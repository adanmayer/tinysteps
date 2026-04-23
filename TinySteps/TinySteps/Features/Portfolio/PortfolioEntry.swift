import Foundation
import MBAPI

enum PortfolioTimelineRole: Equatable, Sendable {
    case teacherStream
    case parentJournal

    var defaultRange: PortfolioRangeFilter {
        switch self {
        case .teacherStream:
            return .today
        case .parentJournal:
            return .all
        }
    }
}

enum PortfolioRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case all = "All"

    var id: String {
        rawValue
    }
}

enum PortfolioEntryKind: String, CaseIterable, Sendable {
    case note = "Note"
    case photo = "Photo"
    case image = "Image"
    case video = "Video"
    case file = "File"
    case website = "Website"
    case reflection = "Reflection"
    case event = "Event"
    case unknown = "Moment"

    var systemImage: String {
        switch self {
        case .note:
            return "line.3.horizontal"
        case .photo:
            return "camera.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "play.rectangle.fill"
        case .file:
            return "doc.fill"
        case .website:
            return "link"
        case .reflection:
            return "bubble.left.and.text.bubble.right.fill"
        case .event:
            return "calendar"
        case .unknown:
            return "sparkle"
        }
    }
}

enum PortfolioEntryMedia: Equatable, Sendable {
    case photo(url: URL, altText: String?)
    case video(thumbnailURL: URL?, duration: String?)
    case file(title: String, subtitle: String?, thumbnailURL: URL?)
    case website(url: URL, title: String?, faviconURL: URL?)
}

struct PortfolioStudent: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarURL: URL?

    var initials: String {
        let parts = displayName
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()

        if parts.isEmpty {
            return "?"
        }

        return String(parts.prefix(2))
    }
}

struct PortfolioEntry: Identifiable, Equatable, Sendable {
    let id: String
    let kind: PortfolioEntryKind
    let title: String?
    let bodyText: String?
    let createdAt: Date?
    let media: PortfolioEntryMedia?
    let tags: [String]
    let attributedStudents: [PortfolioStudent]
    let isAssignedToAllStudents: Bool
    let sourceStatus: String?

    func isAttributed(to studentID: PortfolioStudent.ID) -> Bool {
        if isAssignedToAllStudents {
            return true
        }

        return attributedStudents.contains { $0.id == studentID }
    }
}
