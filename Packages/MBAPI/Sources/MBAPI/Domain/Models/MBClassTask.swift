import Foundation

public struct MBClassTask: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let groupID: String?
    public let groupName: String?
    public let startAt: String?
    public let endAt: String?
    public let backgroundColor: String?
    public let textColor: String?
    public let allDay: Bool?
    public let category: String?
    public let type: String?
    public let url: URL?
    public let labels: [String]
    public let actions: [String]
    public let dropboxID: String?
    public let onlineAssessmentID: String?
    public let taskCategory: MBClassTaskCategory?
    public let memberCount: Int?

    public init(
        id: String,
        name: String,
        groupID: String? = nil,
        groupName: String? = nil,
        startAt: String? = nil,
        endAt: String? = nil,
        backgroundColor: String? = nil,
        textColor: String? = nil,
        allDay: Bool? = nil,
        category: String? = nil,
        type: String? = nil,
        url: URL? = nil,
        labels: [String] = [],
        actions: [String] = [],
        dropboxID: String? = nil,
        onlineAssessmentID: String? = nil,
        taskCategory: MBClassTaskCategory? = nil,
        memberCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.groupID = groupID
        self.groupName = groupName
        self.startAt = startAt
        self.endAt = endAt
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.allDay = allDay
        self.category = category
        self.type = type
        self.url = url
        self.labels = labels
        self.actions = actions
        self.dropboxID = dropboxID
        self.onlineAssessmentID = onlineAssessmentID
        self.taskCategory = taskCategory
        self.memberCount = memberCount
    }

    public var displayTitle: String {
        name
    }

    public var isOnlineAssessmentLinked: Bool {
        onlineAssessmentID != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case groupID = "group_id"
        case groupName = "group_name"
        case startAt = "start_at"
        case endAt = "end_at"
        case backgroundColor = "bgcolor"
        case textColor = "fgcolor"
        case allDay = "all_day"
        case category
        case type
        case url
        case labels
        case actions
        case dropboxID = "dropbox_id"
        case onlineAssessmentID = "online_assessment_id"
        case taskCategory = "task_category"
        case memberCount = "member_count"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        groupID = try MBModelCoding.decodeOptionalStringID(
            from: container,
            forKey: .groupID
        )
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        startAt = try container.decodeIfPresent(String.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(String.self, forKey: .endAt)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor)
        allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        labels = (
            (try? container.decodeIfPresent([String].self, forKey: .labels))
            ?? (try? container.decodeIfPresent([Label].self, forKey: .labels))?.compactMap { label in
                let title = label.title ?? label.name
                let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == true ? nil : trimmed
            }
        ) ?? []
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        dropboxID = try MBModelCoding.decodeOptionalStringID(
            from: container,
            forKey: .dropboxID
        )
        onlineAssessmentID = try MBModelCoding.decodeOptionalStringID(
            from: container,
            forKey: .onlineAssessmentID
        )
        taskCategory = try container.decodeIfPresent(MBClassTaskCategory.self, forKey: .taskCategory)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
    }

    private struct Label: Codable {
        let title: String?
        let name: String?

        private enum CodingKeys: String, CodingKey {
            case title
            case name
        }
    }
}

public struct MBClassTaskCategory: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let weight: Int?
    public let style: MBChildLabelStyle?

    public init(
        id: String,
        name: String,
        weight: Int? = nil,
        style: MBChildLabelStyle? = nil
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.style = style
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case weight
        case style
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weight = try container.decodeIfPresent(Int.self, forKey: .weight)
        style = try container.decodeIfPresent(MBChildLabelStyle.self, forKey: .style)
    }
}
