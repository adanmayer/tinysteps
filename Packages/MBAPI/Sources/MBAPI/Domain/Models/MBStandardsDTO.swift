import Foundation

public struct MBUnitComponents: Decodable, Equatable, Sendable {
    public let standards: [MBUnitStandard]
    public let syllabusItems: [MBSyllabusItem]
    public let scopeSequences: [MBScopeSequence]
    public let pypThemeReferences: [MBTRThemeReference]

    public init(
        standards: [MBUnitStandard] = [],
        syllabusItems: [MBSyllabusItem] = [],
        scopeSequences: [MBScopeSequence] = [],
        pypThemeReferences: [MBTRThemeReference] = []
    ) {
        self.standards = standards
        self.syllabusItems = syllabusItems
        self.scopeSequences = scopeSequences
        self.pypThemeReferences = pypThemeReferences
    }

    private enum CodingKeys: String, CodingKey {
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
        standards = try container.decodeIfPresent([MBUnitStandard].self, forKey: .standards) ?? []
        syllabusItems = (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItems))
            ?? (try? container.decodeIfPresent([MBSyllabusItem].self, forKey: .syllabusItemsLegacy))
            ?? []
        scopeSequences = (try? container.decodeIfPresent([MBScopeSequence].self, forKey: .scopeSequences))
            ?? (try? container.decodeIfPresent([MBScopeSequence].self, forKey: .scopeSequencesLegacy))
            ?? []
        pypThemeReferences = (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .trThemes))
            ?? (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .pypThemes))
            ?? (try? container.decodeIfPresent([MBTRThemeReference].self, forKey: .themeReferences))
            ?? []
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
