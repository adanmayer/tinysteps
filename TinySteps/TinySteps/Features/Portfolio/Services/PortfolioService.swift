import Foundation
import MBAPI
import CryptoKit

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

    func uploadAudioDescription(
        for session: AuthSession,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String
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

    func uploadAudioDescription(
        for session: AuthSession,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        let credentials = try credentialsProvider.credentials(for: session)
        let context = credentials.sessionContext(childID: nil)
        let request = MBAPI.Portfolio.DirectUploadRequest(
            filename: filename,
            contentType: mimeType,
            byteSize: audioData.count,
            checksum: audioData.md5Base64Digest()
        )
        let response = try await client.createPortfolioDirectUpload(
            in: context,
            payload: request
        )

        guard let destination = URL(string: response.directUpload.url) else {
            throw PortfolioServiceError.directUploadResponseMalformed("Missing or invalid direct-upload URL.")
        }

        var headers = response.directUpload.headers
        if headers["Content-Length"] == nil {
            headers["Content-Length"] = String(audioData.count)
        }
        headers["Content-Type"] = mimeType

        try await client.uploadToDirectUploadURL(
            destination,
            headers: headers,
            body: audioData
        )

        guard let signedID = response.signedID, signedID.isEmpty == false else {
            throw PortfolioServiceError.directUploadResponseMalformed("Missing signed_id from direct-upload response.")
        }

        return signedID
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

private enum PortfolioServiceError: LocalizedError, Sendable {
    case directUploadResponseMalformed(String)

    var errorDescription: String? {
        switch self {
        case .directUploadResponseMalformed(let message):
            message
        }
    }
}

private extension Data {
    func md5Base64Digest() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return Data(digest).base64EncodedString()
    }
}
