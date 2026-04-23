import Foundation
import MBAPI

protocol PortfolioService: Sendable {
    func loadPortfolioTimeline(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [MBAPI.Portfolio.TimelineItem]

    func createClassNote(
        for session: AuthSession,
        classID: String,
        payload: PortfolioNoteCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse

    func uploadPhoto(
        for session: AuthSession,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> MBAPI.Portfolio.UploadedPhoto

    func createClassPhoto(
        for session: AuthSession,
        classID: String,
        payload: PortfolioPhotoCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse

    func loadClassPortfolioSettings(
        for session: AuthSession,
        programID: String
    ) async throws -> MBAPI.Portfolio.Settings
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

    func createClassNote(
        for session: AuthSession,
        classID: String,
        payload: PortfolioNoteCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse {
        let credentials = try credentialsProvider.credentials(for: session)

        return try await client.createPortfolioClassNote(
            in: credentials.sessionContext(childID: nil),
            classID: classID,
            payload: payload
        )
    }

    func uploadPhoto(
        for session: AuthSession,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> MBAPI.Portfolio.UploadedPhoto {
        let credentials = try credentialsProvider.credentials(for: session)

        return try await client.uploadPortfolioPhoto(
            in: credentials.sessionContext(childID: nil),
            imageData: imageData,
            filename: filename,
            mimeType: mimeType
        )
    }

    func createClassPhoto(
        for session: AuthSession,
        classID: String,
        payload: PortfolioPhotoCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse {
        let credentials = try credentialsProvider.credentials(for: session)

        return try await client.createPortfolioClassPhoto(
            in: credentials.sessionContext(childID: nil),
            classID: classID,
            payload: payload
        )
    }

    func loadClassPortfolioSettings(
        for session: AuthSession,
        programID: String
    ) async throws -> MBAPI.Portfolio.Settings {
        let credentials = try credentialsProvider.credentials(for: session)

        return try await client.loadClassPortfolioSettings(
            in: credentials.sessionContext(childID: nil),
            programID: programID
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
