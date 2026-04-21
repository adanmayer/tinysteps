import CoreGraphics
import UIKit

enum FaceCropper {
    static func fixedOrientation(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        guard let cgOriented = image.ciImage else {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }.cgImage
        }

        return CIContext().createCGImage(cgOriented.oriented(orientation(for: image)), from: cgOriented.extent)
    }

    static func imageBounds(_ observation: CGRect, for imageSize: CGSize) -> CGRect {
        let width = imageSize.width
        let height = imageSize.height

        let x = observation.origin.x * width
        let y = (1 - observation.origin.y - observation.height) * height
        let w = observation.width * width
        let h = observation.height * height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func orientation(for image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
