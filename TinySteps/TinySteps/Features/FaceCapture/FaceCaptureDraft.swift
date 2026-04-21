import Foundation

struct FaceCaptureDraft: Identifiable, Equatable {
    let id: UUID
    let classID: String
    let className: String
    let imageData: Data
    let capturedAt: Date
    let faces: [FaceCaptureDraftFace]

    init(
        id: UUID = UUID(),
        classID: String,
        className: String,
        imageData: Data,
        capturedAt: Date = .now,
        faces: [FaceCaptureDraftFace]
    ) {
        self.id = id
        self.classID = classID
        self.className = className
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.faces = faces
    }
}

struct FaceCaptureDraftFace: Equatable, Sendable {
    let faceID: UUID
    let bounds: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    let studentKey: String?

    static func == (lhs: FaceCaptureDraftFace, rhs: FaceCaptureDraftFace) -> Bool {
        lhs.faceID == rhs.faceID &&
        lhs.bounds.x == rhs.bounds.x &&
        lhs.bounds.y == rhs.bounds.y &&
        lhs.bounds.width == rhs.bounds.width &&
        lhs.bounds.height == rhs.bounds.height &&
        lhs.studentKey == rhs.studentKey
    }
}
