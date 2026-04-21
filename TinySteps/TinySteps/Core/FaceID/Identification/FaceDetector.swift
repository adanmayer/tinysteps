import Vision
import CoreGraphics

enum FaceDetector {
    enum Error: LocalizedError {
        case requestFailed(String)
        case unsupported

        var errorDescription: String? {
            switch self {
            case .requestFailed(let reason):
                return "Face detection failed: \(reason)"
            case .unsupported:
                return "Face detection is unavailable on this device."
            }
        }
    }

    static func detectFaces(in cgImage: CGImage) async throws -> [VNFaceObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: Error.requestFailed(error.localizedDescription))
                    return
                }

                let faces = request.results as? [VNFaceObservation] ?? []
                continuation.resume(returning: faces)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: Error.requestFailed(error.localizedDescription))
            }
        }
    }
}
