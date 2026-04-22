import Foundation

public struct MBUnitComponents: Decodable, Equatable, Sendable {
    public let standards: [MBUnitStandard]
    public let syllabusItems: [MBSyllabusItem]
    public let scopeSequences: [MBScopeSequence]
    public let pypThemeReferences: [MBTRThemeReference]
    public let namedPYPThemes: [NamedPYPTheme]

    public init(
        standards: [MBUnitStandard] = [],
        syllabusItems: [MBSyllabusItem] = [],
        scopeSequences: [MBScopeSequence] = [],
        pypThemeReferences: [MBTRThemeReference] = [],
        namedPYPThemes: [NamedPYPTheme] = []
    ) {
        self.standards = standards
        self.syllabusItems = syllabusItems
        self.scopeSequences = scopeSequences
        self.pypThemeReferences = pypThemeReferences
        self.namedPYPThemes = namedPYPThemes
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case standards
        case syllabusItems = "syllabus_items"
        case syllabusItemsLegacy = "syllabusItems"
        case scopeSequences = "scope_sequences"
        case scopeSequencesLegacy = "scopeSequences"
        case trThemes = "tr_themes"
        case pypThemes = "pyp_themes"
        case themeReferences = "themes"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var decodedStandards = try container.decodeIfPresent([MBUnitStandard].self, forKey: .standards) ?? []
        var decodedSyllabusItems = (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItems))
            ?? (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItemsLegacy))
            ?? []
        var decodedScopeSequences = (try? container.decodeIfPresent([MBScopeSequence].self, forKey: .scopeSequences))
            ?? (try? container.decodeIfPresent([MBScopeSequence].self, forKey: .scopeSequencesLegacy))
            ?? []
        var decodedThemeReferences = (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .trThemes))
            ?? (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .pypThemes))
            ?? (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .themeReferences))
            ?? []
        var decodedNamedThemes: [NamedPYPTheme] = []

        if let componentItems = try? container.decodeIfPresent([UnitComponentPayload].self, forKey: .items) {
            let normalized = Self.normalizeComponentPayloads(componentItems)
            decodedStandards += normalized.standards
            decodedSyllabusItems += normalized.syllabusItems
            decodedScopeSequences += normalized.scopeSequences
            decodedThemeReferences += normalized.pypThemes
            decodedNamedThemes += normalized.namedPYPThemes
        }

        self.standards = Self.deduplicatedByID(decodedStandards)
        self.syllabusItems = Self.deduplicatedByID(decodedSyllabusItems)
        self.scopeSequences = Self.deduplicatedByID(decodedScopeSequences)
        self.pypThemeReferences = Self.deduplicatedByID(decodedThemeReferences)
        self.namedPYPThemes = Self.deduplicatedByID(decodedNamedThemes)
    }

    private static func normalizeComponentPayloads(_ componentPayloads: [UnitComponentPayload]) -> NormalizedComponents {
        var normalized = NormalizedComponents()

        for payload in componentPayloads {
            let componentName = Self.normalizedComponentName(payload.name)

            guard let data = payload.data else {
                continue
            }

            switch componentName {
            case "standards":
                if let itemStandards = data.standards {
                    normalized.standards.append(contentsOf: itemStandards)
                }
                normalized.standards.append(
                    contentsOf: Self.standardReferences(from: data.standardTextValues, namespace: "standard")
                )
            case "syllabus", "syllabus_items", "syllabuses":
                if let items = data.syllabusItems {
                    normalized.syllabusItems.append(contentsOf: items)
                }
            case "scope_sequence", "scope_sequences", "scope", "scope-sequences":
                if let items = data.scopeSequences {
                    normalized.scopeSequences.append(contentsOf: items)
                }
            case "tr_theme", "tr_themes", "pyp_theme", "pyp_themes":
                let namedThemes = data.themeNames
                    .map { name in
                        Self.normalizedThemeItem(from: name, parentTitle: data.themeTitle)
                    }

                normalized.pypThemes.append(contentsOf: namedThemes.map { MBTRThemeReference(id: $0.sourceID) })
                normalized.namedPYPThemes.append(contentsOf: namedThemes)
            case "key_concepts", "unit_key_concepts":
                let keyConceptItems = data.keyConcepts + data.unitKeyConcepts
                normalized.standards.append(
                    contentsOf: Self.standardReferences(from: keyConceptItems, namespace: "key-concept")
                )
            case "approaches_to_learning", "atl", "atls":
                normalized.standards.append(
                    contentsOf: Self.standardReferences(from: data.atlSkills, namespace: "atl")
                )
            case "dispositions", "learner_profiles":
                normalized.standards.append(
                    contentsOf: Self.standardReferences(from: data.learnerProfiles, namespace: "learner-profile")
                )
            default:
                continue
            }
        }

        return normalized
    }

    private static func normalizedComponentName(_ name: String?) -> String {
        let normalized = (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let withoutPrefix = normalized.replacingOccurrences(of: "unit::component::", with: "")
        return withoutPrefix.replacingOccurrences(of: "-", with: "_")
    }

    private static func standardReferences(
        from textValues: [String],
        namespace: String,
        startIndex: Int = 0
    ) -> [MBUnitStandard] {
        textValues.enumerated().map { (offset, value) in
            MBUnitStandard(
                id: "\(namespace)-\(Self.stableID(for: value, namespace: namespace))-\(startIndex + offset)",
                title: value
            )
        }
        .filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    private static func normalizedThemeItem(from title: String, parentTitle: String?) -> NamedPYPTheme {
        let sourceID = "theme-\(stableID(for: title, namespace: "theme"))"
        return NamedPYPTheme(sourceID: sourceID, title: title, parentTitle: parentTitle, isGenerated: true)
    }

    private static func stableID(for text: String, namespace: String) -> String {
        var hash = UInt64(1469598103934665603)
        for byte in "\(namespace)::\(text)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        let compact = String(hash, radix: 16, uppercase: false)
        return String(compact.prefix(10))
    }

    private static func deduplicatedByID(_ values: [MBUnitStandard]) -> [MBUnitStandard] {
        var seen: Set<String> = []
        return values.filter {
            let key = $0.id
            guard seen.insert(key).inserted else {
                return false
            }

            return true
        }
    }

    private static func deduplicatedByID(_ values: [MBSyllabusItem]) -> [MBSyllabusItem] {
        var seen: Set<String> = []
        return values.filter {
            guard seen.insert($0.id).inserted else {
                return false
            }

            return true
        }
    }

    private static func deduplicatedByID(_ values: [MBScopeSequence]) -> [MBScopeSequence] {
        var seen: Set<String> = []
        return values.filter {
            guard seen.insert($0.id).inserted else {
                return false
            }

            return true
        }
    }

    private static func deduplicatedByID(_ values: [MBTRThemeReference]) -> [MBTRThemeReference] {
        var seen: Set<String> = []
        return values.filter {
            guard seen.insert($0.id).inserted else {
                return false
            }

            return true
        }
    }

    private static func deduplicatedByID(_ values: [NamedPYPTheme]) -> [NamedPYPTheme] {
        var seen: Set<String> = []
        return values.filter {
            guard seen.insert($0.sourceID).inserted else {
                return false
            }

            return true
        }
    }

    private struct NormalizedComponents: Sendable {
        var standards: [MBUnitStandard] = []
        var syllabusItems: [MBSyllabusItem] = []
        var scopeSequences: [MBScopeSequence] = []
        var pypThemes: [MBTRThemeReference] = []
        var namedPYPThemes: [NamedPYPTheme] = []
    }

    private struct UnitComponentPayload: Decodable, Sendable {
        let name: String?
        let data: UnitComponentData?

        private enum CodingKeys: String, CodingKey {
            case name
            case data
        }
    }

    private struct UnitComponentData: Decodable, Sendable {
        let standards: [MBUnitStandard]?
        let standardTextValues: [String]
        let syllabusItems: [MBSyllabusItem]?
        let scopeSequences: [MBScopeSequence]?
        let themeTitle: String?
        let themeNames: [String]
        let keyConcepts: [String]
        let unitKeyConcepts: [String]
        let atlSkills: [String]
        let learnerProfiles: [String]

        private enum CodingKeys: String, CodingKey {
            case standards
            case standardTextValues = "standards_text"
            case syllabusItems = "syllabus_items"
            case syllabusItemsLegacy = "syllabusItems"
            case scopeSequences = "scope_sequences"
            case themeTitle = "title"
            case themeNames = "list"
            case keyConcepts = "key_concepts"
            case unitKeyConcepts = "unit_key_concepts"
            case atlSkills = "atls"
            case learnerProfiles = "learner_profiles"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            standards = try container.decodeIfPresent([MBUnitStandard].self, forKey: .standards)

            standardTextValues = (try? container.decodeIfPresent([String].self, forKey: .standardTextValues))
                ?? []

            syllabusItems = (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItems))
                ?? (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItemsLegacy))
                ?? []

            scopeSequences = (try? container.decodeIfPresent([MBScopeSequence].self, forKey: .scopeSequences))
                ?? []

            themeTitle = try? container.decodeIfPresent(String.self, forKey: .themeTitle)
            let directThemeNames = (try? container.decodeIfPresent([String].self, forKey: .themeNames)) ?? []
            let objectThemeNames = (try? container.decodeIfPresent([UnitNamedValue].self, forKey: .themeNames)) ?? []
            themeNames = directThemeNames + objectThemeNames.map(\.name)
            keyConcepts = (try? container.decodeIfPresent([String].self, forKey: .keyConcepts)) ?? []
            unitKeyConcepts = (try? container.decodeIfPresent([String].self, forKey: .unitKeyConcepts)) ?? []
            atlSkills = (try? container.decodeIfPresent([String].self, forKey: .atlSkills)) ?? []
            learnerProfiles = (try? container.decodeIfPresent([String].self, forKey: .learnerProfiles)) ?? []
        }

        private struct UnitNamedValue: Decodable, Sendable {
            let name: String

            private enum CodingKeys: String, CodingKey {
                case name
                case title
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let nameValue = try? container.decode(String.self, forKey: .name) {
                    name = nameValue
                    return
                }

                if let titleValue = try? container.decode(String.self, forKey: .title) {
                    name = titleValue
                    return
                }

                throw DecodingError.dataCorruptedError(
                    forKey: .name,
                    in: container,
                    debugDescription: "Expected a theme name field."
                )
            }
        }
    }
}

public struct NamedPYPTheme: Decodable, Equatable, Sendable {
    public let sourceID: String
    public let title: String
    public let parentTitle: String?
    public let isGenerated: Bool

    public init(sourceID: String, title: String, parentTitle: String? = nil, isGenerated: Bool = false) {
        self.sourceID = sourceID
        self.title = title
        self.parentTitle = parentTitle
        self.isGenerated = isGenerated
    }

    private enum CodingKeys: String, CodingKey {
        case sourceID
        case sourceId
        case id
        case title
        case name
        case parentTitle
        case parent_title
        case isGenerated
        case is_generated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let sourceIDValue = try? container.decode(String.self, forKey: .sourceID) {
            sourceID = sourceIDValue
        } else if let sourceIDValue = try? container.decode(String.self, forKey: .sourceId) {
            sourceID = sourceIDValue
        } else {
            sourceID = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        }

        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else if let nameValue = try? container.decode(String.self, forKey: .name) {
            title = nameValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "Expected a title/name for named PYP theme."
            )
        }

        parentTitle = (try? container.decodeIfPresent(String.self, forKey: .parentTitle))
            ?? (try? container.decodeIfPresent(String.self, forKey: .parent_title))
        isGenerated = (try? container.decodeIfPresent(Bool.self, forKey: .isGenerated))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .is_generated))
            ?? false
    }
}

public struct MBUnitStandard: Decodable, Equatable, Sendable {
    public let id: String
    public let code: String?
    public let label: String?
    public let title: String
    public let description: String?

    public init(
        id: String,
        code: String? = nil,
        label: String? = nil,
        title: String,
        description: String? = nil
    ) {
        self.id = id
        self.code = code
        self.label = label
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case label
        case title
        case name
        case text
        case description
        case details
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? (try? container.decode(String.self, forKey: .details))

        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else if let nameValue = try? container.decode(String.self, forKey: .name) {
            title = nameValue
        } else if let textValue = try? container.decode(String.self, forKey: .text) {
            title = textValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "Expected a title-like field for unit standard."
            )
        }
    }
}

public struct MBSyllabusItem: Decodable, Equatable, Sendable {
    public let id: String
    public let code: String?
    public let title: String
    public let description: String?

    public init(id: String, code: String? = nil, title: String, description: String? = nil) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case title
        case name
        case text
        case description
        case details
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? (try? container.decode(String.self, forKey: .details))

        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else if let nameValue = try? container.decode(String.self, forKey: .name) {
            title = nameValue
        } else if let textValue = try? container.decode(String.self, forKey: .text) {
            title = textValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "Expected a title-like field for syllabus item."
            )
        }
    }
}

public struct MBScopeSequence: Decodable, Equatable, Sendable {
    public let id: String
    public let code: String?
    public let title: String
    public let description: String?

    public init(id: String, code: String? = nil, title: String, description: String? = nil) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case title
        case name
        case text
        case description
        case details
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? (try? container.decode(String.self, forKey: .details))

        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else if let nameValue = try? container.decode(String.self, forKey: .name) {
            title = nameValue
        } else if let textValue = try? container.decode(String.self, forKey: .text) {
            title = textValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "Expected a title-like field for scope sequence."
            )
        }
    }
}

public struct MBTRThemeReference: Decodable, Equatable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case themeID = "theme_id"
        case themeId = "themeId"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
            return
        }

        if let intValue = try? container.decode(Int.self, forKey: .id) {
            id = String(intValue)
            return
        }

        if let idValue = try? container.decode(String.self, forKey: .themeID) {
            id = idValue
            return
        }

        if let intValue = try? container.decode(Int.self, forKey: .themeID) {
            id = String(intValue)
            return
        }

        if let idValue = try? container.decode(String.self, forKey: .themeId) {
            id = idValue
            return
        }

        if let intValue = try? container.decode(Int.self, forKey: .themeId) {
            id = String(intValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            forKey: .id,
            in: container,
            debugDescription: "Expected a string or integer identifier for TR theme reference."
        )
    }
}

public struct MBTRTheme: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let order: Int?
    public let descriptions: [MBTRThemeDescription]

    public init(
        id: String,
        name: String,
        description: String? = nil,
        order: Int? = nil,
        descriptions: [MBTRThemeDescription] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.order = order
        self.descriptions = descriptions
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case id
        case name
        case title
        case list
        case description
        case details
        case order
        case sequence
        case icon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.data) {
            self = try container.decode(MBTRTheme.self, forKey: .data)
            return
        }

        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)

        if let titleValue = try? container.decode(String.self, forKey: .name) {
            name = titleValue
        } else if let titleValue = try? container.decode(String.self, forKey: .title) {
            name = titleValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Expected a TR theme title/name."
            )
        }

        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? (try? container.decode(String.self, forKey: .details))

        order = try container.decodeIfPresent(Int.self, forKey: .order)
            ?? (try? container.decode(Int.self, forKey: .sequence))
        descriptions = (try? container.decodeIfPresent([MBTRThemeDescriptionGroup].self, forKey: .list))?
            .flatMap(\.options) ?? []
    }
}

public struct MBTRThemeDescription: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let year: Int?
    public let label: String?

    public init(id: String, name: String, year: Int? = nil, label: String? = nil) {
        self.id = id
        self.name = name
        self.year = year
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case year
        case label
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        label = try container.decodeIfPresent(String.self, forKey: .label)

        if let nameValue = try? container.decode(String.self, forKey: .name) {
            name = nameValue
        } else if let titleValue = try? container.decode(String.self, forKey: .title) {
            name = titleValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Expected a TR theme description name."
            )
        }
    }
}

private struct MBTRThemeDescriptionGroup: Decodable, Equatable, Sendable {
    let year: Int?
    let label: String?
    let options: [MBTRThemeDescription]

    private enum CodingKeys: String, CodingKey {
        case year
        case label
        case options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let groupYear = try container.decodeIfPresent(Int.self, forKey: .year)
        let groupLabel = try container.decodeIfPresent(String.self, forKey: .label)
        let rawOptions = try container.decodeIfPresent([MBTRThemeDescription].self, forKey: .options) ?? []
        let resolvedOptions = rawOptions.map {
            MBTRThemeDescription(
                id: $0.id,
                name: $0.name,
                year: $0.year ?? groupYear,
                label: $0.label ?? groupLabel
            )
        }
        year = groupYear
        label = groupLabel
        options = resolvedOptions
    }
}
