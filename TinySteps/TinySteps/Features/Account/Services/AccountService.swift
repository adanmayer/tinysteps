import Foundation
import MBAPI

protocol AccountService {
    func loadAccount(for session: AuthSession) async throws -> MBAccount
}

struct MBAccountService: AccountService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadAccount(for session: AuthSession) async throws -> MBAccount {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.loadAccount(in: credentials.sessionContext())
    }
}

extension MBAccountService {
    static func preview(filePath: String = #filePath) -> MBAccountService {
        MBAccountService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}
