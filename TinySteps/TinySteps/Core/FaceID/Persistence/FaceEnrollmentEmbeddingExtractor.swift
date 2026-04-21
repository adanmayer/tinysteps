import Foundation
import Vision
import CoreML

struct FaceEnrollmentEmbeddingResult {
    let embeddings: Data
    let embeddingCount: Int
    let vectorLength: Int
    let elementType: Int
    let modelIdentifier: String
}

enum FaceEnrollmentEmbeddingExtractorError: LocalizedError {
    case noPhotos
    case missingPhotoOrientData(index: Int)
    case noFaces(index: Int)
    case invalidAlignment(index: Int)
    case embeddingGenerationFailed(index: Int, reason: String)
    case mismatchedVectorLength(expected: Int, actual: Int, index: Int)
    case unsupportedElementType(rawValue: Int)
    case vectorDataSizeMismatch(expectedBytes: Int, actualBytes: Int)

    var errorDescription: String? {
        switch self {
        case .noPhotos:
            return "No photos available for face enrollment embeddings."
        case .missingPhotoOrientData(let index):
            return "Could not normalise image \(index + 1)."
        case .noFaces(let index):
            return "No face detected in image \(index + 1)."
        case .invalidAlignment(let index):
            return "Could not align the face in image \(index + 1)."
        case .embeddingGenerationFailed(let index, let reason):
            return "Failed to generate embedding for image \(index + 1): \(reason)."
        case .mismatchedVectorLength(let expected, let actual, let index):
            return "Face embedding \(index + 1) has unexpected length \(actual) (expected \(expected))."
        case .unsupportedElementType(let rawValue):
            return "Unsupported embedding element type: \(rawValue)."
        case .vectorDataSizeMismatch(let expectedBytes, let actualBytes):
            return "Embedding byte count is invalid (\(actualBytes) bytes, expected \(expectedBytes) bytes)."
        }
    }
}

enum FaceEnrollmentEmbeddingExtractor {
    static func extractEmbeddings(from photos: [UIImage]) async throws -> FaceEnrollmentEmbeddingResult {
        let normalizedPhotos = photos
            .compactMap { photo in FaceCropper.fixedOrientation(photo) }

        guard normalizedPhotos.isEmpty == false else {
            throw FaceEnrollmentEmbeddingExtractorError.noPhotos
        }

        guard normalizedPhotos.count == photos.count else {
            throw FaceEnrollmentEmbeddingExtractorError.missingPhotoOrientData(index: 0)
        }

        let aligner = FaceAligner()
        let embedder = try MLFaceEmbedder()

        var allEmbeddings = Data()
        var vectorLength: Int?
        var vectorBytes: Int?

        for (index, cgImage) in normalizedPhotos.enumerated() {
            let observations = try await FaceDetector.detectFaces(in: cgImage)
            guard let observation = observations.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
                throw FaceEnrollmentEmbeddingExtractorError.noFaces(index: index)
            }

            let alignedFaces = try aligner.alignAll(in: cgImage, observations: [observation])
            guard let aligned = alignedFaces.first else {
                throw FaceEnrollmentEmbeddingExtractorError.invalidAlignment(index: index)
            }

            let embedding = try await embedder.embed(aligned)
            guard embedding.elementType == FaceIDModelContainer.requiredElementType else {
                throw FaceEnrollmentEmbeddingExtractorError.unsupportedElementType(rawValue: embedding.elementType)
            }

            if let expectedLength = vectorLength {
                if embedding.vectorLength != expectedLength {
                    throw FaceEnrollmentEmbeddingExtractorError.mismatchedVectorLength(
                        expected: expectedLength,
                        actual: embedding.vectorLength,
                        index: index
                    )
                }
            } else {
                vectorLength = embedding.vectorLength
                vectorBytes = embedding.vectorLength * MemoryLayout<Float32>.size
            }

            allEmbeddings.append(embedding.data)
        }

        guard let expectedBytes = vectorBytes, let expectedLength = vectorLength else {
            throw FaceEnrollmentEmbeddingExtractorError.noPhotos
        }
        let expectedByteCount = normalizedPhotos.count * expectedBytes
        guard allEmbeddings.count == expectedByteCount else {
            throw FaceEnrollmentEmbeddingExtractorError.vectorDataSizeMismatch(
                expectedBytes: expectedByteCount,
                actualBytes: allEmbeddings.count
            )
        }

        return FaceEnrollmentEmbeddingResult(
            embeddings: allEmbeddings,
            embeddingCount: photos.count,
            vectorLength: expectedLength,
            elementType: FaceIDModelContainer.requiredElementType,
            modelIdentifier: FaceIDModelContainer.requiredModelIdentifier
        )
    }
}
