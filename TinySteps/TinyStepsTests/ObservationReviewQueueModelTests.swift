import Foundation
import MBAPI
import Testing
@testable import TinySteps

@MainActor
struct ObservationReviewQueueModelTests {
    @Test("Review queue loads saved drafts and derives ready counts")
    func loadsSavedDraftsAndReadyCounts() async throws {
        let store = InMemoryObservationCaptureDraftStore()
        let readyDraft = ObservationCaptureDraft.reviewTestDraft(
            pendingRetag: false,
            status: .savedForReview
        )
        let waitingDraft = ObservationCaptureDraft.reviewTestDraft(
            transcript: "Noor noticed the clouds.",
            pendingRetag: true,
            status: .savedForReview
        )
        let recoverableDraft = ObservationCaptureDraft.reviewTestDraft(
            transcript: "Still being edited.",
            pendingRetag: false,
            status: .localDraft
        )

        _ = try await store.saveDraft(readyDraft)
        _ = try await store.saveDraft(waitingDraft)
        _ = try await store.saveDraft(recoverableDraft)

        let model = ObservationReviewQueueModel(
            session: .previewTeacher,
            classID: "blue-room",
            className: "Blue Room",
            selectedClass: nil,
            draftStore: store,
            photoDraftStore: InMemoryFaceCaptureDraftStore(),
            publisher: SucceedingObservationDraftPublisher()
        )

        await model.load()

        #expect(model.reviewCount == 2)
        #expect(model.readyCount == 1)
        #expect(model.waitingCount == 1)
    }

    @Test("Unavailable publishing keeps the draft local")
    func unavailablePublishingKeepsDraftLocal() async throws {
        let store = InMemoryObservationCaptureDraftStore()
        let draft = ObservationCaptureDraft.reviewTestDraft(pendingRetag: false)
        _ = try await store.saveDraft(draft)

        let model = ObservationReviewQueueModel(
            session: .previewTeacher,
            classID: "blue-room",
            className: "Blue Room",
            selectedClass: nil,
            draftStore: store,
            photoDraftStore: InMemoryFaceCaptureDraftStore(),
            publisher: UnavailableObservationDraftPublisher()
        )

        await model.load()
        await model.publish(draft.id)

        let storedDrafts = try await store.loadDrafts(forClassID: "blue-room")
        #expect(model.reviewCount == 1)
        #expect(storedDrafts.count == 1)
        #expect(model.errorMessage == ObservationDraftPublishError.unavailable.errorDescription)
    }

    @Test("Successful publishing removes the local draft")
    func successfulPublishingRemovesLocalDraft() async throws {
        let store = InMemoryObservationCaptureDraftStore()
        let draft = ObservationCaptureDraft.reviewTestDraft(pendingRetag: false)
        _ = try await store.saveDraft(draft)

        let model = ObservationReviewQueueModel(
            session: .previewTeacher,
            classID: "blue-room",
            className: "Blue Room",
            selectedClass: nil,
            draftStore: store,
            photoDraftStore: InMemoryFaceCaptureDraftStore(),
            publisher: SucceedingObservationDraftPublisher()
        )

        await model.load()
        await model.publish(draft.id)

        let storedDrafts = try await store.loadDrafts(forClassID: "blue-room")
        #expect(model.reviewCount == 0)
        #expect(storedDrafts.isEmpty)
    }
}

private struct SucceedingObservationDraftPublisher: ObservationDraftPublishing {
    var isAvailable: Bool {
        true
    }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
    }

    func publish(
        _ draft: FaceCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
    }
}

private extension ObservationCaptureDraft {
    static func reviewTestDraft(
        transcript: String = "Amara stacked the red cups and counted them carefully.",
        pendingRetag: Bool,
        status: ObservationDraftStatus = .savedForReview
    ) -> ObservationCaptureDraft {
        ObservationCaptureDraft(
            classID: "blue-room",
            className: "Blue Room",
            transcript: transcript,
            matchedChildren: [
                ObservationMatchedChild(
                    studentKey: "amara",
                    displayName: "Amara",
                    matchText: "Amara"
                )
            ],
            tags: ObservationPYPTagBundle(
                transdisciplinaryTheme: nil,
                keyConcepts: [.connection],
                atlSkills: [.thinking],
                learnerProfile: [.inquirer]
            ),
            confidence: 0.8,
            evidenceSpans: [],
            pendingRetag: pendingRetag,
            status: status,
            createdAt: Date(timeIntervalSince1970: 1_776_800_000),
            updatedAt: Date(timeIntervalSince1970: 1_776_800_000)
        )
    }
}
