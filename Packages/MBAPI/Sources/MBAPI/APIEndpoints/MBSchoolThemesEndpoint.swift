import Foundation

public protocol MBSchoolThemesEndpoint: Sendable {
    func loadThemes(
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [MBTRTheme]
}

public struct MBSchoolThemesEndpointClient: MBSchoolThemesEndpoint, Sendable {
    private let requester: MBEndpointRequesting

    init(requester: MBEndpointRequesting) {
        self.requester = requester
    }

    public func loadThemes(
        in context: MBSessionContext,
        query: [String: String] = [:]
    ) async throws -> [MBTRTheme] {
        try await requester.loadItems(
            as: MBTRTheme.self,
            from: "school/tr_themes",
            in: context,
            query: query
        )
    }
}
