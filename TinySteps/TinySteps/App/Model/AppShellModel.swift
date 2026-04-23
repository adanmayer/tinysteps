import Foundation
import Observation

@Observable
@MainActor
final class AppShellModel {

    enum AppFlow: Equatable {
        case launching
        case signedOut(lastHost: SchoolHost?)
        case authenticating
        case signedIn(AuthSession)
        case authFailure(lastHost: SchoolHost?, message: String)
        case expiredSession(lastHost: SchoolHost?)
        case blockingError(String)
    }

    private(set) var hasCompletedInitialRestore = false

    private let authController: AuthController
    private let navigationState: AppNavigationState
    private var hasStarted = false

    init(
        authController: AuthController,
        navigationState: AppNavigationState
    ) {
        self.authController = authController
        self.navigationState = navigationState
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true

        Task {
            await authController.restoreSession()
            hasCompletedInitialRestore = true
        }
    }

    func signOut() {
        Task {
            await authController.signOut()
            navigationState.resetForSignedOutState()
        }
    }

    func shouldShowOnboarding() -> Bool {
        navigationState.consumeOnboarding()
    }

    var flow: AppFlow {
        Self.flow(for: authController.authState)
    }

    func handleIncomingURL(_ url: URL) -> Bool {
        if authController.handleRedirectURL(url) {
            return true
        }

        return navigationState.handleIncomingURL(url)
    }

    static func flow(for authState: AuthState) -> AppFlow {
        switch authState {
        case .signedOut(let lastHost):
            .signedOut(lastHost: lastHost)
        case .restoring:
            .launching
        case .authenticating:
            .authenticating
        case .signedIn(let session):
            .signedIn(session)
        case .failed(let lastHost, let message):
            .authFailure(lastHost: lastHost, message: message)
        case .expired(let lastHost):
            .expiredSession(lastHost: lastHost)
        }
    }
}
