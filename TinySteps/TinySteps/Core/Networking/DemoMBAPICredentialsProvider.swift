import Foundation
import MBAPI

struct DemoMBAPICredentialsProvider: MBAPICredentialsProvider {
    private let accessToken: String
    private let role: MBAPIRole

    init(accessToken: String = "demo-token", role: MBAPIRole = .parent) {
        self.accessToken = accessToken
        self.role = role
    }

    func credentials(for session: AuthSession) throws -> MBAPICredentials {
        MBAPICredentials(
            apiBaseURL: session.schoolHost.apiBaseURL,
            accessToken: accessToken,
            role: session.apiRole ?? role
        )
    }
}
