import Foundation
import MBAPI

protocol MBStandardsLoadingService: Sendable {
    func loadStandards(
        for session: AuthSession,
        childContext: ChildContext,
        selectedClass: MBClass,
        forceRefresh: Bool
    ) async -> MBStandardsLoadResult

    func clearCache() async
}

extension MBStandardsLoadingService {
    func loadStandards(
        for session: AuthSession,
        selectedClass: MBClass,
        forceRefresh: Bool = false
    ) async -> MBStandardsLoadResult {
        await loadStandards(
            for: session,
            childContext: .allChildren,
            selectedClass: selectedClass,
            forceRefresh: forceRefresh
        )
    }
}

final class MBStandardsLoadingServiceImpl: MBStandardsLoadingService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient
    private let cache: MBStandardsCache
    private let hashtagGenerator: MBStandardHashtagGenerating

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient,
        hashtagGenerator: MBStandardHashtagGenerating = MBStandardHashtagGenerator(),
        cache: MBStandardsCache = MBStandardsCache()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
        self.hashtagGenerator = hashtagGenerator
        self.cache = cache
    }

    func loadStandards(
        for session: AuthSession,
        childContext: ChildContext,
        selectedClass: MBClass,
        forceRefresh: Bool
    ) async -> MBStandardsLoadResult {
        let key = MBStandardsCacheKey(classID: selectedClass.id, program: selectedClass.program)

        if forceRefresh == false, let cached = await cache.cachedResult(for: key) {
            return cached
        }

        let credentials: MBAPICredentials
        do {
            credentials = try credentialsProvider.credentials(for: session)
        } catch {
            return await failedResult(
                for: selectedClass,
                key: key,
                unitFailures: [],
                error: "Session is no longer valid. Please sign in again."
            )
        }

        let context = credentials.sessionContext(childID: childContext.apiChildID)
        let className = selectedClass.displayName.isEmpty ? selectedClass.id : selectedClass.displayName

        do {
            let units = try await client.listClassUnits(in: context, classID: selectedClass.id)
            let programCode = MBStandardsProgramDetector.programCode(for: selectedClass.program)

            guard units.isEmpty == false else {
                return await storeAndReturn(
                    result: MBStandardsLoadResult(
                        classID: selectedClass.id,
                        className: className,
                        classProgramCode: MBStandardsProgramDetector.programCode(for: selectedClass.program),
                        isPYP: MBStandardsProgramDetector.programIsPYP(selectedClass.program),
                        status: .empty,
                        references: [],
                        unitSections: [],
                        unitLoadFailures: [],
                        loadedAt: .now,
                        errorMessage: nil
                    ),
                    for: key
                )
            }

            var unitFailures: [MBStandardsUnitFailure] = []

            let componentResults = await withTaskGroup(of: UnitComponentLoadResult.self, returning: [UnitComponentLoadResult].self) { group in
                for unit in units {
                    group.addTask {
                        await self.loadComponents(
                            for: unit,
                            inClassID: selectedClass.id,
                            in: context,
                            classProgramCode: programCode
                        )
                    }
                }

                var results: [UnitComponentLoadResult] = []
                for await result in group {
                    results.append(result)
                }

                return results
            }

            for componentResult in componentResults where componentResult.failure != nil {
                unitFailures.append(componentResult.failure!)
            }

            let orderedComponentResults = units.compactMap { orderedUnit in
                componentResults.first { $0.unitID == orderedUnit.id }
            }

            var references: [MBStandardReference] = orderedComponentResults.flatMap { $0.references }

            if MBStandardsProgramDetector.programIsPYP(selectedClass.program) {
                let themes = await loadPYPThemes(for: context)
                if let themeError = themes.error {
                    unitFailures.append(themeError)
                }

                references = references.map { reference in
                    guard reference.kind == .pypTheme else {
                        return reference
                    }

                    guard let resolvedTheme = themes.theme(for: reference) else {
                        let hasReadableTitle = reference.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        return MBStandardReference(
                            kind: .pypTheme,
                            classID: reference.classID,
                            unitID: reference.unitID,
                            unitTitle: reference.unitTitle,
                            programCode: reference.programCode,
                            sourceID: reference.sourceID,
                            code: reference.code,
                            title: hasReadableTitle ? reference.title : unresolvedThemeTitle(reference.sourceID),
                            detail: nil,
                            isUnresolvedTheme: true,
                            displayHashtag: reference.displayHashtag,
                            sourceIdentity: reference.sourceIdentity,
                            stableIdentity: reference.stableIdentity
                        )
                    }

                    let sourceIdentity: MBStandardSourceIdentity
                    let sourceID: String
                    let detail: String?
                    if let descriptionID = resolvedTheme.descriptionID {
                        sourceIdentity = .pypThemeDescription(themeID: resolvedTheme.themeID, descriptionID: descriptionID)
                        sourceID = descriptionID
                        detail = resolvedTheme.themeTitle
                    } else {
                        sourceIdentity = .pypTheme(themeID: resolvedTheme.themeID)
                        sourceID = resolvedTheme.themeID
                        detail = resolvedTheme.description
                    }

                    return MBStandardReference(
                        kind: .pypTheme,
                        classID: reference.classID,
                        unitID: reference.unitID,
                        unitTitle: reference.unitTitle,
                        programCode: reference.programCode,
                        sourceID: sourceID,
                        code: nil,
                        title: resolvedTheme.title,
                        detail: detail,
                        isUnresolvedTheme: false,
                        displayHashtag: reference.displayHashtag,
                        sourceIdentity: sourceIdentity,
                        stableIdentity: stableIdentity(
                            classID: reference.classID,
                            unitID: reference.unitID,
                            sourceIdentity: sourceIdentity
                        )
                    )
                }

            }

            let resolvedHashtags = await hashtagGenerator.hashtags(for: references)
            let enriched = references.map { reference in
                let referenceHashtag = resolvedHashtags[reference.id] ?? reference.displayHashtag
                let resolvedReference = MBStandardReference(
                    kind: reference.kind,
                    classID: reference.classID,
                    unitID: reference.unitID,
                    unitTitle: reference.unitTitle,
                    programCode: reference.programCode,
                    sourceID: reference.sourceID,
                    code: reference.code,
                    title: reference.title,
                    detail: reference.detail,
                    isUnresolvedTheme: reference.isUnresolvedTheme,
                    displayHashtag: normalizeHashtag(referenceHashtag),
                    sourceIdentity: reference.sourceIdentity,
                    stableIdentity: reference.stableIdentity
                )
                return resolvedHashtags.isEmpty ? reference : resolvedReference
            }

            let deduplicated = deduplicate(enriched)

            let unitSections = units.compactMap { unit in
                let sectionReferences = deduplicated.filter { $0.unitID == unit.id }
                return MBStandardUnitSection(
                    unitID: unit.id,
                    unitTitle: unit.title,
                    references: sectionReferences
                )
            }

            let allReferences = deduplicated
            let uniqueReferenceCount = allReferences.count

            let status: MBStandardsLoadStatus = {
                if uniqueReferenceCount == 0 && componentResults.allSatisfy({ $0.failure == nil }) {
                    return .empty
                }

                if unitFailures.isEmpty {
                    return .loaded
                }

                return uniqueReferenceCount == 0 ? .failed : .partialFailure
            }()

            let errorMessage = errorSummary(
                forClass: className,
                classID: selectedClass.id,
                unitFailures: unitFailures,
                status: status
            )

            return await storeAndReturn(
                result: MBStandardsLoadResult(
                    classID: selectedClass.id,
                    className: className,
                    classProgramCode: MBStandardsProgramDetector.programCode(for: selectedClass.program),
                    isPYP: MBStandardsProgramDetector.programIsPYP(selectedClass.program),
                    status: status,
                    references: allReferences,
                    unitSections: unitSections,
                    unitLoadFailures: unitFailures,
                    loadedAt: .now,
                    errorMessage: errorMessage
                ),
                for: key
            )
        } catch {
            return await storeAndReturn(
                result: failedResult(
                    for: selectedClass,
                    key: key,
                    unitFailures: [],
                    error: error.localizedDescription
                ),
                for: key
            )
        }
    }

    func clearCache() async {
        await cache.clear()
    }

    private func loadComponents(
        for unit: MBClassUnit,
        inClassID classID: String,
        in context: MBSessionContext,
        classProgramCode: String?
    ) async -> UnitComponentLoadResult {
        if let components = await loadComponentsFromClassEndpoint(
            for: unit,
            inClassID: classID,
            in: context,
            classProgramCode: classProgramCode
        ) {
            return components
        }

        if let components = await loadComponentsFromUnitEndpoint(
            for: unit,
            in: context,
            classProgramCode: classProgramCode
        ) {
            return components
        }

        return UnitComponentLoadResult(
            unitID: unit.id,
            unitTitle: unit.title,
            references: [],
            failure: MBStandardsUnitFailure(
                unitID: unit.id,
                unitTitle: unit.title,
                errorDescription: "Unable to load standards for this unit."
            )
        )
    }

    private func loadComponentsFromUnitEndpoint(
        for unit: MBClassUnit,
        in context: MBSessionContext,
        classProgramCode: String?
    ) async -> UnitComponentLoadResult? {
        do {
            let components = try await client.loadStandardsComponents(
                in: context,
                forUnitID: unit.id
            )

            return UnitComponentLoadResult(
                unitID: unit.id,
                unitTitle: unit.title,
                references: mapReferences(
                    from: components,
                    unit: unit,
                    classProgramCode: classProgramCode
                ),
                failure: nil
            )
        } catch {
            if case MBClientError.unexpectedStatusCode(let statusCode) = error,
               statusCode == 404 {
                return nil
            }

            return UnitComponentLoadResult(
                unitID: unit.id,
                unitTitle: unit.title,
                references: [],
                failure: MBStandardsUnitFailure(
                    unitID: unit.id,
                    unitTitle: unit.title,
                    errorDescription: error.localizedDescription
                )
            )
        }
    }

    private func loadComponentsFromClassEndpoint(
        for unit: MBClassUnit,
        inClassID classID: String,
        in context: MBSessionContext,
        classProgramCode: String?
    ) async -> UnitComponentLoadResult? {
        do {
            let components = try await client.loadStandardsComponents(
                in: context,
                classID: classID,
                forUnitID: unit.id
            )

            return UnitComponentLoadResult(
                unitID: unit.id,
                unitTitle: unit.title,
                references: mapReferences(
                    from: components,
                    unit: unit,
                    classProgramCode: classProgramCode
                ),
                failure: nil
            )
        } catch {
            if case MBClientError.unexpectedStatusCode(let statusCode) = error,
               statusCode == 404 {
                return nil
            }

            return UnitComponentLoadResult(
                unitID: unit.id,
                unitTitle: unit.title,
                references: [],
                failure: MBStandardsUnitFailure(
                    unitID: unit.id,
                    unitTitle: unit.title,
                    errorDescription: error.localizedDescription
                )
            )
        }
    }

    private func loadPYPThemes(for context: MBSessionContext) async -> PYPThemesLoadResult {
        do {
            let themes = try await client.loadSchoolThemes(in: context)
            var themesByID: [String: PYPThemeResolution] = [:]
            var themesByNormalizedName: [String: PYPThemeResolution] = [:]
            var themeDescriptionsByParentAndName: [String: PYPThemeResolution] = [:]
            for theme in themes {
                let themeResolution = PYPThemeResolution(
                    themeID: theme.id,
                    descriptionID: nil,
                    title: theme.name,
                    themeTitle: theme.name,
                    description: theme.description
                )
                themesByID[theme.id] = themeResolution
                themesByNormalizedName[MBStandardsProgramDetector.normalizedValue(theme.name)] = themeResolution
                for description in theme.descriptions {
                    let descriptionResolution = PYPThemeResolution(
                        themeID: theme.id,
                        descriptionID: description.id,
                        title: description.name,
                        themeTitle: theme.name,
                        description: description.label
                    )
                    themesByID[description.id] = descriptionResolution
                    themesByNormalizedName[MBStandardsProgramDetector.normalizedValue(description.name)] = descriptionResolution
                    themeDescriptionsByParentAndName[
                        Self.themeDescriptionKey(parentTitle: theme.name, descriptionTitle: description.name)
                    ] = descriptionResolution
                }
            }

            return PYPThemesLoadResult(
                themesByID: themesByID,
                themesByNormalizedName: themesByNormalizedName,
                themeDescriptionsByParentAndName: themeDescriptionsByParentAndName,
                error: nil
            )
        } catch {
            return PYPThemesLoadResult(
                themesByID: [:],
                themesByNormalizedName: [:],
                themeDescriptionsByParentAndName: [:],
                error: MBStandardsUnitFailure(
                    unitID: "school-theme",
                    unitTitle: "PYP themes",
                    errorDescription: error.localizedDescription
                )
            )
        }
    }

    private func mapReferences(
        from components: MBUnitComponents,
        unit: MBClassUnit,
        classProgramCode: String?
    ) -> [MBStandardReference] {
        var references: [MBStandardReference] = []

        references.append(
            contentsOf: components.standards.map {
                mapStandardReference(
                    kind: .standard,
                    unit: unit,
                    sourceID: $0.id,
                    title: $0.title,
                    code: $0.code,
                    detail: $0.description,
                    programCode: classProgramCode
                )
            }
        )

        references.append(
            contentsOf: components.syllabusItems.map {
                mapStandardReference(
                    kind: .syllabus,
                    unit: unit,
                    sourceID: $0.id,
                    title: $0.title,
                    code: $0.code,
                    detail: $0.description,
                    programCode: classProgramCode
                )
            }
        )

        references.append(
            contentsOf: components.scopeSequences.map {
                mapStandardReference(
                    kind: .scopeSequence,
                    unit: unit,
                    sourceID: $0.id,
                    title: $0.title,
                    code: $0.code,
                    detail: $0.description,
                    programCode: classProgramCode
                )
            }
        )

        let namedThemeIDs = Set(components.namedPYPThemes.map(\.sourceID))
        let unresolvedThemeReferences = components.pypThemeReferences.filter { themeReference in
            namedThemeIDs.contains(themeReference.id) == false
        }

        references.append(
            contentsOf: unresolvedThemeReferences.map { themeReference in
                let sourceIdentity = sourceIdentity(kind: .pypTheme, unitID: unit.id, sourceID: themeReference.id)
                return MBStandardReference(
                    kind: .pypTheme,
                    classID: unit.classID,
                    unitID: unit.id,
                    unitTitle: unit.title,
                    programCode: classProgramCode,
                    sourceID: themeReference.id,
                    code: nil,
                    title: unresolvedThemeTitle(themeReference.id),
                    detail: nil,
                    isUnresolvedTheme: true,
                    displayHashtag: "#Ref\(themeReference.id.prefix(6))",
                    sourceIdentity: sourceIdentity,
                    stableIdentity: stableIdentity(classID: unit.classID, unitID: unit.id, sourceIdentity: sourceIdentity)
                )
            }
        )

        references.append(
            contentsOf: components.namedPYPThemes.map { theme in
                mapStandardReference(
                    kind: .pypTheme,
                    unit: unit,
                    sourceID: theme.sourceID,
                    title: theme.title,
                    code: nil,
                    detail: theme.parentTitle,
                    programCode: classProgramCode,
                    isUnresolvedTheme: true
                )
            }
        )

        return references
    }

    private func mapStandardReference(
        kind: MBStandardReference.Kind,
        unit: MBClassUnit,
        sourceID: String,
        title: String,
        code: String?,
        detail: String?,
        programCode: String?,
        isUnresolvedTheme: Bool = false
    ) -> MBStandardReference {
        let sourceIdentity = sourceIdentity(kind: kind, unitID: unit.id, sourceID: sourceID)
        return MBStandardReference(
            kind: kind,
            classID: unit.classID,
            unitID: unit.id,
            unitTitle: unit.title,
            programCode: programCode,
            sourceID: sourceID,
            code: code,
            title: title,
            detail: detail,
            isUnresolvedTheme: isUnresolvedTheme,
            displayHashtag: "#Ref\(sourceID.prefix(6))",
            sourceIdentity: sourceIdentity,
            stableIdentity: stableIdentity(classID: unit.classID, unitID: unit.id, sourceIdentity: sourceIdentity)
        )
    }

    private func sourceIdentity(
        kind: MBStandardReference.Kind,
        unitID: String,
        sourceID: String
    ) -> MBStandardSourceIdentity {
        if isGeneratedLocalReferenceID(sourceID) {
            return .unresolved(kind: kind.rawValue, generatedID: sourceID)
        }

        switch kind {
        case .standard:
            return .standard(unitID: unitID, standardID: sourceID)
        case .syllabus:
            return .syllabus(unitID: unitID, syllabusID: sourceID)
        case .scopeSequence:
            return .scopeSequence(unitID: unitID, expectationID: sourceID)
        case .pypTheme:
            return .pypTheme(themeID: sourceID)
        }
    }

    private func stableIdentity(classID: String, unitID: String, sourceIdentity: MBStandardSourceIdentity) -> String {
        "\(classID)|\(unitID)|\(sourceIdentity.stableKey)"
    }

    private func isGeneratedLocalReferenceID(_ sourceID: String) -> Bool {
        [
            "standard-",
            "key-concept-",
            "atl-",
            "learner-profile-",
            "theme-"
        ].contains { sourceID.hasPrefix($0) }
    }

    private static func themeDescriptionKey(parentTitle: String, descriptionTitle: String) -> String {
        "\(MBStandardsProgramDetector.normalizedValue(parentTitle))|\(MBStandardsProgramDetector.normalizedValue(descriptionTitle))"
    }

    private func unresolvedThemeTitle(_ themeID: String) -> String {
        "PYP Theme · \(themeID)"
    }

    private func deduplicate(_ references: [MBStandardReference]) -> [MBStandardReference] {
        var seen: Set<MBStandardReference> = []
        return references.filter { reference in
            if seen.contains(reference) {
                return false
            }

            seen.insert(reference)
            return true
        }
    }

    private func normalizeHashtag(_ hashtag: String) -> String {
        guard hashtag.hasPrefix("#") else {
            return "#\(hashtag)"
        }

        if hashtag.count <= 24 {
            return hashtag
        }

        return "#\(String(hashtag.dropFirst()).prefix(23))"
    }

    private func failedResult(
        for selectedClass: MBClass,
        key: MBStandardsCacheKey,
        unitFailures: [MBStandardsUnitFailure],
        error: String
    ) async -> MBStandardsLoadResult {
        return await storeAndReturn(
            result: MBStandardsLoadResult(
                classID: selectedClass.id,
                className: selectedClass.displayName.isEmpty ? selectedClass.id : selectedClass.displayName,
                classProgramCode: MBStandardsProgramDetector.programCode(for: selectedClass.program),
                isPYP: MBStandardsProgramDetector.programIsPYP(selectedClass.program),
                status: .failed,
                references: [],
                unitSections: [],
                unitLoadFailures: unitFailures,
                loadedAt: .now,
                errorMessage: "Failed to load standards for \(selectedClass.displayName). " + error
            ),
            for: key
        )
    }

    private func storeAndReturn(result: MBStandardsLoadResult, for key: MBStandardsCacheKey) async -> MBStandardsLoadResult {
        await cache.store(result, for: key)
        return result
    }

    private func errorSummary(
        forClass className: String,
        classID: String,
        unitFailures: [MBStandardsUnitFailure],
        status: MBStandardsLoadStatus
    ) -> String? {
        switch status {
        case .loaded, .empty:
            return nil
        case .failed:
            if let firstFailure = unitFailures.first {
                return "Failed to load standards for \(className): \(firstFailure.errorDescription)"
            }

            return "Failed to load standards for \(className)."
        case .partialFailure:
            let skipped = unitFailures.count
            let unitName = skipped == 1 ? "unit" : "units"
            if let firstFailure = unitFailures.first {
                return "Loaded partial standards for \(className). Could not load \(skipped) \(unitName): \(firstFailure.errorDescription)"
            }

            return "Loaded partial standards for \(className)."
        }
    }
}

extension MBStandardsLoadingServiceImpl {
    struct UnitComponentLoadResult: Sendable {
        let unitID: String
        let unitTitle: String
        let references: [MBStandardReference]
        let failure: MBStandardsUnitFailure?
    }

    struct PYPThemesLoadResult: Sendable {
        let themesByID: [String: PYPThemeResolution]
        let themesByNormalizedName: [String: PYPThemeResolution]
        let themeDescriptionsByParentAndName: [String: PYPThemeResolution]
        let error: MBStandardsUnitFailure?

        func theme(for reference: MBStandardReference) -> PYPThemeResolution? {
            if let theme = themesByID[reference.sourceID] {
                return theme
            }

            if let parentTitle = reference.detail {
                let parentAndDescriptionKey = MBStandardsLoadingServiceImpl.themeDescriptionKey(
                    parentTitle: parentTitle,
                    descriptionTitle: reference.title
                )
                if let theme = themeDescriptionsByParentAndName[parentAndDescriptionKey] {
                    return theme
                }
            }

            let normalizedTitle = MBStandardsProgramDetector.normalizedValue(reference.title)
            if let theme = themesByNormalizedName[normalizedTitle] {
                return theme
            }

            if let code = reference.code {
                return themesByNormalizedName[MBStandardsProgramDetector.normalizedValue(code)]
            }

            return nil
        }
    }

    struct PYPThemeResolution: Sendable {
        let themeID: String
        let descriptionID: String?
        let title: String
        let themeTitle: String
        let description: String?
    }

    static func preview(filePath: String = #filePath) -> MBStandardsLoadingServiceImpl {
        MBStandardsLoadingServiceImpl(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}

private extension MBClassUnit {
    var classID: String {
        id
    }
}
