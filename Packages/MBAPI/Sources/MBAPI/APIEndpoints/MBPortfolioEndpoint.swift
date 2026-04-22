import Foundation

public protocol MBPortfolioEndpoint: Sendable {
    func listTimeline(
        in context: MBSessionContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [Portfolio.TimelineItem]
}

public struct MBPortfolioEndpointClient: MBPortfolioEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func listTimeline(
        in context: MBSessionContext,
        classID: String? = nil,
        query: [String: String] = [:]
    ) async throws -> [Portfolio.TimelineItem] {
        let endpointPath: String
        if let classID, !classID.isEmpty {
            endpointPath = "\(context.role.urlPathComponent)/portfolio/classes/\(classID)/timeline"
        } else {
            endpointPath = "\(context.role.urlPathComponent)/portfolio/timeline"
        }

        return try await requester.loadItems(
            as: Portfolio.TimelineItem.self,
            from: endpointPath,
            in: context,
            query: query
        )
    }
}
