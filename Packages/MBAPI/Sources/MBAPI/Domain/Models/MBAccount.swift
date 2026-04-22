import Foundation

public struct MBAccount: Codable, Equatable, Sendable {
    public let id: String
    public let role: MBAPIRole
    public let fullName: String?
    public let firstName: String?
    public let lastName: String?
    public let email: String?
    public let photoURL: URL?

    public init(
        id: String,
        role: MBAPIRole,
        fullName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        photoURL: URL? = nil
    ) {
        self.id = id
        self.role = role
        self.fullName = fullName
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.photoURL = photoURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case roleId = "role_id"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case photoURL = "photo_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        let roleValue = try Self.decodeAccountRole(from: container)
        role = MBAPIRole(rawValue: roleValue ?? "") ?? .parent
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        photoURL = try container.decodeIfPresent(URL.self, forKey: .photoURL)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
    }

    private static func decodeAccountRole(from container: KeyedDecodingContainer<CodingKeys>) throws -> String? {
        if let role = try decodeStringRole(from: container, keys: [.role]), role.isEmpty == false {
            return role
        }

        if let roleID = try decodeStringRole(from: container, keys: [.roleId]), roleID.isEmpty == false {
            return roleID
        }

        return nil
    }

    private static func decodeStringRole(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> String? {
        for key in keys {
            if let value = try container.decodeIfPresent(String.self, forKey: key),
               value.isEmpty == false {
                return normalizedRoleString(value)
            }
            if let value = try container.decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                return "\(Int(value))"
            }
        }

        return nil
    }

    private static func normalizedRoleString(_ role: String) -> String {
        role
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
