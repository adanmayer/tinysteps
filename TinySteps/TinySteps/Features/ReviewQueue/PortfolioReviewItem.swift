import Foundation

enum PortfolioReviewItemKind: String, Codable, Sendable {
    case note
    case photo
}

struct PortfolioReviewItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let classID: String
    let className: String
    let kind: PortfolioReviewItemKind
    let noteDraft: ObservationCaptureDraft?
    let photoDraft: FaceCaptureDraft?
    let createdAt: Date
    let updatedAt: Date

    init(noteDraft: ObservationCaptureDraft) {
        self.id = noteDraft.id
        self.classID = noteDraft.classID
        self.className = noteDraft.className
        self.kind = .note
        self.noteDraft = noteDraft
        self.photoDraft = nil
        self.createdAt = noteDraft.createdAt
        self.updatedAt = noteDraft.updatedAt
    }

    init(photoDraft: FaceCaptureDraft) {
        self.id = photoDraft.id
        self.classID = photoDraft.classID
        self.className = photoDraft.className
        self.kind = .photo
        self.noteDraft = nil
        self.photoDraft = photoDraft
        self.createdAt = photoDraft.capturedAt
        self.updatedAt = photoDraft.capturedAt
    }
}
