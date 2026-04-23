import Foundation
import MBAPI

struct MBPortfolioReviewItemPublisher: ObservationDraftPublishing {
    let portfolioService: PortfolioService
    let classesService: ClassesService

    var isAvailable: Bool {
        true
    }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
        guard draft.classID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw ObservationDraftPublishError.validation("This draft has no class id. It stays on this device.")
        }

        guard draft.pendingRetag == false else {
            throw ObservationDraftPublishError.validation("Tags are still catching up. Try again in a moment.")
        }

        let assignedUserIDs = try PortfolioStudentAssignmentResolver()
            .assignedUserIDs(
                for: draft.matchedChildren.map {
                    PortfolioStudentAssignmentReference(
                        studentKey: $0.studentKey,
                        userID: $0.userID
                    )
                }
            )
        let isPYP = hasPYPObservationTags(draft.tags) || draft.standardTagSuggestions.contains { suggestion in
            suggestion.kind == .pypTheme || isPYPProgramCode(suggestion.programCode)
        }
        let outcome = try PortfolioOutcomePayloadBuilder().build(
            from: draft.standardTagSuggestions,
            isPYP: isPYP
        )
        let presetID = try await resolveNotePresetID(
            session: session,
            selectedClass: selectedClass
        )
        let payload = try PortfolioPublishPayloadFactory.notePayload(
            for: draft,
            presetID: presetID,
            assignedUserIDs: assignedUserIDs,
            outcome: outcome
        )

        _ = try await portfolioService.createClassNote(
            for: session,
            classID: draft.classID,
            payload: payload
        )
    }

    func publish(
        _ draft: FaceCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
        _ = selectedClass
        guard draft.classID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw ObservationDraftPublishError.validation("This photo has no class id. It stays on this device.")
        }

        guard draft.imageData.isEmpty == false else {
            throw ObservationDraftPublishError.validation("This photo data is missing. It stays on this device.")
        }

        let assignedUserIDs = try PortfolioStudentAssignmentResolver()
            .assignedUserIDs(
                for: draft.faces.compactMap { face in
                    guard let studentKey = face.studentKey else {
                        return nil
                    }

                    return PortfolioStudentAssignmentReference(
                        studentKey: studentKey,
                        userID: face.userID
                    )
                }
            )
        let uploadedPhoto = try await portfolioService.uploadPhoto(
            for: session,
            imageData: draft.imageData,
            filename: "\(draft.id.uuidString).jpg",
            mimeType: "image/jpeg"
        )

        guard let photoID = Int(uploadedPhoto.id.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ObservationDraftPublishError.validation("The server did not return a publishable photo id. This photo stays on this device.")
        }

        let audioDescriptionID = try await resolveAudioDescriptionID(
            for: draft,
            session: session
        )
        let payload = PortfolioPublishPayloadFactory.photoPayload(
            for: draft,
            photoID: photoID,
            assignedUserIDs: assignedUserIDs,
            audioDescriptionID: audioDescriptionID
        )

        _ = try await portfolioService.createClassPhoto(
            for: session,
            classID: draft.classID,
            payload: payload
        )

        if let childVoice = draft.childVoice {
            let recorder = ChildVoiceAudioRecorder()
            try? recorder.deleteRecording(filename: childVoice.localFilename)
        }
    }

    private func resolveAudioDescriptionID(
        for draft: FaceCaptureDraft,
        session: AuthSession
    ) async throws -> String? {
        guard let childVoice = draft.childVoice else {
            return nil
        }

        if let uploadedID = childVoice.uploadedAudioDescriptionID {
            return uploadedID
        }

        let recorder = ChildVoiceAudioRecorder()
        let audioData = try recorder.recordingData(for: childVoice.localFilename)
        return try await portfolioService.uploadAudioDescription(
            for: session,
            audioData: audioData,
            filename: childVoice.localFilename,
            mimeType: "audio/mp4"
        )
    }

    private func isPYPProgramCode(_ code: String?) -> Bool {
        guard let code else {
            return false
        }

        let normalized = MBStandardsProgramDetector.normalizedValue(code)
        return normalized == "pyp" ||
        normalized == "ibpyp" ||
        normalized == "primaryyearsprogramme" ||
        normalized == "primaryyearsprogram" ||
        MBStandardsProgramDetector.pypAliases.contains(normalized)
    }

    private func hasPYPObservationTags(_ tags: ObservationPYPTagBundle) -> Bool {
        tags.transdisciplinaryTheme != nil ||
        tags.keyConcepts.isEmpty == false ||
        tags.atlSkills.isEmpty == false ||
        tags.learnerProfile.isEmpty == false
    }

    private func resolveNotePresetID(
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws -> String {
        guard let programID = selectedClass?.program?.uid?.trimmingCharacters(in: .whitespacesAndNewlines),
              programID.isEmpty == false else {
            throw ObservationDraftPublishError.validation("This class has no portfolio settings program id. The draft stays on this device.")
        }

        let settings = try await portfolioService.loadClassPortfolioSettings(
            for: session,
            programID: programID
        )

        guard let presetID = settings.noteStylePresets
            .map(\.id)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.isEmpty == false })
        else {
            throw ObservationDraftPublishError.validation("This class has no available note style preset. The draft stays on this device.")
        }

        return presetID
    }
}
