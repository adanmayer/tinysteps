import Foundation
import UIKit

struct FaceIdentificationService {
    enum Error: LocalizedError {
        case noImageData
        case noEmbeddings

        var errorDescription: String? {
            switch self {
            case .noImageData:
                return "Could not process the photo."
            case .noEmbeddings:
                return "Could not generate face embeddings."
            }
        }
    }

    private let aligner = FaceAligner()
    private let matcher = IdentityMatcher()
    private let embedder: MLFaceEmbedder

    init() throws {
        embedder = try MLFaceEmbedder()
    }

    func identifyFaces(
        in photo: UIImage,
        using snapshots: [FaceEnrollmentSnapshot],
        threshold: Float = FaceIdentificationThreshold.current()
    ) async throws -> [FaceCaptureFace] {
        guard let cgImage = FaceCropper.fixedOrientation(photo) else {
            throw Error.noImageData
        }

        let observations = try await FaceDetector.detectFaces(in: cgImage)
        guard observations.isEmpty == false else {
            return []
        }

        let alignedFaces = try aligner.alignAll(in: cgImage, observations: observations)
        if alignedFaces.isEmpty {
            return []
        }

        var identified: [FaceCaptureFace] = []
        for alignedFace in alignedFaces {
            let embedding = try await embedder.embed(alignedFace)
            let match = matcher.bestMatch(
                for: embedding,
                in: snapshots,
                threshold: threshold
            )

            let label: FaceCaptureLabel
            switch match {
            case .matched(let studentKey, let displayName, let distanceSquared):
                label = .matched(
                    studentKey: studentKey,
                    displayName: displayName,
                    distanceSquared: distanceSquared
                )
            case .unknown(let distanceSquared):
                label = .unknown(distanceSquared: distanceSquared)
            }

            identified.append(
                FaceCaptureFace(
                    bounds: alignedFace.bounds,
                    label: label
                )
            )
        }

        return identified
    }
}
