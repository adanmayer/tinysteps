import Foundation

public enum MBMockClientError: LocalizedError, Equatable, Sendable {
    case fixtureNotFound(endpointPath: String, responseType: String, requestURL: String)
    case malformedSnapshotData(endpointPath: String, responseType: String, requestURL: String, reason: String)
    case decodingFailed(endpointPath: String, responseType: String, requestURL: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .fixtureNotFound(let endpointPath, let responseType, let requestURL):
            "No mock fixture found for endpoint `\(endpointPath)` and response type `\(responseType)` at `\(requestURL)`."
        case .malformedSnapshotData(let endpointPath, let responseType, let requestURL, let reason):
            "Mock fixture for endpoint `\(endpointPath)` and response type `\(responseType)` has malformed payload at `\(requestURL)`: \(reason)"
        case .decodingFailed(let endpointPath, let responseType, let requestURL, let reason):
            "Failed to decode mock fixture for endpoint `\(endpointPath)` and response type `\(responseType)` at `\(requestURL)`: \(reason)"
        }
    }
}
