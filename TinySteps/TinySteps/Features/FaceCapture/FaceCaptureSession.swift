import Foundation
import MBAPI

struct FaceCaptureSession: Identifiable {
    let id: UUID
    let classID: String
    let className: String
    let rosterSnapshot: [FaceCaptureStudentSnapshot]
    let createdAt: Date

    init(
        classID: String,
        className: String,
        rosterSnapshot: [FaceCaptureStudentSnapshot],
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.classID = classID
        self.className = className
        self.rosterSnapshot = rosterSnapshot
        self.createdAt = createdAt
    }
}

struct FaceCaptureStudentSnapshot: Identifiable, Sendable {
    let id: String
    let studentKey: String
    let userID: String?
    let displayName: String

    init(from student: ClassRosterStudent) {
        self.id = student.studentKey
        self.studentKey = student.studentKey
        self.userID = student.userID
        self.displayName = student.displayName
    }
}
