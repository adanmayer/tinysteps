import Foundation

public struct MBAttendanceExcusal: Codable, Equatable, Sendable {
    public let id: Int64?
    public let date: String?
    public let endDate: String?
    public let duration: Int?
    public let comment: String?

    public init(
        id: Int64? = nil,
        date: String? = nil,
        endDate: String? = nil,
        duration: Int? = nil,
        comment: String? = nil
    ) {
        self.id = id
        self.date = date
        self.endDate = endDate
        self.duration = duration
        self.comment = comment
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case endDate = "end_date"
        case duration
        case comment
    }
}
