import Foundation
import MBAPI

protocol PortfolioService {
    func loadPortfolioTimeline(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [MBAPI.Portfolio.TimelineItem]
}

struct MBPortfolioService: PortfolioService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadPortfolioTimeline(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [MBAPI.Portfolio.TimelineItem] {
        let credentials = try credentialsProvider.credentials(for: session)

        return try await client.listPortfolioTimeline(
            in: credentials.sessionContext(childID: childContext.apiChildID),
            classID: classID,
            query: query
        )
    }
}

extension MBPortfolioService {
    static func preview(filePath: String = #filePath) -> MBPortfolioService {
        MBPortfolioService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}
