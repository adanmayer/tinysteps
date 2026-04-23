import Foundation
import MBAPI

protocol ClassesService: Sendable {
    func loadClasses(for session: AuthSession, childContext: ChildContext) async throws -> [MBClass]
    func loadClassTasks(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String,
        query: [String: String]
    ) async throws -> [MBAPI.MBClassTask]
    func loadClassUnits(for session: AuthSession, childContext: ChildContext, classID: String) async throws -> [MBAPI.MBClassUnit]
    func loadClassStudents(for session: AuthSession, classID: String) async throws -> [MBMember]
}

struct MBClassesService: ClassesService {
    private let credentialsProvider: MBAPICredentialsProvider
    private let client: any MBClient
    private let classPageSize = 100

    init(
        credentialsProvider: MBAPICredentialsProvider,
        client: any MBClient = MBLiveClient()
    ) {
        self.credentialsProvider = credentialsProvider
        self.client = client
    }

    func loadClasses(for session: AuthSession, childContext: ChildContext) async throws -> [MBClass] {
        let credentials = try credentialsProvider.credentials(for: session)
        var classes: [MBClass] = []
        var page = 1

        while true {
            var query: [String: String] = [
                "page": "\(page)",
                "per_page": "\(classPageSize)"
            ]

            let pageClasses = try await client.listClasses(
                in: credentials.sessionContext(childID: childContext.apiChildID),
                query: query
            )
            classes.append(contentsOf: pageClasses)

            guard pageClasses.count == classPageSize else {
                break
            }

            page += 1
        }

        return classes
    }

    func loadClassTasks(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String,
        query: [String: String]
    ) async throws -> [MBAPI.MBClassTask] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listClassTasks(
            in: credentials.sessionContext(childID: childContext.apiChildID),
            classID: classID,
            query: query
        )
    }

    func loadClassUnits(for session: AuthSession, childContext: ChildContext, classID: String) async throws -> [MBAPI.MBClassUnit] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listClassUnits(
            in: credentials.sessionContext(childID: childContext.apiChildID),
            classID: classID,
            query: [:]
        )
    }

    func loadClassStudents(
        for session: AuthSession,
        classID: String
    ) async throws -> [MBMember] {
        let credentials = try credentialsProvider.credentials(for: session)
        return try await client.listClassMembers(
            in: credentials.sessionContext(childID: nil),
            classID: classID,
            roleFilter: "students"
        )
    }

}

extension MBClassesService {
    static func preview(filePath: String = #filePath) -> MBClassesService {
        MBClassesService(
            credentialsProvider: DemoMBAPICredentialsProvider(),
            client: MBMockDataPreviewFactory.replayClient(filePath: filePath)
        )
    }
}
