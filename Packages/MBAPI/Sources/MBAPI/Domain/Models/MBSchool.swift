import Foundation

public struct MBSchool: Codable, Equatable, Sendable {
    public let attendanceEnabled: Bool
    public let parentExcusalsEnabled: Bool

    public init(attendanceEnabled: Bool, parentExcusalsEnabled: Bool) {
        self.attendanceEnabled = attendanceEnabled
        self.parentExcusalsEnabled = parentExcusalsEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case attendanceEnabled = "attendance_enabled"
        case parentExcusalsEnabled = "parent_excusals_enabled"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attendanceEnabled = try container.decodeIfPresent(Bool.self, forKey: .attendanceEnabled) ?? false
        parentExcusalsEnabled = try container.decodeIfPresent(Bool.self, forKey: .parentExcusalsEnabled) ?? false
    }
}
