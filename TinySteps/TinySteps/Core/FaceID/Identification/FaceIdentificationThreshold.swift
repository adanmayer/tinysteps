import Foundation

enum FaceIdentificationThreshold {
    static let defaultValue: Float = 1.48
    static let userDefaultsKey = "tinysteps.faceIdentification.d2Threshold"

    nonisolated static func current() -> Float {
        guard let value = UserDefaults.standard.object(forKey: userDefaultsKey) as? Double else {
            return defaultValue
        }
        return Float(value)
    }

    nonisolated static func update(_ value: Float) {
        UserDefaults.standard.set(Double(value), forKey: userDefaultsKey)
    }
}
