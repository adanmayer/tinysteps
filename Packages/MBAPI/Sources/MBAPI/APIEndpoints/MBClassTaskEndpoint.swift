import Foundation

public protocol MBClassTaskEndpoint: Sendable {
    func list(
        in context: MBSessionContext,
        classID: String,
        query: [String: String]
    ) async throws -> [MBClassTask]
}

public struct MBClassTaskEndpointClient: MBClassTaskEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(
        in context: MBSessionContext,
        classID: String,
        query: [String: String] = [:]
    ) async throws -> [MBClassTask] {
        var query = query
        query["event_type[]"] = "tasks"
        query["group_id"] = classID

        return try await requester.loadItems(
            as: MBClassTask.self,
            from: "\(context.role.urlPathComponent)/generic_events",
            in: context,
            query: query
        )
    }
}
