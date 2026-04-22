import Foundation
import Observation

enum ObservationReviewFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case note = "Note"
    case photo = "Photo"
    case image = "Image"
    case video = "Video"
    case file = "File"
    case website = "Website"

    var id: String {
        rawValue
    }

    var systemImage: String? {
        switch self {
        case .all:
            return nil
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
        }
    }

    func matches(_ draft: ObservationCaptureDraft) -> Bool {
        switch self {
        case .all, .note:
            return true
        case .photo, .image, .video, .file, .website:
            return false
        }
    }
}

@Observable
@MainActor
final class ObservationReviewQueueModel {
    private(set) var drafts: [ObservationCaptureDraft] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?
    private(set) var seenDraftIDs: Set<ObservationCaptureDraft.ID> = []
    private(set) var actionDraftIDs: Set<ObservationCaptureDraft.ID> = []
    var selectedFilter: ObservationReviewFilter = .all

    let classID: String?
    let className: String

    private let session: AuthSession
    private let draftStore: ObservationCaptureDraftStore
    private let publisher: ObservationDraftPublishing
    private var hasLoaded = false

    init(
        session: AuthSession,
        classID: String?,
        className: String,
        draftStore: ObservationCaptureDraftStore,
        publisher: ObservationDraftPublishing
    ) {
        self.session = session
        self.classID = classID
        self.className = className
        self.draftStore = draftStore
        self.publisher = publisher
    }

    var hasConcreteClass: Bool {
        classID != nil
    }

    var reviewDrafts: [ObservationCaptureDraft] {
        drafts.filter { $0.status == .savedForReview }
    }

    var filteredDrafts: [ObservationCaptureDraft] {
        reviewDrafts.filter { selectedFilter.matches($0) }
    }

    var reviewCount: Int {
        reviewDrafts.count
    }

    var readyCount: Int {
        reviewDrafts.filter(Self.isReadyForPublish).count
    }

    var waitingCount: Int {
        reviewCount - readyCount
    }

    var seenReadyCount: Int {
        reviewDrafts
            .filter(Self.isReadyForPublish)
            .filter { seenDraftIDs.contains($0.id) }
            .count
    }

    var canPublishSeen: Bool {
        seenReadyCount > 0 && actionDraftIDs.isEmpty
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await load()
    }

    func load() async {
        guard let classID else {
            drafts = []
            hasLoaded = true
            errorMessage = nil
            statusMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            drafts = try await draftStore.loadDrafts(forClassID: classID)
            hasLoaded = true
            seenDraftIDs = seenDraftIDs.intersection(Set(drafts.map(\.id)))
        } catch {
            drafts = []
            errorMessage = "Local review drafts are unavailable right now."
        }

        isLoading = false
    }

    func markSeen(_ draftID: ObservationCaptureDraft.ID) {
        seenDraftIDs.insert(draftID)
    }

    func isSeen(_ draftID: ObservationCaptureDraft.ID) -> Bool {
        seenDraftIDs.contains(draftID)
    }

    func isActing(on draftID: ObservationCaptureDraft.ID) -> Bool {
        actionDraftIDs.contains(draftID)
    }

    func saveForLater(_ draftID: ObservationCaptureDraft.ID) async {
        guard var draft = reviewDrafts.first(where: { $0.id == draftID }) else {
            return
        }

        actionDraftIDs.insert(draftID)
        statusMessage = nil
        errorMessage = nil

        draft.updatedAt = Date()

        do {
            _ = try await draftStore.saveDraft(draft)
            replaceDraft(draft)
            statusMessage = "Saved on this device."
        } catch {
            errorMessage = "This draft could not be saved right now."
        }

        actionDraftIDs.remove(draftID)
    }

    func deleteDraft(_ draftID: ObservationCaptureDraft.ID) async {
        guard reviewDrafts.contains(where: { $0.id == draftID }) else {
            return
        }

        actionDraftIDs.insert(draftID)
        statusMessage = nil
        errorMessage = nil

        do {
            try await draftStore.deleteDraft(id: draftID)
            drafts.removeAll { $0.id == draftID }
            seenDraftIDs.remove(draftID)
            statusMessage = "Draft deleted."
        } catch {
            errorMessage = "This draft could not be deleted right now."
        }

        actionDraftIDs.remove(draftID)
    }

    func publish(_ draftID: ObservationCaptureDraft.ID) async {
        guard let draft = reviewDrafts.first(where: { $0.id == draftID }) else {
            return
        }

        statusMessage = nil
        errorMessage = nil

        guard Self.isReadyForPublish(draft) else {
            statusMessage = "Tags are still catching up."
            return
        }

        actionDraftIDs.insert(draftID)

        do {
            try await publisher.publish(draft, session: session)
            try await draftStore.deleteDraft(id: draftID)
            drafts.removeAll { $0.id == draftID }
            seenDraftIDs.remove(draftID)
            statusMessage = "Published 1 moment."
        } catch {
            errorMessage = error.localizedDescription
        }

        actionDraftIDs.remove(draftID)
    }

    func publishSeen() async {
        statusMessage = nil
        errorMessage = nil

        let publishableIDs = reviewDrafts
            .filter(Self.isReadyForPublish)
            .filter { seenDraftIDs.contains($0.id) }
            .map(\.id)

        guard publishableIDs.isEmpty == false else {
            statusMessage = "Scroll through to confirm moments first."
            return
        }

        var publishedCount = 0
        for draftID in publishableIDs {
            guard let draft = reviewDrafts.first(where: { $0.id == draftID }) else {
                continue
            }

            actionDraftIDs.insert(draftID)
            do {
                try await publisher.publish(draft, session: session)
                try await draftStore.deleteDraft(id: draftID)
                drafts.removeAll { $0.id == draftID }
                seenDraftIDs.remove(draftID)
                publishedCount += 1
            } catch {
                errorMessage = error.localizedDescription
                actionDraftIDs.remove(draftID)
                break
            }
            actionDraftIDs.remove(draftID)
        }

        if publishedCount > 0 {
            statusMessage = "Published \(publishedCount) \(publishedCount == 1 ? "moment" : "moments")."
        }
    }

    static func isReadyForPublish(_ draft: ObservationCaptureDraft) -> Bool {
        draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        draft.pendingRetag == false
    }

    private func replaceDraft(_ draft: ObservationCaptureDraft) {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }

        drafts.sort { $0.updatedAt < $1.updatedAt }
    }
}
