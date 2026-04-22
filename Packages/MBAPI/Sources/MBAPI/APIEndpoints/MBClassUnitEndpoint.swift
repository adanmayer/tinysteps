import Foundation

public protocol MBClassUnitEndpoint: Sendable {
    func list(
        in context: MBSessionContext,
        classID: String,
        query: [String: String]
    ) async throws -> [MBClassUnit]
}

public struct MBClassUnitEndpointClient: MBClassUnitEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(
        in context: MBSessionContext,
        classID: String,
        query: [String: String] = [:]
    ) async throws -> [MBClassUnit] {
        try await requester.loadItems(
            as: MBClassUnit.self,
            from: "\(context.role.urlPathComponent)/classes/\(classID)/units",
            in: context,
            query: query
        )
    }
}
