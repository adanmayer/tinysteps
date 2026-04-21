import Foundation
import MBAPI

struct MBAPICredentials: Equatable {
    let apiBaseURL: URL
    let accessToken: String
    let role: MBAPIRole

    func sessionContext(childID: String? = nil) -> MBSessionContext {
        MBSessionContext(
            apiBaseURL: apiBaseURL,
            accessToken: accessToken,
            role: role,
            childID: childID
        )
    }
}

protocol MBAPICredentialsProvider {
    func credentials(for session: AuthSession) throws -> MBAPICredentials
}

struct StoredTokenMBAPICredentialsProvider: MBAPICredentialsProvider {
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    func credentials(for session: AuthSession) throws -> MBAPICredentials {
        guard let tokenState = try tokenStore.loadTokenState() else {
            throw AuthError.sessionExpired
        }

        let sameAccount = tokenState.accountIdentifier == session.accountIdentifier
        guard tokenState.schoolHost == session.schoolHost, sameAccount else {
            throw AuthError.sessionExpired
        }

        return MBAPICredentials(
            apiBaseURL: session.schoolHost.apiBaseURL,
            accessToken: tokenState.accessToken,
            role: tokenState.apiRole ?? session.apiRole ?? .parent
        )
    }
}
