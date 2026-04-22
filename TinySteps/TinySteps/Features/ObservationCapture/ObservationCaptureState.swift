import Foundation

enum ObservationCaptureState: Equatable, Sendable {
    case idle
    case permissionUnknown
    case requestingPermission
    case ready
    case recording
    case transcribing
    case suggestingTags
    case draftReady
    case saving
    case saved
    case failed(ObservationCaptureError)
}

enum ObservationCaptureError: Equatable, LocalizedError, Sendable {
    case microphonePermissionDenied
    case speechPermissionDenied
    case speechUnavailable(String)
    case noSpeechDetected
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is needed to capture an observation."
        case .speechPermissionDenied:
            return "Speech recognition access is needed to transcribe your observation."
        case .speechUnavailable(let message):
            return message
        case .noSpeechDetected:
            return "No speech was detected. Press and hold to try again."
        case .saveFailed(let message):
            return "Local draft could not be saved. \(message)"
        }
    }
}

enum ObservationSpeechAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case microphoneDenied
    case denied
    case restricted
    case unknown
}
