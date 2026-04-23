import Foundation

public protocol MBPortfolioEndpoint: Sendable {
    func listTimeline(
        in context: MBSessionContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [Portfolio.TimelineItem]

    func createClassResource<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        kind: Portfolio.ResourceKind,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse

    func uploadPhoto(
        in context: MBSessionContext,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> Portfolio.UploadedPhoto

    func uploadAsset(
        in context: MBSessionContext,
        fileData: Data,
        filename: String,
        mimeType: String
    ) async throws -> Portfolio.UploadedAsset

    func createDirectUpload(
        in context: MBSessionContext,
        payload: Portfolio.DirectUploadRequest
    ) async throws -> Portfolio.DirectUploadResponse

    func loadClassPortfolioSettings(
        in context: MBSessionContext,
        programID: String
    ) async throws -> Portfolio.Settings
}

public struct MBPortfolioEndpointClient: MBPortfolioEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func listTimeline(
        in context: MBSessionContext,
        classID: String? = nil,
        query: [String: String] = [:]
    ) async throws -> [Portfolio.TimelineItem] {
        let endpointPath: String
        if let classID, !classID.isEmpty {
            endpointPath = "\(context.role.urlPathComponent)/portfolio/classes/\(classID)/timeline"
        } else {
            endpointPath = "\(context.role.urlPathComponent)/portfolio/timeline"
        }

        return try await requester.loadItems(
            as: Portfolio.TimelineItem.self,
            from: endpointPath,
            in: context,
            query: query
        )
    }

    public func createClassResource<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        kind: Portfolio.ResourceKind,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        let endpointPath = "\(context.role.urlPathComponent)/portfolio/classes/\(classID)/resources/\(kind.rawValue)"
        return try await requester.send(
            Portfolio.ResourceCreateResponse.self,
            to: endpointPath,
            in: context,
            method: "POST",
            query: [:],
            body: payload
        )
    }

    public func uploadPhoto(
        in context: MBSessionContext,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> Portfolio.UploadedPhoto {
        try await requester.uploadMultipart(
            as: Portfolio.UploadedPhoto.self,
            to: "photos",
            in: context,
            query: [:],
            file: MBMultipartFile(
                fieldName: "file",
                filename: filename,
                mimeType: mimeType,
                data: imageData
            )
        )
    }

    public func uploadAsset(
        in context: MBSessionContext,
        fileData: Data,
        filename: String,
        mimeType: String
    ) async throws -> Portfolio.UploadedAsset {
        try await requester.uploadMultipart(
            as: Portfolio.UploadedAsset.self,
            to: "assets",
            in: context,
            query: [:],
            file: MBMultipartFile(
                fieldName: "file",
                filename: filename,
                mimeType: mimeType,
                data: fileData
            )
        )
    }

    public func createDirectUpload(
        in context: MBSessionContext,
        payload: Portfolio.DirectUploadRequest
    ) async throws -> Portfolio.DirectUploadResponse {
        try await requester.send(
            Portfolio.DirectUploadResponse.self,
            to: "direct_uploads",
            in: context,
            method: "POST",
            query: [:],
            body: payload
        )
    }

    public func loadClassPortfolioSettings(
        in context: MBSessionContext,
        programID: String
    ) async throws -> Portfolio.Settings {
        try await requester.loadObject(
            as: Portfolio.Settings.self,
            from: "school/programs/\(programID)/class_portfolio_settings",
            in: context,
            query: [:]
        )
    }
}

public extension MBPortfolioEndpoint {
    func createClassNote<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        try await createClassResource(
            in: context,
            classID: classID,
            kind: .notes,
            payload: payload
        )
    }

    func createClassPhoto<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        try await createClassResource(
            in: context,
            classID: classID,
            kind: .photos,
            payload: payload
        )
    }
}
