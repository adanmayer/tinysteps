import Foundation
import CoreGraphics

struct FaceCaptureDraft: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let classID: String
    let className: String
    let imageData: Data
    let capturedAt: Date
    let faces: [FaceCaptureDraftFace]
    let childVoice: ChildVoiceDraft?

    init(
        id: UUID = UUID(),
        classID: String,
        className: String,
        imageData: Data,
        capturedAt: Date = .now,
        faces: [FaceCaptureDraftFace],
        childVoice: ChildVoiceDraft? = nil
    ) {
        self.id = id
        self.classID = classID
        self.className = className
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.faces = faces
        self.childVoice = childVoice
    }
}

struct FaceCaptureDraftFaceBounds: Codable, Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

struct FaceCaptureDraftFace: Codable, Equatable, Sendable {
    let faceID: UUID
    let bounds: FaceCaptureDraftFaceBounds
    let studentKey: String?
    let userID: String?

    init(
        faceID: UUID,
        bounds: FaceCaptureDraftFaceBounds,
        studentKey: String?,
        userID: String? = nil
    ) {
        self.faceID = faceID
        self.bounds = bounds
        self.studentKey = studentKey
        self.userID = userID
    }
}
