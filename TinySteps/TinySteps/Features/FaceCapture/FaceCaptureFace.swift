import Foundation
import CoreGraphics

enum FaceCaptureLabel: Equatable, Sendable {
    case matched(studentKey: String, displayName: String, distanceSquared: Float)
    case unknown(distanceSquared: Float?)
}

struct FaceCaptureFace: Identifiable, Equatable, Sendable {
    let id: UUID
    let bounds: CGRect
    var label: FaceCaptureLabel

    init(id: UUID = UUID(), bounds: CGRect, label: FaceCaptureLabel) {
        self.id = id
        self.bounds = bounds
        self.label = label
    }
}
