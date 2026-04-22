import Foundation

public protocol MBChildrenEndpoint: Sendable {
    func list(in context: MBSessionContext) async throws -> [MBChild]
}

public struct MBChildrenEndpointClient: MBChildrenEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(in context: MBSessionContext) async throws -> [MBChild] {
        try await requester.loadItems(
            as: MBChild.self,
            from: "\(context.role.urlPathComponent)/children",
            in: context
        )
    }
}
