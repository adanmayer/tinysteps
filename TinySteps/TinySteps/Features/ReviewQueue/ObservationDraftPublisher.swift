import Foundation

protocol ObservationDraftPublishing: Sendable {
    var isAvailable: Bool { get }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession
    ) async throws
}

enum ObservationDraftPublishError: LocalizedError, Equatable, Sendable {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Publishing is not connected yet. This draft stays on this device."
        }
    }
}

struct UnavailableObservationDraftPublisher: ObservationDraftPublishing {
    var isAvailable: Bool {
        false
    }

    func publish(
        _ draft: ObservationCaptureDraft,
        session: AuthSession
    ) async throws {
        throw ObservationDraftPublishError.unavailable
    }
}
