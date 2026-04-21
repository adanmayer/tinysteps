import Foundation

extension URL {
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
