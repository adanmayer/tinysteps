import Foundation

public struct MBClassUnit: Identifiable, Codable, Equatable, Sendable {
    public enum SubItemType: String, Codable, Equatable, Sendable {
        case none
        case streams
        case lessonExperiences
    }

    public let id: String
    public let title: String
    public let durationInWeeks: Int?
    public let streamsCount: Int?
    public let lessonExperiencesCount: Int?
    public let coverURL: URL?
    public let detailURL: URL?
    public let labels: [String]
    public let summary: String?
    public let isIDU: Bool?

    public init(
        id: String,
        title: String,
        durationInWeeks: Int? = nil,
        streamsCount: Int? = nil,
        lessonExperiencesCount: Int? = nil,
        coverURL: URL? = nil,
        detailURL: URL? = nil,
        labels: [String] = [],
        summary: String? = nil,
        isIDU: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.durationInWeeks = durationInWeeks
        self.streamsCount = streamsCount
        self.lessonExperiencesCount = lessonExperiencesCount
        self.coverURL = coverURL
        self.detailURL = detailURL
        self.labels = labels
        self.summary = summary
        self.isIDU = isIDU
    }

    public var subItemType: SubItemType {
        if let lessonExperiences = lessonExperiencesCount, lessonExperiences > 0 {
            return .lessonExperiences
        }

        if let streams = streamsCount, streams > 0 {
            return .streams
        }

        return .none
    }

    public var hasSubItems: Bool {
        subItemType != .none
    }

    public var subItemCount: Int {
        let lessonCount = lessonExperiencesCount ?? 0
        if lessonCount > 0 {
            return lessonCount
        }

        return streamsCount ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationInWeeks = "duration_in_weeks"
        case streamsCount = "streams_count"
        case lessonExperiencesCount = "lesson_experiences_count"
        case coverURL = "cover_url"
        case detailURL = "url"
        case labels
        case summary = "description"
        case isIDU = "idu"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        durationInWeeks = Self.decodeOptionalInt(from: container, forKey: .durationInWeeks)
        streamsCount = Self.decodeOptionalInt(from: container, forKey: .streamsCount)
        lessonExperiencesCount = Self.decodeOptionalInt(from: container, forKey: .lessonExperiencesCount)
        coverURL = Self.decodeOptionalURL(from: container, forKey: .coverURL)
        detailURL = Self.decodeOptionalURL(from: container, forKey: .detailURL)
        labels = (
            (try? container.decodeIfPresent([String].self, forKey: .labels))
            ?? (try? container.decodeIfPresent([Label].self, forKey: .labels))?.compactMap { label in
                let value = label.title ?? label.name ?? label.text
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == true ? nil : trimmed
            }
        ) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        isIDU = Self.decodeOptionalBool(from: container, forKey: .isIDU)
    }

    private static func decodeOptionalInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }

        if let value = try? container.decode(Int64.self, forKey: key) {
            return Int(value)
        }

        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    private static func decodeOptionalBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }

        if let value = try? container.decode(Int.self, forKey: key) {
            return value != 0
        }

        if let value = try? container.decode(String.self, forKey: key) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "y"].contains(normalized) {
                return true
            }
            if ["0", "false", "no", "n"].contains(normalized) {
                return false
            }
        }

        return nil
    }

    private static func decodeOptionalURL(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> URL? {
        if let raw = try? container.decode(String.self, forKey: key) {
            return URL(string: raw)
        }

        if let value = try? container.decode(URL.self, forKey: key) {
            return value
        }

        return nil
    }

    private struct Label: Codable {
        let title: String?
        let name: String?
        let text: String?

        private enum CodingKeys: String, CodingKey {
            case title
            case name
            case text
        }
    }
}
