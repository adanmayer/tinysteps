import Foundation

public struct MBParentAssociationMenuItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let url: String?
    public let icon: String?
    public let subtitle: String?
    public let nestedMenu: [NestedItem]?
    public let unread: String?

    public init(
        id: String,
        title: String,
        url: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        nestedMenu: [NestedItem]? = nil,
        unread: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.icon = icon
        self.subtitle = subtitle
        self.nestedMenu = nestedMenu
        self.unread = unread
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case icon
        case subtitle
        case nestedMenu = "nested_menu"
        case unread
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        nestedMenu = try container.decodeIfPresent([NestedItem].self, forKey: .nestedMenu)
        unread = try container.decodeIfPresent(String.self, forKey: .unread)
    }

    public struct NestedItem: Codable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let url: String?
        public let dotColor: String?
        public let icon: String?
        public let unread: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case url
            case dotColor = "dot_color"
            case icon
            case unread
        }

        public init(
            id: String,
            title: String,
            url: String? = nil,
            dotColor: String? = nil,
            icon: String? = nil,
            unread: String? = nil
        ) {
            self.id = id
            self.title = title
            self.url = url
            self.dotColor = dotColor
            self.icon = icon
            self.unread = unread
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            dotColor = try container.decodeIfPresent(String.self, forKey: .dotColor)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            unread = try container.decodeIfPresent(String.self, forKey: .unread)
        }
    }
}
