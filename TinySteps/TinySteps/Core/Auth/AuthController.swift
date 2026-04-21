import Foundation
import MBAPI
import Observation

@Observable
@MainActor
final class AuthController {
    private(set) var authState: AuthState = .signedOut(lastHost: nil)

    private let configurationService: OAuthConfigurationService
    private let sessionDriver: OAuthSessionDriver
    private let tokenStore: TokenStore

    init(
        tokenStore: TokenStore,
        configurationService: OAuthConfigurationService,
        sessionDriver: OAuthSessionDriver
    ) {
        self.tokenStore = tokenStore
        self.configurationService = configurationService
        self.sessionDriver = sessionDriver
    }

    func restoreSession() async {
        authState = .restoring
        var restoredHost: SchoolHost?

        do {
            guard let tokenState = try tokenStore.loadTokenState() else {
                authState = .signedOut(lastHost: nil)
                return
            }

            restoredHost = tokenState.schoolHost

            if tokenState.needsRefresh {
                guard tokenState.refreshToken != nil else {
                    try tokenStore.clearTokenState()
                    authState = .expired(lastHost: tokenState.schoolHost)
                    return
                }

                let refreshedToken = try await sessionDriver.refresh(using: tokenState)
                let refreshedState = StoredTokenState(
                    schoolHost: tokenState.schoolHost,
                    tokenResult: refreshedToken,
                    apiRole: tokenState.apiRole
                )

                try tokenStore.saveTokenState(refreshedState)
                authState = .signedIn(AuthSession(tokenState: refreshedState))
                return
            }

            authState = .signedIn(AuthSession(tokenState: tokenState))
        } catch let error as AuthError {
            if restoredHost != nil {
                try? tokenStore.clearTokenState()
            }
            authState = .failed(lastHost: restoredHost, message: error.localizedDescription)
        } catch {
            if restoredHost != nil {
                try? tokenStore.clearTokenState()
            }
            authState = .failed(lastHost: restoredHost, message: error.localizedDescription)
        }
    }

    func signIn() async {
        authState = .authenticating

        do {
            let configuration = try await configurationService.bootstrapConfiguration()
            let loginResult = try await sessionDriver.signIn(using: configuration)
            let tokenState = StoredTokenState(
                schoolHost: loginResult.resolvedSchoolHost,
                tokenResult: loginResult.tokenResult,
                apiRole: nil
            )

            try tokenStore.saveTokenState(tokenState)
            authState = .signedIn(AuthSession(tokenState: tokenState))
        } catch let error as AuthError {
            authState = .failed(lastHost: currentLastHost, message: error.localizedDescription)
        } catch {
            authState = .failed(lastHost: currentLastHost, message: error.localizedDescription)
        }
    }

    func handleRedirectURL(_ url: URL) -> Bool {
        sessionDriver.handleRedirectURL(url)
    }

    func recordIdentifiedRole(_ role: MBAPIRole) {
        guard case .signedIn(let session) = authState, session.apiRole != role else {
            return
        }

        do {
            guard let tokenState = try tokenStore.loadTokenState() else {
                return
            }

            let updatedState = tokenState.with(apiRole: role)
            try tokenStore.saveTokenState(updatedState)
            authState = .signedIn(AuthSession(tokenState: updatedState, establishedAt: session.establishedAt))
        } catch {
            // non-fatal — role caching is best-effort
        }
    }

    func signOut() async {
        do {
            try tokenStore.clearTokenState()
            authState = .signedOut(lastHost: currentLastHost)
        } catch let error as AuthError {
            authState = .failed(lastHost: currentLastHost, message: error.localizedDescription)
        } catch {
            authState = .failed(lastHost: currentLastHost, message: error.localizedDescription)
        }
    }

    private var currentLastHost: SchoolHost? {
        switch authState {
        case .signedOut(let lastHost), .failed(let lastHost, _), .expired(let lastHost):
            lastHost
        case .authenticating:
            nil
        case .signedIn(let session):
            session.schoolHost
        case .restoring:
            nil
        }
    }
}
