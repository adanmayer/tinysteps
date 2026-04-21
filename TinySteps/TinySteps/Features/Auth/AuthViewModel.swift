import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {
    private let authController: AuthController

    init(authController: AuthController) {
        self.authController = authController
    }

    func signIn() {
        Task {
            await authController.signIn()
        }
    }

    var errorMessage: String? {
        switch authController.authState {
        case .failed(_, let message):
            return message
        case .expired:
            return AuthError.sessionExpired.localizedDescription
        default:
            return nil
        }
    }

    var isAuthenticating: Bool {
        switch authController.authState {
        case .restoring, .authenticating:
            return true
        default:
            return false
        }
    }

    var lastConnectedHost: String? {
        switch authController.authState {
        case .signedOut(let lastHost):
            return lastHost?.displayName
        case .failed(let lastHost, _):
            return lastHost?.displayName
        case .expired(let lastHost):
            return lastHost?.displayName
        default:
            return nil
        }
    }
}
