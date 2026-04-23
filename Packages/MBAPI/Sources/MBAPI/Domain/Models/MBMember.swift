import Foundation

public struct MBMember: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let groupID: String?
    public let joinedAt: String?
    public let accessedAt: String?
    public let level: String?
    public let user: MBMemberUser
    public let canRemove: Bool?
    public let showOnReports: Bool?
    public let preApproved: Bool?
    public let approved: Bool?
    public let groupAdvisor: Bool?
    public let primaryAdvisor: Bool?
    public let studentID: String?
    public let casStatus: MBMemberCasStatus?

    public let edit: MBMemberEdit?

    public init(
        id: String,
        groupID: String? = nil,
        joinedAt: String? = nil,
        accessedAt: String? = nil,
        level: String? = nil,
        user: MBMemberUser,
        canRemove: Bool? = nil,
        showOnReports: Bool? = nil,
        preApproved: Bool? = nil,
        approved: Bool? = nil,
        groupAdvisor: Bool? = nil,
        primaryAdvisor: Bool? = nil,
        studentID: String? = nil,
        casStatus: MBMemberCasStatus? = nil,
        edit: MBMemberEdit? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.joinedAt = joinedAt
        self.accessedAt = accessedAt
        self.level = level
        self.user = user
        self.canRemove = canRemove
        self.showOnReports = showOnReports
        self.preApproved = preApproved
        self.approved = approved
        self.groupAdvisor = groupAdvisor
        self.primaryAdvisor = primaryAdvisor
        self.studentID = studentID
        self.casStatus = casStatus
        self.edit = edit
    }

    public var canEdit: Bool {
        canRemove ?? false
    }

    public static let unknown = MBMember(
        id: "0",
        user: MBMemberUser(id: "0", fullName: "", email: nil)
    )

    private enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case joinedAt = "joined_at"
        case accessedAt = "accessed_at"
        case level
        case user
        case canRemove = "can_remove"
        case showOnReports = "show_on_reports"
        case preApproved = "pre_approved"
        case approved
        case groupAdvisor = "group_advisor"
        case primaryAdvisor = "primary_advisor"
        case studentID = "student_id"
        case casStatus = "cas_status"
        case edit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        groupID = try MBModelCoding.decodeOptionalStringID(from: container, forKey: .groupID)
        joinedAt = try container.decodeIfPresent(String.self, forKey: .joinedAt)
        accessedAt = try container.decodeIfPresent(String.self, forKey: .accessedAt)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        user = try container.decode(MBMemberUser.self, forKey: .user)
        canRemove = try container.decodeIfPresent(Bool.self, forKey: .canRemove)
        showOnReports = try container.decodeIfPresent(Bool.self, forKey: .showOnReports)
        preApproved = try container.decodeIfPresent(Bool.self, forKey: .preApproved)
        approved = try container.decodeIfPresent(Bool.self, forKey: .approved)
        groupAdvisor = try container.decodeIfPresent(Bool.self, forKey: .groupAdvisor)
        primaryAdvisor = try container.decodeIfPresent(Bool.self, forKey: .primaryAdvisor)
        studentID = try container.decodeIfPresent(String.self, forKey: .studentID)
        casStatus = try container.decodeIfPresent(MBMemberCasStatus.self, forKey: .casStatus)
        edit = try container.decodeIfPresent(MBMemberEdit.self, forKey: .edit)
    }
}

public enum MBMemberCasStatus: String, Codable, Equatable, Sendable {
    case completed = "cas_completed"
    case approved = "cas_approved"
    case needsApproval = "cas_needs_approval"
}

public struct MBMemberUser: Codable, Equatable, Sendable {
    public let id: String
    public let fullName: String
    public let email: String?
    public let avatarURL: URL?
    public let initials: String?
    public let role: String?

    public init(
        id: String,
        fullName: String,
        email: String? = nil,
        avatarURL: URL? = nil,
        initials: String? = nil,
        role: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.avatarURL = avatarURL
        self.initials = initials
        self.role = role
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case avatarURL = "avatar_url"
        case photoURL = "photo_url"
        case initials
        case role
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
            ?? container.decodeIfPresent(URL.self, forKey: .photoURL)
        initials = try container.decodeIfPresent(String.self, forKey: .initials)
        role = try container.decodeIfPresent(String.self, forKey: .role)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(initials, forKey: .initials)
        try container.encodeIfPresent(role, forKey: .role)
    }
}

public struct MBMemberEdit: Codable, Equatable, Sendable {
    public let userID: String?
    public let level: String?
    public let showOnReports: Bool?
    public let preApproved: Bool?
    public let approved: Bool?
    public let userIDs: [String]?

    public init(
        userID: String? = nil,
        level: String? = nil,
        showOnReports: Bool? = nil,
        preApproved: Bool? = nil,
        approved: Bool? = nil,
        userIDs: [String]? = nil
    ) {
        self.userID = userID
        self.level = level
        self.showOnReports = showOnReports
        self.preApproved = preApproved
        self.approved = approved
        self.userIDs = userIDs
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case level
        case showOnReports = "show_on_reports"
        case preApproved = "pre_approved"
        case approved
        case userIDs = "user_ids"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        showOnReports = try container.decodeIfPresent(Bool.self, forKey: .showOnReports)
        preApproved = try container.decodeIfPresent(Bool.self, forKey: .preApproved)
        approved = try container.decodeIfPresent(Bool.self, forKey: .approved)
        userIDs = try container.decodeIfPresent([String].self, forKey: .userIDs)
    }
}
