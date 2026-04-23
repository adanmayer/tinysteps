import Foundation
import MBAPI

struct FaceCaptureSession: Identifiable {
    let id: UUID
    let classID: String
    let className: String
    let rosterSnapshot: [FaceCaptureStudentSnapshot]
    let initialDraft: FaceCaptureDraft?
    let createdAt: Date

    init(
        classID: String,
        className: String,
        rosterSnapshot: [FaceCaptureStudentSnapshot],
        initialDraft: FaceCaptureDraft? = nil,
        createdAt: Date = .now
    ) {
        self.id = initialDraft?.id ?? UUID()
        self.classID = classID
        self.className = className
        self.rosterSnapshot = rosterSnapshot
        self.initialDraft = initialDraft
        self.createdAt = createdAt
    }
}

struct FaceCaptureStudentSnapshot: Identifiable, Sendable {
    let id: String
    let studentKey: String
    let userID: String?
    let displayName: String
    let avatarURL: URL?

    init(
        studentKey: String,
        userID: String?,
        displayName: String,
        avatarURL: URL? = nil
    ) {
        self.id = studentKey
        self.studentKey = studentKey
        self.userID = userID
        self.avatarURL = avatarURL
        let displayName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName.isEmpty ? "Child" : displayName
    }

    init(from student: ClassRosterStudent) {
        self.id = student.studentKey
        self.studentKey = student.studentKey
        self.userID = student.userID
        self.avatarURL = student.avatarURL
        let displayName = student.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName.isEmpty ? "Child" : displayName
    }
}
