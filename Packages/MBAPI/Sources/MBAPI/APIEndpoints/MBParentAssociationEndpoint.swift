import Foundation

public protocol MBParentAssociationEndpoint: Sendable {
    func listMenu(
        in context: MBSessionContext
    ) async throws -> [MBParentAssociationMenuItem]

    func listAttendanceExcusals(
        in context: MBSessionContext
    ) async throws -> [MBAttendanceExcusal]

    func submitAttendanceExcusal(
        in context: MBSessionContext,
        submission: MBAttendanceExcusalSubmission
    ) async throws
}

public struct MBParentAssociationEndpointClient: MBParentAssociationEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func listMenu(
        in context: MBSessionContext
    ) async throws -> [MBParentAssociationMenuItem] {
        try await requester.loadItems(
            as: MBParentAssociationMenuItem.self,
            from: "\(context.role.urlPathComponent)/pa/menu",
            in: context
        )
    }

    public func listAttendanceExcusals(
        in context: MBSessionContext
    ) async throws -> [MBAttendanceExcusal] {
        try await requester.loadItems(
            as: MBAttendanceExcusal.self,
            from: "\(context.role.urlPathComponent)/attendance_excusals",
            in: context
        )
    }

    public func submitAttendanceExcusal(
        in context: MBSessionContext,
        submission: MBAttendanceExcusalSubmission
    ) async throws {
        let payload: Data
        do {
            payload = try JSONEncoder().encode(submission)
        } catch {
            throw MBClientError.decodingFailed(
                "Failed to encode attendance excusal payload: \(error.localizedDescription)"
            )
        }

        try await requester.send(
            to: "\(context.role.urlPathComponent)/attendance_excusals",
            in: context,
            method: "POST",
            query: [:],
            body: payload
        )
    }
}
