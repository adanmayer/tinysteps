import Foundation
import MBAPI

enum FilesScope: Equatable, Sendable {
    case parentAssociation
    case schoolClass(id: String)
}

protocol FilesService {
    func loadFiles(
        for session: AuthSession,
        childContext: ChildContext,
        scope: FilesScope,
        folderID: String?
    ) async throws -> [MBFile]
}

struct MBFilesService: FilesService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadFiles(
        for session: AuthSession,
        childContext: ChildContext,
        scope: FilesScope,
        folderID: String?
    ) async throws -> [MBFile] {
        let credentials = try credentialsProvider.credentials(for: session)
        let context = credentials.sessionContext(childID: childContext.apiChildID)

        switch scope {
        case .parentAssociation:
            return try await client.listParentAssociationFiles(
                in: context,
                folderID: folderID
            )
        case .schoolClass(let classID):
            return try await client.listClassFiles(
                in: context,
                classID: classID,
                folderID: folderID
            )
        }
    }
}

extension MBFilesService {
    static func preview(filePath: String = #filePath) -> MBFilesService {
        MBFilesService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}

private extension FilesScope {
    var storageKey: String {
        switch self {
        case .parentAssociation:
            return "parentAssociation"
        case .schoolClass(let id):
            return "schoolClass::\(id)"
        }
    }
}
