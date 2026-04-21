import Foundation
import ImageIO
import UIKit
import Vision

struct FaceEnrollmentEmbeddingResult {
    let embeddings: Data
    let embeddingCount: Int
    let vectorLength: Int
    let elementType: Int
    let modelIdentifier: String
}

enum FaceEnrollmentEmbeddingExtractorError: LocalizedError {
    case noPhotos
    case cannotOrientImage(index: Int)
    case noFeaturePrintObservation(index: Int)
    case revisionFallbackFailed(index: Int, attempts: [String])
    case unsupportedElementType(rawValue: Int)
    case vectorLengthMismatch(first: Int, next: Int, index: Int)

    var errorDescription: String? {
        switch self {
        case .noPhotos:
            return "No photos available for face enrollment embeddings."
        case .cannotOrientImage(let index):
            return "Could not normalise image \(index + 1)."
        case .noFeaturePrintObservation(let index):
            return "Vision did not return a feature print for image \(index + 1)."
        case .revisionFallbackFailed(let index, let attempts):
            return "Image \(index + 1) feature extraction failed: \(attempts.joined(separator: "; "))."
        case .unsupportedElementType(let rawValue):
            return "Unsupported embedding element type: \(rawValue)."
        case .vectorLengthMismatch(let first, let next, let index):
            return "Inconsistent embeddings at image \(index + 1): got \(next), expected \(first)."
        }
    }
}

// Path A from the FaceTagging experiment: Vision feature-print embeddings.
// We keep this in a separate persistence utility so enrollment can evolve later
// without leaking FaceID data-model concerns into the setup view.
enum FaceEnrollmentEmbeddingExtractor {
    private static let requestRevisions: [Int] = [
        VNGenerateImageFeaturePrintRequestRevision2,
        VNGenerateImageFeaturePrintRequestRevision1
    ]

    static func extractEmbeddings(from photos: [UIImage]) async throws -> FaceEnrollmentEmbeddingResult {
        return try extractEmbeddingsSync(from: photos)
    }

    private static func extractEmbeddingsSync(from photos: [UIImage]) throws -> FaceEnrollmentEmbeddingResult {
        guard photos.isEmpty == false else {
            throw FaceEnrollmentEmbeddingExtractorError.noPhotos
        }

        var merged = Data()
        var expectedVectorLength: Int?
        var elementType: Int?
        var usedRevision: Int?

        for (index, photo) in photos.enumerated() {
            guard let cgImage = FaceCropper.fixedOrientation(photo) else {
                throw FaceEnrollmentEmbeddingExtractorError.cannotOrientImage(index: index)
            }

            let extracted = try featurePrint(
                from: cgImage,
                index: index
            )
            let printVectorLength = extracted.elementCount
            let printElementType = extracted.elementType

            if let expectedVectorLength {
                if printVectorLength != expectedVectorLength {
                    throw FaceEnrollmentEmbeddingExtractorError.vectorLengthMismatch(
                        first: expectedVectorLength,
                        next: printVectorLength,
                        index: index
                    )
                }
            } else {
                expectedVectorLength = printVectorLength
            }

            if let elementType {
                if printElementType != elementType {
                    throw FaceEnrollmentEmbeddingExtractorError.unsupportedElementType(rawValue: printElementType)
                }
            } else {
                elementType = printElementType
            }

            if usedRevision == nil {
                usedRevision = extracted.revision
            }

            merged.append(extracted.data)
        }

        guard let expectedVectorLength else {
            throw FaceEnrollmentEmbeddingExtractorError.noPhotos
        }
        guard let elementType else {
            throw FaceEnrollmentEmbeddingExtractorError.unsupportedElementType(rawValue: -1)
        }

        return FaceEnrollmentEmbeddingResult(
            embeddings: merged,
            embeddingCount: photos.count,
            vectorLength: expectedVectorLength,
            elementType: elementType,
            modelIdentifier: "com.fariasystems.faceid.vnFeaturePrint.revision.\(usedRevision ?? VNGenerateImageFeaturePrintRequestRevision2)"
        )
    }

    private static func featurePrint(
        from cgImage: CGImage,
        index: Int
    ) throws -> (data: Data, elementCount: Int, elementType: Int, revision: Int) {
        var attempts: [String] = []
        for revision in requestRevisions {
            do {
                let request = VNGenerateImageFeaturePrintRequest()
                request.revision = revision

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: CGImagePropertyOrientation.up
                )
                try handler.perform([request])

                guard let observation = request.results?.compactMap({ $0 as? VNFeaturePrintObservation }).first else {
                    throw FaceEnrollmentEmbeddingExtractorError.noFeaturePrintObservation(index: index)
                }

                let elementType = Int(observation.elementType.rawValue)
                guard elementType == Int(VNElementType.float.rawValue) else {
                    throw FaceEnrollmentEmbeddingExtractorError.unsupportedElementType(rawValue: elementType)
                }

                return (observation.data, observation.elementCount, elementType, revision)
            } catch {
                attempts.append("rev=\(revision): \(error.localizedDescription)")
            }
        }

        throw FaceEnrollmentEmbeddingExtractorError.revisionFallbackFailed(
            index: index,
            attempts: attempts
        )
    }
}

private enum FaceCropper {
    // Keep this local util here so this module does not depend on app image
    // helpers outside FaceID persistence.
    static func fixedOrientation(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        return upright.cgImage
    }
}
