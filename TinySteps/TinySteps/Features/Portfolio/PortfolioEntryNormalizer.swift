import Foundation
import MBAPI

enum PortfolioEntryNormalizer {
    nonisolated static func normalize(_ items: [MBAPI.Portfolio.TimelineItem]) -> [PortfolioEntry] {
        items
            .map(normalize(_:))
            .sorted { lhs, rhs in
                switch (lhs.createdAt, rhs.createdAt) {
                case (.some(let lhsDate), .some(let rhsDate)):
                    return lhsDate > rhsDate
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.id < rhs.id
                }
            }
    }

    nonisolated static func normalize(_ item: MBAPI.Portfolio.TimelineItem) -> PortfolioEntry {
        let kind = normalizedKind(for: item)
        let title = normalizedTitle(for: item, kind: kind)

        return PortfolioEntry(
            id: item.id,
            kind: kind,
            title: title,
            bodyText: normalizedBodyText(for: item, kind: kind),
            createdAt: item.createdDate,
            media: normalizedMedia(for: item, kind: kind, title: title),
            tags: normalizedTags(for: item),
            attributedStudents: normalizedStudents(for: item),
            isAssignedToAllStudents: item.isAssignedToAllStudents,
            sourceStatus: item.status
        )
    }

    nonisolated private static func normalizedKind(for item: MBAPI.Portfolio.TimelineItem) -> PortfolioEntryKind {
        let rawKind = [
            item.logable.kind,
            item.logableType
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if rawKind.contains("note") {
            return .note
        }
        if rawKind.contains("photo") {
            return .photo
        }
        if rawKind.contains("image") {
            return .image
        }
        if rawKind.contains("video") {
            return .video
        }
        if rawKind.contains("file") || rawKind.contains("asset") {
            return .file
        }
        if rawKind.contains("website") || rawKind.contains("url") || rawKind.contains("link") {
            return .website
        }
        if rawKind.contains("reflection") {
            return .reflection
        }
        if rawKind.contains("event") {
            return .event
        }

        if item.logable.photos.isEmpty == false {
            return .photo
        }
        if item.logable.assets.isEmpty == false {
            return .file
        }
        if item.logable.urls.isEmpty == false {
            return .website
        }

        return .unknown
    }

    nonisolated private static func normalizedTitle(
        for item: MBAPI.Portfolio.TimelineItem,
        kind: PortfolioEntryKind
    ) -> String? {
        let title = item.logable.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let title, title.isEmpty == false, title != "Portfolio item" {
            return title
        }

        return kind.rawValue
    }

    nonisolated private static func normalizedBodyText(
        for item: MBAPI.Portfolio.TimelineItem,
        kind: PortfolioEntryKind
    ) -> String? {
        let text: String?
        switch kind {
        case .note:
            text = item.logable.body ?? item.logable.description
        case .photo, .image, .video, .file, .website, .reflection, .event, .unknown:
            text = item.logable.description ?? item.logable.body
        }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == true ? nil : trimmed
    }

    nonisolated private static func normalizedMedia(
        for item: MBAPI.Portfolio.TimelineItem,
        kind: PortfolioEntryKind,
        title: String?
    ) -> PortfolioEntryMedia? {
        switch kind {
        case .photo, .image:
            guard let photo = item.logable.photos.first,
                  let url = preferredPhotoURL(photo) else {
                return nil
            }

            return .photo(url: url, altText: title ?? photo.filename)
        case .video:
            return .video(thumbnailURL: nil, duration: nil)
        case .file:
            guard let asset = item.logable.assets.first else {
                return nil
            }

            return .file(
                title: asset.filename,
                subtitle: asset.info.isEmpty ? asset.filetype : asset.info,
                thumbnailURL: nil
            )
        case .website:
            guard
                let rawURL = item.logable.urls.first,
                let url = URL(string: rawURL)
            else {
                return nil
            }

            return .website(url: url, title: title, faviconURL: nil)
        case .note, .reflection, .event, .unknown:
            return nil
        }
    }

    nonisolated private static func preferredPhotoURL(_ photo: MBAPI.Portfolio.Photo) -> URL? {
        let candidates: [String?] = [
            photo.versions?.thumb,
            photo.versions?.square,
            photo.url,
            photo.versions?.tiny
        ]

        return candidates
            .compactMap { value -> URL? in
                guard let value else {
                    return nil
                }
                return URL(string: value)
            }
            .first
    }

    nonisolated private static func normalizedTags(for item: MBAPI.Portfolio.TimelineItem) -> [String] {
        var seen = Set<String>()
        return (item.labels + item.logable.labels)
            .compactMap { tag -> String? in
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else {
                    return nil
                }

                let key = trimmed.lowercased()
                guard seen.insert(key).inserted else {
                    return nil
                }

                return trimmed
            }
    }

    nonisolated private static func normalizedStudents(for item: MBAPI.Portfolio.TimelineItem) -> [PortfolioStudent] {
        item.explicitAttributedStudents.map { student in
            PortfolioStudent(
                id: student.id,
                displayName: student.displayName.isEmpty ? "Child" : student.displayName,
                avatarURL: student.avatarURL
            )
        }
    }
}
