import Foundation

struct FaceCaptureAssignment: Identifiable, Equatable, Sendable {
    let id: UUID
    let faceID: UUID
    var studentKey: String?

    init(faceID: UUID, studentKey: String? = nil) {
        self.id = UUID()
        self.faceID = faceID
        self.studentKey = studentKey
    }
}
