import Foundation

public protocol MBGeneralEndpoint: Sendable {
    func school(in context: MBSessionContext) async throws -> MBSchool
    func account(in context: MBSessionContext) async throws -> MBAccount
}

public struct MBGeneralEndpointClient: MBGeneralEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func school(in context: MBSessionContext) async throws -> MBSchool {
        return try await requester.loadObject(
            as: MBSchool.self,
            from: "school",
            in: context
        )
    }

    public func account(in context: MBSessionContext) async throws -> MBAccount {
        return try await requester.loadObject(
            as: MBAccount.self,
            from: "account",
            in: context
        )
    }
}
