import Foundation

public struct MBClass: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let iconName: String
    public let labels: [MBClassLabel]
    public let detailURL: URL?
    public let isLocked: Bool
    public let isMember: Bool
    public let program: MBClassProgram?
    public let uniqueID: String?
    public let defaultTerm: MBClassTerm?
    public let terms: [MBClassTerm]

    public init(
        id: String,
        displayName: String,
        iconName: String,
        labels: [MBClassLabel] = [],
        detailURL: URL? = nil,
        isLocked: Bool,
        isMember: Bool,
        program: MBClassProgram? = nil,
        uniqueID: String? = nil,
        defaultTerm: MBClassTerm? = nil,
        terms: [MBClassTerm] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.labels = labels
        self.detailURL = detailURL
        self.isLocked = isLocked
        self.isMember = isMember
        self.program = program
        self.uniqueID = uniqueID
        self.defaultTerm = defaultTerm
        self.terms = terms
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "name"
        case iconName = "icon"
        case labels
        case detailURL = "url"
        case isLocked = "locked"
        case isMember = "member"
        case program
        case uniqueID = "uniq_id"
        case defaultTerm = "default_term"
        case terms
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? ""
        labels = try container.decodeIfPresent([MBClassLabel].self, forKey: .labels) ?? []
        detailURL = try container.decodeIfPresent(URL.self, forKey: .detailURL)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        isMember = try container.decode(Bool.self, forKey: .isMember)
        program = try container.decodeIfPresent(MBClassProgram.self, forKey: .program)
        uniqueID = try container.decodeIfPresent(String.self, forKey: .uniqueID)
        defaultTerm = try container.decodeIfPresent(MBClassTerm.self, forKey: .defaultTerm)
        terms = try container.decodeIfPresent([MBClassTerm].self, forKey: .terms) ?? []
    }
}

public struct MBClassLabel: Codable, Equatable, Sendable {
    public let title: String?
    public let icon: String?
    public let progress: Double?
    public let style: MBChildLabelStyle?

    public init(
        title: String? = nil,
        icon: String? = nil,
        progress: Double? = nil,
        style: MBChildLabelStyle? = nil
    ) {
        self.title = title
        self.icon = icon
        self.progress = progress
        self.style = style
    }
}

public struct MBClassProgram: Codable, Equatable, Sendable {
    public let uid: String?
    public let code: String
    public let name: String
    public let shortName: String?
    public let iconName: String?
    public let color: String?

    public init(
        uid: String? = nil,
        code: String,
        name: String,
        shortName: String? = nil,
        iconName: String? = nil,
        color: String? = nil
    ) {
        self.uid = uid
        self.code = code
        self.name = name
        self.shortName = shortName
        self.iconName = iconName
        self.color = color
    }

    private enum CodingKeys: String, CodingKey {
        case uid
        case code
        case name
        case shortName = "short_name"
        case iconName = "icon"
        case color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        color = try container.decodeIfPresent(String.self, forKey: .color)

        if let stringUID = try? container.decode(String.self, forKey: .uid) {
            uid = stringUID
        } else if let intUID = try? container.decode(Int64.self, forKey: .uid) {
            uid = String(intUID)
        } else {
            uid = nil
        }
    }
}

public struct MBClassTerm: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? container.decode(Int64.self, forKey: .id) {
            id = String(intID)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Expected a string or integer term id.")
        }
    }
}
