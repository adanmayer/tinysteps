import CoreGraphics
import Foundation

struct AlignedFace: Identifiable {
    let id: UUID
    let bounds: CGRect
    let image: CGImage

    init(id: UUID = UUID(), bounds: CGRect, image: CGImage) {
        self.id = id
        self.bounds = bounds
        self.image = image
    }
}
