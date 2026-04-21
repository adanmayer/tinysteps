import UIKit
import Vision
import CoreGraphics

struct FaceAligner {
    enum Error: LocalizedError {
        case noLandmarks
        case noImageData
        case alignmentFailed
        case failedToCrop

        var errorDescription: String? {
            switch self {
            case .noLandmarks:
                return "No face landmarks available for alignment."
            case .noImageData:
                return "Cannot load image content."
            case .alignmentFailed:
                return "Face alignment failed."
            case .failedToCrop:
                return "Could not crop detected face."
            }
        }
    }

    private let canvasSize = CGSize(width: 112, height: 112)
    private let defaultPadding: CGFloat = 0.75

    func alignAll(in cgImage: CGImage, observations: [VNFaceObservation]? = nil) throws -> [AlignedFace] {
        guard cgImage.width > 0, cgImage.height > 0 else {
            throw Error.noImageData
        }

        let sourceObservations = observations?.isEmpty == false
            ? observations!
            : try detectFaceObservations(in: cgImage)

        guard sourceObservations.isEmpty == false else {
            return []
        }

        let landmarkObservations = try landmarkResults(in: cgImage)

        return sourceObservations.compactMap { observation in
            guard let landmarks = matchingLandmarks(for: observation, in: landmarkObservations) else {
                return nil
            }

            let alignment = FaceAlignment(landmarks: landmarks, imageHeight: CGFloat(cgImage.height))
            let bounds = FaceCropper.imageBounds(
                observation.boundingBox,
                for: CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            )
            guard let alignedImage = align(image: cgImage, to: bounds, alignment: alignment) else {
                return nil
            }
            return AlignedFace(bounds: observation.boundingBox, image: alignedImage)
        }
    }

    private func detectFaceObservations(in cgImage: CGImage) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        return request.results as? [VNFaceObservation] ?? []
    }

    private func landmarkResults(in cgImage: CGImage) throws -> [VNFaceObservation] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        return request.results as? [VNFaceObservation] ?? []
    }

    private func matchingLandmarks(
        for observation: VNFaceObservation,
        in observations: [VNFaceObservation]
    ) -> VNFaceLandmarks2D? {
        if let exactMatch = observations.first(where: { $0.boundingBox == observation.boundingBox })?.landmarks {
            return exactMatch
        }

        guard observations.isEmpty == false else {
            return nil
        }

        let nearest = observations.min {
            centerDistance($0.boundingBox, observation.boundingBox) < centerDistance($1.boundingBox, observation.boundingBox)
        }

        guard let matched = nearest?.landmarks else {
            return nil
        }

        return matched
    }

    private func align(image: CGImage, to bounds: CGRect, alignment _: FaceAlignment) -> CGImage? {
        let paddedBounds = expanded(bounds: bounds, in: CGSize(width: image.width, height: image.height))
        let roundedBounds = paddedBounds.integral
        guard let faceCrop = image.cropping(to: roundedBounds) else {
            return nil
        }

        return resizeAndNormalize(faceCrop)
    }

    private func resizeAndNormalize(_ image: CGImage) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            let cg = UIGraphicsGetCurrentContext()
            cg?.setFillColor(UIColor.black.cgColor)
            cg?.fill(CGRect(origin: .zero, size: canvasSize))

            let sourceSize = CGSize(width: image.width, height: image.height)
            let widthScale = canvasSize.width / sourceSize.width
            let heightScale = canvasSize.height / sourceSize.height
            let scale = max(widthScale, heightScale)
            let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let drawRect = CGRect(
                x: (canvasSize.width - targetSize.width) / 2,
                y: (canvasSize.height - targetSize.height) / 2,
                width: targetSize.width,
                height: targetSize.height
            )

            if let uiImage = UIImage(cgImage: image) {
                uiImage.draw(in: drawRect)
            }
        }.cgImage
    }

    private func expanded(bounds: CGRect, in size: CGSize) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let faceExtent = max(bounds.width, bounds.height)
        let padding = max(faceExtent * defaultPadding, 12.0)
        let padded = CGRect(
            x: bounds.midX - (faceExtent + padding) / 2,
            y: bounds.midY - (faceExtent + padding) / 2,
            width: faceExtent + padding,
            height: faceExtent + padding
        )

        return padded.intersection(CGRect(origin: .zero, size: size))
    }

    private func centerDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let dx = lhs.midX - rhs.midX
        let dy = lhs.midY - rhs.midY
        return dx * dx + dy * dy
    }
}
