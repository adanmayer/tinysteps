import Foundation

public protocol MBClassesEndpoint: Sendable {
    func list(in context: MBSessionContext) async throws -> [MBClass]
    func list(
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [MBClass]
}

public struct MBClassesEndpointClient: MBClassesEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(in context: MBSessionContext) async throws -> [MBClass] {
        try await list(in: context, query: [:])
    }

    public func list(
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [MBClass] {
        var resolvedQuery = query
        resolvedQuery["per_page"] = resolvedQuery["per_page"] ?? "100"

        let endpointPath = "\(context.role.urlPathComponent)/classes" + (context.role == .teacher || context.role == .advisor ? "/roster/my" : "/roster")

        return try await requester.loadItems(
            as: MBClass.self,
            from: endpointPath,
            in: context,
            query: resolvedQuery
        )
    }
}
