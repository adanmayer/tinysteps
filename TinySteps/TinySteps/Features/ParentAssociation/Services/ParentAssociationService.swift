import Foundation
import MBAPI

protocol ParentAssociationService {
    func loadSchool(
        for session: AuthSession
    ) async throws -> MBSchool

    func loadParentAssociationMenu(
        for session: AuthSession,
        childContext: ChildContext
    ) async throws -> [MBParentAssociationMenuItem]

    func listAttendanceExcusals(
        for session: AuthSession,
        childContext: ChildContext
    ) async throws -> [MBAttendanceExcusal]

    func submitAttendanceExcusal(
        for session: AuthSession,
        childContext: ChildContext,
        submission: MBAttendanceExcusalSubmission
    ) async throws
}

struct MBParentAssociationService: ParentAssociationService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadSchool(
        for session: AuthSession
    ) async throws -> MBSchool {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.loadSchool(in: credentials.sessionContext())
    }

    func loadParentAssociationMenu(
        for session: AuthSession,
        childContext: ChildContext
    ) async throws -> [MBParentAssociationMenuItem] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listParentAssociationMenu(
            in: credentials.sessionContext(childID: childContext.apiChildID)
        )
    }

    func listAttendanceExcusals(
        for session: AuthSession,
        childContext: ChildContext
    ) async throws -> [MBAttendanceExcusal] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listAttendanceExcusals(
            in: credentials.sessionContext(childID: childContext.apiChildID)
        )
    }

    func submitAttendanceExcusal(
        for session: AuthSession,
        childContext: ChildContext,
        submission: MBAttendanceExcusalSubmission
    ) async throws {
        let credentials = try credentialsProvider.credentials(for: session)
        try await client.submitAttendanceExcusal(
            in: credentials.sessionContext(childID: childContext.apiChildID),
            submission: submission
        )
    }
}

extension MBParentAssociationService {
    static func preview(filePath: String = #filePath) -> MBParentAssociationService {
        MBParentAssociationService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}
