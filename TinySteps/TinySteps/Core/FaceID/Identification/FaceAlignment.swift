import Vision
import CoreGraphics

struct FaceAlignment {
    let eyeDistance: CGFloat?
    let leftEye: CGPoint?
    let rightEye: CGPoint?
    let noseTip: CGPoint?

    init(landmarks: VNFaceLandmarks2D?, imageHeight: CGFloat) {
        let normalized = landmarks.map { landmarks in
            Self.normalizedPoints(from: landmarks)
        }

        leftEye = normalized?.leftEye
        rightEye = normalized?.rightEye
        noseTip = normalized?.nose
        if let leftEye, let rightEye {
            eyeDistance = abs(leftEye.x - rightEye.x)
        } else {
            eyeDistance = nil
        }
    }

    private static func normalizedPoints(from landmarks: VNFaceLandmarks2D) -> (
        leftEye: CGPoint?,
        rightEye: CGPoint?,
        nose: CGPoint?
    ) {
        let leftPoints = landmarks.leftEye?.normalizedPoints ?? []
        let rightPoints = landmarks.rightEye?.normalizedPoints ?? []
        let nosePoints = landmarks.nose?.normalizedPoints ?? []

        func centroid(_ points: [CGPoint]) -> CGPoint? {
            guard points.isEmpty == false else {
                return nil
            }
            let x = points.reduce(0, { $0 + $1.x }) / CGFloat(points.count)
            let y = points.reduce(0, { $0 + $1.y }) / CGFloat(points.count)
            return CGPoint(x: x, y: y)
        }

        return (
            centroid(leftPoints),
            centroid(rightPoints),
            centroid(nosePoints)
        )
    }
}
