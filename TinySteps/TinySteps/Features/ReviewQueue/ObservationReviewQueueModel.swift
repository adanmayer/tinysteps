import Foundation
import MBAPI
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

    func matches(_ item: PortfolioReviewItem) -> Bool {
        switch self {
        case .all:
            return true
        case .note:
            return item.kind == .note
        case .photo, .image:
            return item.kind == .photo
        case .video, .file, .website:
            return false
        }
    }
}

@Observable
@MainActor
final class ObservationReviewQueueModel {
    private(set) var items: [PortfolioReviewItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?
    private(set) var seenItemIDs: Set<PortfolioReviewItem.ID> = []
    private(set) var actionItemIDs: Set<PortfolioReviewItem.ID> = []
    var selectedFilter: ObservationReviewFilter = .all

    let classID: String?
    let className: String

    private let session: AuthSession
    private let selectedClass: MBClass?
    private let draftStore: ObservationCaptureDraftStore
    private let photoDraftStore: FaceCaptureDraftStore
    private let publisher: ObservationDraftPublishing
    private var hasLoaded = false

    init(
        session: AuthSession,
        classID: String?,
        className: String,
        selectedClass: MBClass?,
        draftStore: ObservationCaptureDraftStore,
        photoDraftStore: FaceCaptureDraftStore,
        publisher: ObservationDraftPublishing
    ) {
        self.session = session
        self.classID = classID
        self.className = className
        self.selectedClass = selectedClass
        self.draftStore = draftStore
        self.photoDraftStore = photoDraftStore
        self.publisher = publisher
    }

    var hasConcreteClass: Bool {
        classID != nil
    }

    var reviewItems: [PortfolioReviewItem] {
        items
    }

    var filteredItems: [PortfolioReviewItem] {
        reviewItems.filter { selectedFilter.matches($0) }
    }

    var reviewCount: Int {
        reviewItems.count
    }

    var readyCount: Int {
        reviewItems.filter(Self.isReadyForPublish).count
    }

    var waitingCount: Int {
        reviewCount - readyCount
    }

    var seenReadyCount: Int {
        reviewItems
            .filter(Self.isReadyForPublish)
            .filter { seenItemIDs.contains($0.id) }
            .count
    }

    var canPublishSeen: Bool {
        seenReadyCount > 0 && actionItemIDs.isEmpty
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await load()
    }

    func load() async {
        guard let classID else {
            items = []
            hasLoaded = true
            errorMessage = nil
            statusMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let noteItems = try await draftStore.loadDrafts(forClassID: classID)
                .filter { $0.status == .savedForReview }
                .map(PortfolioReviewItem.init(noteDraft:))
            let photoItems = try await photoDraftStore.loadDrafts(forClassID: classID)
                .map(PortfolioReviewItem.init(photoDraft:))
            items = (noteItems + photoItems).sorted { $0.updatedAt < $1.updatedAt }
            hasLoaded = true
            seenItemIDs = seenItemIDs.intersection(Set(items.map(\.id)))
        } catch {
            items = []
            errorMessage = "Local review drafts are unavailable right now."
        }

        isLoading = false
    }

    func markSeen(_ itemID: PortfolioReviewItem.ID) {
        seenItemIDs.insert(itemID)
    }

    func isSeen(_ itemID: PortfolioReviewItem.ID) -> Bool {
        seenItemIDs.contains(itemID)
    }

    func isActing(on itemID: PortfolioReviewItem.ID) -> Bool {
        actionItemIDs.contains(itemID)
    }

    func saveForLater(_ draftID: ObservationCaptureDraft.ID) async {
        guard var draft = reviewItems.first(where: { $0.id == draftID })?.noteDraft else {
            return
        }

        actionItemIDs.insert(draftID)
        statusMessage = nil
        errorMessage = nil

        draft.updatedAt = Date()

        do {
            _ = try await draftStore.saveDraft(draft)
            replaceItem(PortfolioReviewItem(noteDraft: draft))
            statusMessage = "Saved on this device."
        } catch {
            errorMessage = "This draft could not be saved right now."
        }

        actionItemIDs.remove(draftID)
    }

    func deleteItem(_ itemID: PortfolioReviewItem.ID) async {
        guard let item = reviewItems.first(where: { $0.id == itemID }) else {
            return
        }

        actionItemIDs.insert(itemID)
        statusMessage = nil
        errorMessage = nil

        do {
            switch item.kind {
            case .note:
                try await draftStore.deleteDraft(id: itemID)
            case .photo:
                try await photoDraftStore.deleteDraft(id: itemID)
            }
            items.removeAll { $0.id == itemID }
            seenItemIDs.remove(itemID)
            statusMessage = "Draft deleted."
        } catch {
            errorMessage = "This draft could not be deleted right now."
        }

        actionItemIDs.remove(itemID)
    }

    func publish(_ itemID: PortfolioReviewItem.ID) async {
        guard let item = reviewItems.first(where: { $0.id == itemID }) else {
            return
        }

        statusMessage = nil
        errorMessage = nil

        guard Self.isReadyForPublish(item) else {
            statusMessage = "Tags are still catching up."
            return
        }

        actionItemIDs.insert(itemID)

        do {
            try await publish(item)
            try await deletePublishedItem(item)
            items.removeAll { $0.id == itemID }
            seenItemIDs.remove(itemID)
            statusMessage = "Published 1 moment."
        } catch {
            errorMessage = error.localizedDescription
        }

        actionItemIDs.remove(itemID)
    }

    func publishSeen() async {
        statusMessage = nil
        errorMessage = nil

        let publishableIDs = reviewItems
            .filter(Self.isReadyForPublish)
            .filter { seenItemIDs.contains($0.id) }
            .map(\.id)

        guard publishableIDs.isEmpty == false else {
            statusMessage = "Scroll through to confirm moments first."
            return
        }

        var publishedCount = 0
        for itemID in publishableIDs {
            guard let item = reviewItems.first(where: { $0.id == itemID }) else {
                continue
            }

            actionItemIDs.insert(itemID)
            do {
                try await publish(item)
                try await deletePublishedItem(item)
                items.removeAll { $0.id == itemID }
                seenItemIDs.remove(itemID)
                publishedCount += 1
            } catch {
                errorMessage = error.localizedDescription
                actionItemIDs.remove(itemID)
                break
            }
            actionItemIDs.remove(itemID)
        }

        if publishedCount > 0 {
            statusMessage = "Published \(publishedCount) \(publishedCount == 1 ? "moment" : "moments")."
        }
    }

    static func isReadyForPublish(_ item: PortfolioReviewItem) -> Bool {
        switch item.kind {
        case .note:
            guard let draft = item.noteDraft else {
                return false
            }
            return draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            draft.pendingRetag == false
        case .photo:
            return item.photoDraft?.imageData.isEmpty == false
        }
    }

    private func publish(_ item: PortfolioReviewItem) async throws {
        switch item.kind {
        case .note:
            guard let draft = item.noteDraft else {
                throw ObservationDraftPublishError.validation("This observation draft is incomplete. It stays on this device.")
            }
            try await publisher.publish(draft, session: session, selectedClass: selectedClass)
        case .photo:
            guard let draft = item.photoDraft else {
                throw ObservationDraftPublishError.validation("This photo draft is incomplete. It stays on this device.")
            }
            try await publisher.publish(draft, session: session, selectedClass: selectedClass)
        }
    }

    private func deletePublishedItem(_ item: PortfolioReviewItem) async throws {
        switch item.kind {
        case .note:
            try await draftStore.deleteDraft(id: item.id)
        case .photo:
            try await photoDraftStore.deleteDraft(id: item.id)
        }
    }

    private func replaceItem(_ item: PortfolioReviewItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }

        items.sort { $0.updatedAt < $1.updatedAt }
    }
}
