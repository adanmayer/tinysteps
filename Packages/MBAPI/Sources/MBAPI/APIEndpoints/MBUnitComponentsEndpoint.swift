import Foundation

public protocol MBUnitComponentsEndpoint: Sendable {
    func loadComponents(
        in context: MBSessionContext,
        unitID: String,
        query: [String: String]
    ) async throws -> MBUnitComponents

    func loadComponents(
        in context: MBSessionContext,
        classID: String,
        unitID: String,
        query: [String: String]
    ) async throws -> MBUnitComponents
}

public struct MBUnitComponentsEndpointClient: MBUnitComponentsEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func loadComponents(
        in context: MBSessionContext,
        unitID: String,
        query: [String: String] = [:]
    ) async throws -> MBUnitComponents {
        try await requester.loadObject(
            as: MBUnitComponents.self,
            from: "\(context.role.urlPathComponent)/units/\(unitID)/components",
            in: context,
            query: query
        )
    }

    public func loadComponents(
        in context: MBSessionContext,
        classID: String,
        unitID: String,
        query: [String: String] = [:]
    ) async throws -> MBUnitComponents {
        try await requester.loadObject(
            as: MBUnitComponents.self,
            from: "\(context.role.urlPathComponent)/classes/\(classID)/units/\(unitID)/components",
            in: context,
            query: query
        )
    }
}
