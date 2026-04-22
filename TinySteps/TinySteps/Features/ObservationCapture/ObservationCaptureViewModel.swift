import Foundation
import Observation

@Observable
@MainActor
final class ObservationCaptureViewModel {
    private(set) var state: ObservationCaptureState = .idle
    private(set) var transcript = ""
    private(set) var matchedChildren: [ObservationMatchedChild] = []
    private(set) var tags: ObservationPYPTagBundle = .empty
    private(set) var standardTagSuggestions: [ObservationStandardTagSuggestion] = []
    private(set) var confidence: Double = 0
    private(set) var evidenceSpans: [ObservationEvidenceSpan] = []
    private(set) var pendingRetag = true
    private(set) var statusMessage: String?

    private let captureSession: ObservationCaptureSession
    private let speechTranscriber: ObservationSpeechTranscribing
    private let taggingService: ObservationTaggingService
    private let standardTaggingService: ObservationStandardTaggingService
    private let standardsLoadingService: MBStandardsLoadingService
    private let childMatcher: ObservationChildNameMatching
    private let draftStore: ObservationCaptureDraftStore
    private let authSession: AuthSession
    private let standardTaggingCandidateBuilder = ObservationStandardTaggingCandidateBuilder()
    private let maxStandardCandidates = 40
    private let maxStandardTagSuggestions = 4
    private var activeTranscriptTask: Task<Void, Never>?
    private var standardTagUpdateTask: Task<Void, Never>?
    private var hasPrepared = false
    private var hasLoadedStandards = false
    private var isLoadingStandards = false
    private var isMicPressActive = false
    private var shouldCancelPendingStart = false
    private var currentDraftID: UUID?
    private var currentDraftCreatedAt: Date?
    private(set) var selectedUnitID: String?
    private(set) var standardsLoadResult: MBStandardsLoadResult?
    private var dismissedChildMatchKeys: Set<String> = []
    private var manuallyAssignedChildKeys: Set<String> = []
    private var manuallyExcludedStandardTagIDs: Set<String> = []

    init(
        captureSession: ObservationCaptureSession,
        speechTranscriber: ObservationSpeechTranscribing,
        taggingService: ObservationTaggingService,
        standardTaggingService: ObservationStandardTaggingService,
        standardsLoadingService: MBStandardsLoadingService,
        childMatcher: ObservationChildNameMatching,
        draftStore: ObservationCaptureDraftStore,
        session: AuthSession
    ) {
        self.captureSession = captureSession
        self.speechTranscriber = speechTranscriber
        self.taggingService = taggingService
        self.standardTaggingService = standardTaggingService
        self.standardsLoadingService = standardsLoadingService
        self.childMatcher = childMatcher
        self.draftStore = draftStore
        self.authSession = session
    }

    var className: String {
        captureSession.className
    }

    var unitSections: [MBStandardUnitSection] {
        standardsLoadResult?.unitSections ?? []
    }

    var selectedUnitSection: MBStandardUnitSection? {
        guard unitSections.isEmpty == false else {
            return nil
        }

        return unitSections.first(where: { $0.id == selectedUnitID }) ?? unitSections.first
    }

    var rosterCount: Int {
        captureSession.rosterSnapshot.count
    }

    var rosterStudents: [ObservationRosterStudent] {
        captureSession.rosterSnapshot
    }

    var selectedStudentKeys: Set<String> {
        Set(matchedChildren.map(\.studentKey))
    }

    var isRecording: Bool {
        state == .recording
    }

    var isMicControlActive: Bool {
        isMicPressActive || state == .requestingPermission || state == .recording
    }

    var isSuggestingTags: Bool {
        state == .suggestingTags
    }

    var isSaving: Bool {
        state == .saving
    }

    var hasTranscript: Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canSave: Bool {
        hasTranscript &&
        state != .recording &&
        state != .requestingPermission &&
        state != .transcribing &&
        state != .saving
    }

    var shouldRetryStandardsLoad: Bool {
        guard let status = standardsLoadResult?.status else {
            return false
        }

        return status == .failed || status == .partialFailure
    }

    var hasUnitSections: Bool {
        unitSections.isEmpty == false
    }

    var standardTagPreviewHashtags: [String] {
        let references = selectedUnitSection?.references ?? []
        return ObservationStandardTaggingCandidateBuilder()
            .candidatePreviewHashtags(for: references)
            .prefix(4)
            .map { $0.isEmpty ? "—" : $0 }
    }

    var standardTagPickerCandidates: [MBStandardReference] {
        let references = selectedUnitSection?.references ?? []
        return references
            .uniqueByID()
            .filter { candidate in
                standardTagSuggestions.contains { $0.referenceID == candidate.id } == false
            }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.title.lowercased() < $1.title.lowercased()
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    func selectUnit(id unitID: String) {
        guard unitSections.contains(where: { $0.id == unitID }) else {
            return
        }

        guard selectedUnitID != unitID else {
            return
        }

        selectedUnitID = unitID
        manualStandardTagUnitDidChange(to: unitID)
    }

    func filteredTagValues(_ values: [String], for category: ObservationPYPTagCategory) -> [String] {
        guard let selectedReferences = selectedUnitSection?.references, selectedReferences.isEmpty == false else {
            return values
        }

        let supportedValues = supportedTagValues(for: category, in: selectedReferences)
        guard supportedValues.isEmpty == false else {
            return values
        }

        let filtered = values.filter { value in
            supportedValues.contains(ObservationTagValueNormalizer.normalize(value))
        }
        return filtered.isEmpty ? values : filtered
    }

    func hashtagValues(for category: ObservationPYPTagCategory) -> [String] {
        guard let selectedReferences = selectedUnitSection?.references,
              selectedReferences.isEmpty == false else {
            return []
        }

        return Array(uniqueHashtags(from: relevantReferences(for: category, in: selectedReferences)).prefix(4))
    }

    private func relevantReferences(
        for category: ObservationPYPTagCategory,
        in references: [MBStandardReference]
    ) -> [MBStandardReference] {
        let searchableReferences: [MBStandardReference]

        switch category {
        case .transdisciplinaryTheme:
            searchableReferences = references.filter { $0.kind == .pypTheme }
        case .keyConcept:
            searchableReferences = references.filter { $0.kind != .pypTheme }
        case .atlSkill:
            searchableReferences = references.filter { $0.kind != .pypTheme }
        case .learnerProfile:
            searchableReferences = references.filter { $0.kind != .pypTheme }
        }

        return searchableReferences
    }

    private func uniqueHashtags(from references: [MBStandardReference]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for reference in references {
            let hashtag = reference.displayHashtag

            if hashtag.isEmpty {
                continue
            }

            if seen.insert(hashtag).inserted {
                result.append(hashtag)
            }
        }

        return result
    }

    var errorMessage: String? {
        guard case .failed(let error) = state else {
            return nil
        }
        return error.errorDescription
    }

    func prepare() async {
        guard hasPrepared == false else {
            return
        }

        hasPrepared = true
        state = .permissionUnknown

        do {
            let drafts = try await draftStore.loadDrafts(forClassID: captureSession.classID)
            if let latestDraft = drafts.last(where: { $0.status.isRecoverableActiveDraft }) {
                apply(draft: latestDraft)
                statusMessage = "Recovered an in-progress local observation draft."
                state = .draftReady
            } else {
                state = .ready
            }
        } catch {
            statusMessage = "Local draft recovery is unavailable right now."
            state = .ready
        }

        Task {
            await loadStandards()
        }
    }

    func beginMicPress() {
        guard isMicPressActive == false, state != .saving else {
            return
        }

        isMicPressActive = true
        shouldCancelPendingStart = false
        Task {
            await startRecording()
        }
    }

    func endMicPress() {
        guard isMicPressActive else {
            return
        }

        isMicPressActive = false
        Task {
            await stopRecording()
        }
    }

    func updateTranscript(_ newTranscript: String) {
        transcript = newTranscript
        let automaticMatches = childMatcher.matchChildren(
            in: newTranscript,
            roster: captureSession.rosterSnapshot
        )
        .filter { isDismissedMatchedChild($0) == false }

        let automaticMatchKeys = Set(automaticMatches.map(\.studentKey))
        let manualMatches = captureSession.rosterSnapshot
            .filter { manuallyAssignedChildKeys.contains($0.studentKey) }
            .filter { automaticMatchKeys.contains($0.studentKey) == false }
            .map(Self.matchedChild)

        matchedChildren = automaticMatches + manualMatches

        if newTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tags = .empty
            confidence = 0
            evidenceSpans = []
            standardTagSuggestions = []
            manuallyExcludedStandardTagIDs.removeAll()
            pendingRetag = true
        }
    }

    func suggestTagsForCurrentTranscript() {
        guard hasTranscript else {
            statusMessage = "No transcript to tag yet. Record or insert sample text first."
            state = .ready
            return
        }

        guard state != .recording,
              state != .requestingPermission,
              state != .transcribing else {
            statusMessage = "Finish recording before requesting tags."
            return
        }

        if state == .suggestingTags {
            statusMessage = "Tagging is already running."
            return
        }

        Task {
            await suggestTags()
        }
    }

    func cancelActiveCapture() async {
        shouldCancelPendingStart = true
        isMicPressActive = false
        activeTranscriptTask?.cancel()
        activeTranscriptTask = nil
        await speechTranscriber.cancel()

        if state == .recording || state == .transcribing || state == .requestingPermission {
            state = hasTranscript ? .draftReady : .ready
        }
    }

    func saveDraft() async -> Bool {
        guard canSave else {
            return false
        }

        state = .saving
        statusMessage = nil

        let now = Date()
        let draft = ObservationCaptureDraft(
            id: currentDraftID ?? UUID(),
            classID: captureSession.classID,
            className: captureSession.className,
            transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            matchedChildren: matchedChildren,
            tags: tags,
            standardTagSuggestions: standardTagSuggestions,
            confidence: confidence,
            evidenceSpans: evidenceSpans,
            pendingRetag: pendingRetag,
            dismissedChildMatchKeys: dismissedChildMatchKeys,
            status: .savedForReview,
            createdAt: currentDraftCreatedAt ?? now,
            updatedAt: now
        )

        do {
            let draftID = try await draftStore.saveDraft(draft)
            currentDraftID = draftID
            currentDraftCreatedAt = draft.createdAt
            state = .saved
            statusMessage = "Local draft saved for review."
            return true
        } catch {
            state = .failed(.saveFailed(error.localizedDescription))
            return false
        }
    }

    func discardDraft() async {
        shouldCancelPendingStart = true
        if let currentDraftID {
            try? await draftStore.deleteDraft(id: currentDraftID)
        }

        activeTranscriptTask?.cancel()
        await speechTranscriber.cancel()
        resetDraftState()
        state = .ready
        statusMessage = nil
    }

    func addMatchedChild(studentID: String) {
        guard let student = captureSession.rosterSnapshot.first(where: { $0.id == studentID }) else {
            return
        }

        let child = Self.matchedChild(for: student)
        dismissedChildMatchKeys.subtract(dismissalKeys(for: child))
        manuallyAssignedChildKeys.insert(child.studentKey)

        guard matchedChildren.contains(where: { $0.studentKey == child.studentKey }) == false else {
            return
        }

        matchedChildren.append(child)
    }

    func removeMatchedChild(id: ObservationMatchedChild.ID) {
        if let child = matchedChildren.first(where: { $0.id == id }) {
            dismissedChildMatchKeys.formUnion(dismissalKeys(for: child))
            manuallyAssignedChildKeys.remove(child.studentKey)
        } else {
            dismissedChildMatchKeys.insert(Self.dismissalKey(prefix: "id", value: id))
            manuallyAssignedChildKeys.remove(id)
        }

        matchedChildren.removeAll { $0.id == id }
    }

    func removeTag(category: ObservationPYPTagCategory, value: String) {
        tags.remove(category: category, value: value)
        evidenceSpans.removeAll { $0.category == category && $0.value == value }
        pendingRetag = tags.isEmpty && standardTagSuggestions.isEmpty
    }

    func removeStandardTag(referenceID: String) {
        manuallyExcludedStandardTagIDs.insert(referenceID)
        standardTagSuggestions.removeAll { $0.referenceID == referenceID }
        pendingRetag = tags.isEmpty && standardTagSuggestions.isEmpty
    }

    func addStandardTag(referenceID: String) {
        guard let candidate = referenceForStandardTag(referenceID: referenceID),
              standardTagSuggestions.contains(where: { $0.referenceID == referenceID }) == false else {
            return
        }

        manuallyExcludedStandardTagIDs.remove(referenceID)
        let suggestion = ObservationStandardTagSuggestion(
            referenceID: candidate.id,
            sourceID: candidate.sourceID,
            kind: candidate.kind,
            classID: candidate.classID,
            unitID: candidate.unitID,
            unitTitle: candidate.unitTitle,
            programCode: candidate.programCode,
            code: candidate.code,
            title: candidate.title,
            detail: candidate.detail,
            displayHashtag: candidate.displayHashtag,
            evidenceQuotes: [],
            selectionSource: .manual
        )
        standardTagSuggestions.append(suggestion)
        pendingRetag = false
    }

    func evidence(forStandardTag suggestion: ObservationStandardTagSuggestion) -> String? {
        guard suggestion.evidenceQuotes.isEmpty == false else {
            return nil
        }

        return suggestion.evidenceQuotes.first
    }

    func evidence(for category: ObservationPYPTagCategory, value: String) -> ObservationEvidenceSpan? {
        evidenceSpans.first { $0.category == category && $0.value == value }
    }

    private func startRecording() async {
        guard state != .recording else {
            return
        }

        state = .requestingPermission
        statusMessage = nil

        let authorization = await speechTranscriber.requestAuthorization()
        guard shouldCancelPendingStart == false else {
            state = hasTranscript ? .draftReady : .ready
            return
        }

        guard authorization == .authorized else {
            state = authorizationFailureState(for: authorization)
            return
        }

        do {
            resetCaptureValuesForNewRecording()
            let stream = try await speechTranscriber.start(locale: .current)
            guard shouldCancelPendingStart == false else {
                await speechTranscriber.cancel()
                state = hasTranscript ? .draftReady : .ready
                return
            }

            state = .recording

            activeTranscriptTask = Task { [weak self] in
                do {
                    for try await event in stream {
                        self?.consumeTranscriptEvent(event)
                    }
                } catch {
                    self?.handleTranscriptStreamFailure(error)
                }
            }

            if isMicPressActive == false {
                await stopRecording()
            }
        } catch {
            if shouldCancelPendingStart {
                state = hasTranscript ? .draftReady : .ready
            } else {
                state = .failed(.speechUnavailable(error.localizedDescription))
            }
        }
    }

    private func loadStandards() async {
        await loadStandards(forceRefresh: false)
    }

    func retryLoadStandards() async {
        await loadStandards(forceRefresh: true)
    }

    private func loadStandards(forceRefresh: Bool) async {
        if isLoadingStandards {
            return
        }

        guard forceRefresh || hasLoadedStandards == false else {
            return
        }

        isLoadingStandards = true
        if forceRefresh {
            hasLoadedStandards = false
        }

        defer {
            isLoadingStandards = false
        }

        let result = await standardsLoadingService.loadStandards(
            for: authSession,
            selectedClass: captureSession.selectedClass
        )

        hasLoadedStandards = [.loaded, .empty].contains(result.status)
        standardsLoadResult = result
        syncSelectedUnit(from: result)

        if let errorMessage = result.errorMessage,
           [.permissionUnknown, .ready, .draftReady].contains(state) {
            statusMessage = errorMessage
        }
    }

    private func syncSelectedUnit(from result: MBStandardsLoadResult) {
        guard result.unitSections.isEmpty == false else {
            selectedUnitID = nil
            standardTagSuggestions = []
            manuallyExcludedStandardTagIDs.removeAll()
            return
        }

        if let selectedUnitID, result.unitSections.contains(where: { $0.id == selectedUnitID }) {
            refreshStandardTagsIfNeeded(forUnitID: selectedUnitID)
            return
        }

        selectedUnitID = result.unitSections.first?.id
        if let selectedUnitID {
            refreshStandardTagsIfNeeded(forUnitID: selectedUnitID)
        }
    }

    private func manualStandardTagUnitDidChange(to unitID: String) {
        standardTagSuggestions.removeAll()
        manuallyExcludedStandardTagIDs.removeAll()
        pendingRetag = true
        refreshStandardTagsIfNeeded(forUnitID: unitID)
    }

    private func refreshStandardTagsIfNeeded(forUnitID unitID: String) {
        standardTagUpdateTask?.cancel()

        guard selectedUnitID == unitID,
              selectedUnitSection?.id == unitID,
              hasTranscript else {
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            guard self.selectedUnitID == unitID else {
                return
            }

            self.standardTagSuggestions = []
            await self.suggestStandardTags()
        }

        standardTagUpdateTask = task
    }

    private func supportedTagValues(for category: ObservationPYPTagCategory, in references: [MBStandardReference]) -> Set<String> {
        let valuesToMatch: [String]
        let searchableReferences: [MBStandardReference]

        switch category {
        case .transdisciplinaryTheme:
            valuesToMatch = PYPTheme.allCases.map(\.rawValue)
            searchableReferences = references.filter { $0.kind == .pypTheme }
        case .keyConcept:
            valuesToMatch = PYPKeyConcept.allCases.map(\.rawValue)
            searchableReferences = references.filter { $0.kind != .pypTheme }
        case .atlSkill:
            valuesToMatch = PYPATLSkillCluster.allCases.map(\.rawValue)
            searchableReferences = references.filter { $0.kind != .pypTheme }
        case .learnerProfile:
            valuesToMatch = PYPLearnerProfile.allCases.map(\.rawValue)
            searchableReferences = references.filter { $0.kind != .pypTheme }
        }

        guard searchableReferences.isEmpty == false else {
            return []
        }

        let searchableText = searchableReferences
            .map(Self.normalizedStandardText(_:))
            .joined(separator: " ")

        return Set(
            valuesToMatch.compactMap { value in
                let normalizedValue = ObservationTagValueNormalizer.normalize(value)
                guard searchableText.contains(normalizedValue) else {
                    return nil
                }
                return normalizedValue
            }
        )
    }

    private static func normalizedStandardText(_ reference: MBStandardReference) -> String {
        let chunks = [
            reference.title,
            reference.code ?? "",
            reference.detail ?? "",
            reference.displayHashtag
        ]

        return ObservationTagValueNormalizer.normalize(chunks.joined(separator: " "))
    }

    private func stopRecording() async {
        guard state == .recording else {
            return
        }

        state = .transcribing
        let finalTranscript = await speechTranscriber.stop()
        activeTranscriptTask?.cancel()
        activeTranscriptTask = nil

        let normalizedTranscript = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedTranscript.isEmpty == false {
            updateTranscript(normalizedTranscript)
        }

        guard hasTranscript else {
            state = .failed(.noSpeechDetected)
            return
        }

        await suggestTags()
    }

    private func suggestTags() async {
        state = .suggestingTags
        tags = .empty
        confidence = 0
        standardTagSuggestions = standardTagSuggestions.filter { $0.selectionSource == .manual }
        evidenceSpans = []
        pendingRetag = true
        statusMessage = nil

        do {
            try await suggestPYPTags()
            await suggestStandardTags()

            pendingRetag = tags.isEmpty && standardTagSuggestions.isEmpty
            if pendingRetag {
                statusMessage = "No tags were suggested for this transcript. You can add tags manually."
            }
            state = .draftReady
        } catch {
            pendingRetag = true
            statusMessage = "Tagging failed: \(error.localizedDescription). This transcript can still be saved as a local draft."
            state = .draftReady
        }
    }

    private func suggestPYPTags() async throws {
        for try await event in taggingService.suggestTags(
            transcript: transcript,
            classContext: captureSession
        ) {
            switch event {
            case .suggestions(let result):
                tags = result.tags
                confidence = max(confidence, result.confidence)
                evidenceSpans = result.evidenceSpans
                if result.tags.isEmpty == false {
                    pendingRetag = false
                    statusMessage = nil
                }
            case .unavailable:
                pendingRetag = true
                statusMessage = "PYP tags are currently unavailable. Add tags manually."
            }
        }
    }

    private func suggestStandardTags() async {
        guard let selectedUnitSection else {
            statusMessage = "No learning unit is selected for standard tagging."
            return
        }

        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTranscript.isEmpty == false else {
            statusMessage = "No transcript text available for standard tagging."
            return
        }

        let candidates = standardTaggingCandidateBuilder.buildCandidates(
            from: selectedUnitSection,
            transcript: trimmedTranscript,
            maxCandidates: maxStandardCandidates
        )

        if candidates.isEmpty {
            statusMessage = "No standard candidates for this unit."
            return
        }

        let candidateLookup = candidateLookup(from: candidates)
        let request = ObservationStandardTaggingRequest(
            classID: captureSession.classID,
            className: captureSession.className,
            selectedUnitID: selectedUnitSection.id,
            selectedUnitTitle: selectedUnitSection.unitTitle,
            transcript: trimmedTranscript,
            candidates: candidates,
            excludedSuggestionIDs: manuallyExcludedStandardTagIDs,
            candidateLookup: candidateLookup
        )

        do {
            for try await event in standardTaggingService.suggestStandardTags(request: request) {
                switch event {
                case .partial(let suggestions):
                    replaceStandardTagSuggestions(with: suggestions, mergeManual: true)
                    if suggestions.isEmpty == false {
                        statusMessage = nil
                    }
                case .suggestions(let result):
                    replaceStandardTagSuggestions(with: result.suggestions, mergeManual: true)
                    confidence = max(confidence, result.confidence)
                    if result.suggestions.isEmpty == false {
                        pendingRetag = false
                        statusMessage = nil
                    } else if tags.isEmpty {
                        statusMessage = "No standard tags were suggested for this unit."
                    }
                case .unavailable:
                    if pendingRetag && tags.isEmpty && standardTagSuggestions.isEmpty {
                        pendingRetag = true
                    }
                    statusMessage = "Standard tagging is unavailable right now. Add tags manually."
                }
            }
        } catch {
            if tags.isEmpty && standardTagSuggestions.isEmpty {
                statusMessage = "Standard tagging failed: \(error.localizedDescription). This transcript can still be saved as a local draft."
            }
        }
    }

    private func replaceStandardTagSuggestions(
        with suggestions: [ObservationStandardTagSuggestion],
        mergeManual: Bool
    ) {
        var merged: [ObservationStandardTagSuggestion] = []
        var seen = Set<String>()

        let manualSuggestions = mergeManual
            ? standardTagSuggestions.filter { $0.selectionSource == .manual }
            : []

        for suggestion in manualSuggestions {
            guard seen.insert(suggestion.referenceID).inserted else {
                continue
            }
            merged.append(suggestion)
        }

        for suggestion in suggestions {
            guard manuallyExcludedStandardTagIDs.contains(suggestion.referenceID) == false else {
                continue
            }
            guard seen.insert(suggestion.referenceID).inserted else {
                continue
            }
            merged.append(suggestion)

            if merged.count >= maxStandardTagSuggestions {
                break
            }
        }

        standardTagSuggestions = merged
    }

    private func referenceForStandardTag(referenceID: String) -> MBStandardReference? {
        selectedUnitSection?.references.first(where: { $0.id == referenceID })
    }

    private func candidateLookup(from candidates: [ObservationStandardTagCandidate]) -> [String: MBStandardReference] {
        var lookup: [String: MBStandardReference] = [:]

        for candidate in candidates {
            guard lookup[candidate.id] == nil else {
                continue
            }

            lookup[candidate.id] = MBStandardReference(
                kind: candidate.kind,
                classID: candidate.classID,
                unitID: candidate.unitID,
                unitTitle: candidate.unitTitle,
                programCode: candidate.programCode,
                sourceID: candidate.sourceID,
                code: candidate.code,
                title: candidate.title,
                detail: candidate.detail,
                isUnresolvedTheme: false,
                displayHashtag: candidate.displayHashtag,
                stableIdentity: candidate.stableIdentity
            )
        }

        return lookup
    }

    private func consumeTranscriptEvent(_ event: ObservationTranscriptEvent) {
        updateTranscript(event.transcript)
    }

    private func handleTranscriptStreamFailure(_ error: Error) {
        guard state == .recording || state == .transcribing else {
            return
        }

        if let transcriberError = error as? ObservationSpeechTranscriberError,
           transcriberError.isRecoverableRecordingInterruption {
            isMicPressActive = false
            activeTranscriptTask = nil
            statusMessage = transcriberError.errorDescription
            state = hasTranscript ? .draftReady : .ready
            return
        }

        state = .failed(.speechUnavailable(error.localizedDescription))
    }

    private func authorizationFailureState(for authorization: ObservationSpeechAuthorizationStatus) -> ObservationCaptureState {
        switch authorization {
        case .microphoneDenied:
            return .failed(.microphonePermissionDenied)
        case .denied:
            return .failed(.speechPermissionDenied)
        case .restricted:
            return .failed(.speechUnavailable("Speech recognition is restricted on this device."))
        case .notDetermined, .unknown:
            return .failed(.speechUnavailable("Speech recognition permission is unavailable right now."))
        case .authorized:
            return .ready
        }
    }

    private func resetCaptureValuesForNewRecording() {
        transcript = ""
        matchedChildren = []
        dismissedChildMatchKeys = []
        manuallyAssignedChildKeys = []
        tags = .empty
        standardTagSuggestions = []
        manuallyExcludedStandardTagIDs.removeAll()
        confidence = 0
        evidenceSpans = []
        pendingRetag = true
    }

    private func resetDraftState() {
        resetCaptureValuesForNewRecording()
        currentDraftID = nil
        currentDraftCreatedAt = nil
    }

    private func apply(draft: ObservationCaptureDraft) {
        currentDraftID = draft.id
        currentDraftCreatedAt = draft.createdAt
        transcript = draft.transcript
        matchedChildren = draft.matchedChildren
        dismissedChildMatchKeys = draft.dismissedChildMatchKeys
        manuallyAssignedChildKeys = Set(draft.matchedChildren.map(\.studentKey))
        tags = draft.tags
        standardTagSuggestions = draft.standardTagSuggestions
        confidence = draft.confidence
        evidenceSpans = draft.evidenceSpans
        pendingRetag = draft.pendingRetag
        manuallyExcludedStandardTagIDs.removeAll()
    }

    private func isDismissedMatchedChild(_ child: ObservationMatchedChild) -> Bool {
        dismissalKeys(for: child).contains { dismissedChildMatchKeys.contains($0) }
    }

    private func dismissalKeys(for child: ObservationMatchedChild) -> Set<String> {
        [
            Self.dismissalKey(prefix: "id", value: child.id),
            Self.dismissalKey(prefix: "student", value: child.studentKey),
            Self.dismissalKey(prefix: "match", value: child.matchText)
        ]
    }

    private static func dismissalKey(prefix: String, value: String) -> String {
        "\(prefix):\(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased())"
    }

    private static func matchedChild(for student: ObservationRosterStudent) -> ObservationMatchedChild {
        ObservationMatchedChild(
            studentKey: student.studentKey,
            displayName: student.displayName,
            matchText: student.displayName,
            confidence: 1
        )
    }
}

private extension Array where Element == MBStandardReference {
    func uniqueByID() -> [MBStandardReference] {
        var seen: Set<String> = []
        return filter { candidate in
            guard seen.contains(candidate.id) == false else {
                return false
            }
            seen.insert(candidate.id)
            return true
        }
    }
}
