import Foundation

protocol FaceCaptureDraftStore: Sendable {
    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID
}

actor InMemoryFaceCaptureDraftStore: FaceCaptureDraftStore {
    private var drafts: [FaceCaptureDraft.ID: FaceCaptureDraft] = [:]

    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID {
        drafts[draft.id] = draft
        return draft.id
    }

    func allDraftIDs() -> [FaceCaptureDraft.ID] {
        Array(drafts.keys)
    }
}
