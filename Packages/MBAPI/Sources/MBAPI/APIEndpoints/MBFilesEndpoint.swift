import Foundation

public protocol MBFilesEndpoint: Sendable {
    func list(
        in context: MBSessionContext,
        classID: String,
        folderID: String?
    ) async throws -> [MBFile]

    func listParentAssociation(
        in context: MBSessionContext,
        folderID: String?
    ) async throws -> [MBFile]
}

public struct MBFilesEndpointClient: MBFilesEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(
        in context: MBSessionContext,
        classID: String,
        folderID: String?
    ) async throws -> [MBFile] {
        var query: [String: String] = [:]
        if let folderID {
            query["folder_id"] = folderID
        }

        return try await requester.loadItems(
            as: MBFile.self,
            from: "\(context.role.urlPathComponent)/classes/\(classID)/files",
            in: context,
            query: query
        )
    }

    public func listParentAssociation(
        in context: MBSessionContext,
        folderID: String?
    ) async throws -> [MBFile] {
        var query: [String: String] = [:]
        if let folderID {
            query["folder_id"] = folderID
        }

        return try await requester.loadItems(
            as: MBFile.self,
            from: "\(context.role.urlPathComponent)/pa/files",
            in: context,
            query: query
        )
    }
}
