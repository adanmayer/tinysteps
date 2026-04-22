import Foundation

public struct MBChild: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let normalizedFullName: String?
    public let roleID: String?
    public let role: String?
    public let profileURL: URL?
    public let email: String?
    public let labels: [MBChildLabel]
    public let gradeLevel: String?
    public let campusName: String?
    public let initials: String
    public let avatarURL: URL?

    public init(
        id: String,
        displayName: String,
        normalizedFullName: String? = nil,
        roleID: String? = nil,
        role: String? = nil,
        profileURL: URL? = nil,
        email: String? = nil,
        labels: [MBChildLabel] = [],
        gradeLevel: String? = nil,
        campusName: String? = nil,
        initials: String = "",
        avatarURL: URL? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedFullName = normalizedFullName
        self.roleID = roleID
        self.role = role
        self.profileURL = profileURL
        self.email = email
        self.labels = labels
        self.gradeLevel = gradeLevel
        self.campusName = campusName
        self.initials = initials
        self.avatarURL = avatarURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "full_name"
        case normalizedFullName = "normalized_full_name"
        case roleID = "role_id"
        case role
        case profileURL = "url"
        case email
        case labels
        case gradeLevel
        case campusName
        case initials
        case avatarURL = "photo_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        normalizedFullName = try container.decodeIfPresent(String.self, forKey: .normalizedFullName)
        roleID = try container.decodeIfPresent(String.self, forKey: .roleID)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        profileURL = try container.decodeIfPresent(URL.self, forKey: .profileURL)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        labels = try container.decodeIfPresent([MBChildLabel].self, forKey: .labels) ?? []
        gradeLevel = try container.decodeIfPresent(String.self, forKey: .gradeLevel)
        campusName = try container.decodeIfPresent(String.self, forKey: .campusName)
        initials = try container.decodeIfPresent(String.self, forKey: .initials) ?? ""
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
    }

    public var secondaryText: String? {
        let parts: [String] = [gradeLevel, campusName].compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }

            return value
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: " • ")
    }
}

public struct MBChildLabel: Codable, Equatable, Sendable {
    public let title: String?
    public let style: MBChildLabelStyle?
    public let color: String?

    public init(
        title: String? = nil,
        style: MBChildLabelStyle? = nil,
        color: String? = nil
    ) {
        self.title = title
        self.style = style
        self.color = color
    }
}

public struct MBChildLabelStyle: Codable, Equatable, Sendable {
    public let textColor: String?
    public let borderColor: String?
    public let backgroundColor: String?

    public init(
        textColor: String? = nil,
        borderColor: String? = nil,
        backgroundColor: String? = nil
    ) {
        self.textColor = textColor
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
    }

    private enum CodingKeys: String, CodingKey {
        case textColor = "text_color"
        case borderColor = "border_color"
        case backgroundColor = "background_color"
    }
}
