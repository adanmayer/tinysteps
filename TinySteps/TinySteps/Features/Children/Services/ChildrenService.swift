import Foundation
import MBAPI

protocol ChildrenService {
    func loadChildren(for session: AuthSession) async throws -> [MBChild]
}

struct MBChildrenService: ChildrenService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadChildren(for session: AuthSession) async throws -> [MBChild] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listChildren(in: credentials.sessionContext())
    }
}

extension MBChildrenService {
    static func preview(filePath: String = #filePath) -> MBChildrenService {
        MBChildrenService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}
