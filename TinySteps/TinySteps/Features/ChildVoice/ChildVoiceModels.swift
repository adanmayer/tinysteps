import Foundation

struct ChildVoiceChild: Codable, Equatable, Identifiable, Sendable {
    let studentKey: String
    let userID: String
    let displayName: String
    let avatarURL: URL?

    init(
        studentKey: String,
        userID: String,
        displayName: String,
        avatarURL: URL? = nil
    ) {
        self.studentKey = studentKey
        self.userID = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    var id: String {
        studentKey
    }
}

struct ChildVoiceDraft: Codable, Equatable, Sendable {
    let localFilename: String
    let childStudentKey: String
    let childUserID: String
    let childDisplayName: String
    let duration: TimeInterval
    let createdAt: Date
    var uploadedAudioDescriptionID: String?

    init(
        localFilename: String,
        childStudentKey: String,
        childUserID: String,
        childDisplayName: String,
        duration: TimeInterval,
        createdAt: Date = .now,
        uploadedAudioDescriptionID: String? = nil
    ) {
        self.localFilename = localFilename
        self.childStudentKey = childStudentKey
        self.childUserID = childUserID
        self.childDisplayName = childDisplayName
        self.duration = duration
        self.createdAt = createdAt
        self.uploadedAudioDescriptionID = uploadedAudioDescriptionID
    }
}

enum ChildVoiceCaptureMode: Equatable, Sendable {
    case photoAttachment(classID: String, className: String, child: ChildVoiceChild)
    case standaloneNote(classID: String, className: String, child: ChildVoiceChild)
}
