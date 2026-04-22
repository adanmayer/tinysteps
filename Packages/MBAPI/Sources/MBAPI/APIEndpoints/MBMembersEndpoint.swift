import Foundation

public protocol MBMembersEndpoint: Sendable {
    func list(
        in context: MBSessionContext,
        classID: String,
        roleFilter: String?
    ) async throws -> [MBMember]
}

public struct MBMembersEndpointClient: MBMembersEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func list(
        in context: MBSessionContext,
        classID: String,
        roleFilter: String? = nil
    ) async throws -> [MBMember] {
        var query: [String: String] = [:]
        if let roleFilter {
            query["role"] = roleFilter
        }

        return try await requester.loadItems(
            as: MBMember.self,
            from: "\(context.role.urlPathComponent)/classes/\(classID)/members",
            in: context,
            query: query
        )
    }
}
