import Foundation
import Testing
@testable import TinySteps

@MainActor
struct PortfolioPublishPayloadTests {
    @Test("Note payload encodes audio_description_id when provided")
    func notePayloadEncodesAudioDescriptionID() throws {
        let payload = PortfolioNoteCreatePayload(
            title: "Observation",
            body: "Amara voice",
            startDate: "2026-04-23",
            presetID: "preset-1",
            audioDescriptionID: "audio-1",
            allowedUserRoles: ["teacher", "student", "parent"],
            notifyViaEmail: false,
            assignedUserIDs: [101],
            shareToStudentPortfolios: false,
            outcome: .empty(isPYP: false)
        )

        let dict = try Self.encodedDict(payload)

        #expect(dict["audio_description_id"] as? String == "audio-1")
        #expect(dict["title"] as? String == "Observation")
    }

    @Test("Note payload omits audio_description_id when missing")
    func notePayloadOmitsAudioDescriptionIDWhenMissing() throws {
        let payload = PortfolioNoteCreatePayload(
            title: "Observation",
            body: "Amara voice",
            startDate: "2026-04-23",
            presetID: "preset-1",
            audioDescriptionID: nil,
            allowedUserRoles: ["teacher", "student", "parent"],
            notifyViaEmail: false,
            assignedUserIDs: [101],
            shareToStudentPortfolios: false,
            outcome: .empty(isPYP: false)
        )

        let dict = try Self.encodedDict(payload)

        #expect(dict["audio_description_id"] == nil)
        #expect(dict["title"] as? String == "Observation")
    }

    @Test("Photo payload encodes audio_description_id when provided")
    func photoPayloadEncodesAudioDescriptionID() throws {
        let payload = PortfolioPhotoCreatePayload(
            title: "Observation photo",
            description: "Student note",
            startDate: "2026-04-23",
            photoIDs: [12],
            audioDescriptionID: "audio-2",
            allowedUserRoles: ["teacher", "student", "parent"],
            notifyViaEmail: false,
            assignedUserIDs: [11],
            shareToStudentPortfolios: false,
            outcome: .empty(isPYP: false)
        )

        let dict = try Self.encodedDict(payload)

        #expect(dict["audio_description_id"] as? String == "audio-2")
        #expect((dict["photo_ids"] as? [Any])?.count == 1)
    }

    @Test("Photo payload omits audio_description_id when missing")
    func photoPayloadOmitsAudioDescriptionIDWhenMissing() throws {
        let payload = PortfolioPhotoCreatePayload(
            title: "Observation photo",
            description: "Student note",
            startDate: "2026-04-23",
            photoIDs: [12],
            audioDescriptionID: nil,
            allowedUserRoles: ["teacher", "student", "parent"],
            notifyViaEmail: false,
            assignedUserIDs: [11],
            shareToStudentPortfolios: false,
            outcome: .empty(isPYP: false)
        )

        let dict = try Self.encodedDict(payload)

        #expect(dict["audio_description_id"] == nil)
        #expect(dict["photo_ids"] != nil)
    }

    @Test("Child-voice note payload uses child title")
    func notePayloadUsesChildVoiceTitle() throws {
        let draft = ObservationCaptureDraft(
            classID: "class-1",
            className: "Class",
            transcript: "Amara voice",
            matchedChildren: [
                ObservationMatchedChild(
                    studentKey: "amara-id",
                    userID: "12",
                    displayName: "Amara",
                    matchText: "Amara"
                )
            ],
            tags: .empty,
            standardTagSuggestions: [],
            pendingRetag: false,
            childVoice: ChildVoiceDraft(
                localFilename: "child-voice.m4a",
                childStudentKey: "amara-id",
                childUserID: "12",
                childDisplayName: "Amara",
                duration: 8.2
            )
        )

        let payload = try PortfolioPublishPayloadFactory.notePayload(
            for: draft,
            presetID: "preset-child",
            assignedUserIDs: [12],
            outcome: .empty(isPYP: false),
            audioDescriptionID: "audio-4"
        )

        let encoded = try encodedDict(payload)
        #expect(encoded["title"] as? String == "In Amara's words")
        #expect(encoded["body"] as? String == "Amara voice")
    }

    private static func encodedDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw PortfolioPayloadTestError.invalidEncoding
        }
        return dict
    }
}

private enum PortfolioPayloadTestError: Error {
    case invalidEncoding
}
