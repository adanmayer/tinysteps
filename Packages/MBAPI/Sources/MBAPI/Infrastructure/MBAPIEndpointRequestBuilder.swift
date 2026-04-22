import Foundation

struct MBAPIEndpointRequestBuilder: Sendable {
    static func requestURL(for endpointPath: String, in context: MBSessionContext, query: [String: String] = [:]) -> URL {
        let baseURL = context.apiBaseURL.appendingEndpointPath(endpointPath)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "child_id" }
        if let childID = context.childID, !childID.isEmpty {
            queryItems.append(URLQueryItem(name: "child_id", value: childID))
        }

        for (name, value) in query.sorted(by: { lhs, rhs in
            lhs.key < rhs.key
        }) where !name.isEmpty {
            queryItems.append(URLQueryItem(name: name, value: value))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url ?? baseURL
    }
}

private extension URL {
    func appendingEndpointPath(_ path: String) -> URL {
        let sanitizedPath = path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard !sanitizedPath.isEmpty,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        let existingPath = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        components.percentEncodedPath = "/" + (existingPath + sanitizedPath).joined(separator: "/")

        return components.url ?? self
    }
}
