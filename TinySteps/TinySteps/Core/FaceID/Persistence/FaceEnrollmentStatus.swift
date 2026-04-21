import Foundation

enum FaceEnrollmentStatus: Equatable, Sendable {
    case enrolled(photoCount: Int, updatedAt: Date)
    case needsSetup
    case invalid(reason: String)
    case disabled
    case unavailable
}

extension FaceEnrollmentStatus {
    var isEnrolled: Bool {
        if case .enrolled = self {
            return true
        }

        return false
    }

    var needsSetup: Bool {
        switch self {
        case .enrolled:
            return false
        case .needsSetup, .invalid, .disabled, .unavailable:
            return true
        }
    }
}

