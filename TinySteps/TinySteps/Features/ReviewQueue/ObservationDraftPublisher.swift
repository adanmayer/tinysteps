import Foundation
import MBAPI

protocol ObservationDraftPublishing: Sendable {
    var isAvailable: Bool { get }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws

    func publish(
        _ draft: FaceCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws
}

enum ObservationDraftPublishError: LocalizedError, Equatable, Sendable {
    case unavailable
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Publishing is not connected yet. This draft stays on this device."
        case .validation(let message):
            return message
        }
    }
}

struct UnavailableObservationDraftPublisher: ObservationDraftPublishing {
    var isAvailable: Bool {
        false
    }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
        throw ObservationDraftPublishError.unavailable
    }

    func publish(
        _ draft: FaceCaptureDraft,
        session: AuthSession,
        selectedClass: MBClass?
    ) async throws {
        throw ObservationDraftPublishError.unavailable
    }
}
