import Foundation

public struct MBAttendanceExcusalSubmission: Codable, Sendable {
    public let date: String
    public let endDate: String
    public let duration: Int
    public let comment: String

    public init(date: String, endDate: String, duration: Int, comment: String) {
        self.date = date
        self.endDate = endDate
        self.duration = duration
        self.comment = comment
    }

    public init(startDate: Date, duration: Int, comment: String, calendar: Calendar = .current) {
        let safeDuration = max(1, duration)
        let endDate = calendar.date(byAdding: .day, value: safeDuration - 1, to: startDate) ?? startDate

        self.date = Self.apiDateFormatter.string(from: startDate)
        self.endDate = Self.apiDateFormatter.string(from: endDate)
        self.duration = safeDuration
        self.comment = comment
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case endDate = "end_date"
        case duration
        case comment
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
