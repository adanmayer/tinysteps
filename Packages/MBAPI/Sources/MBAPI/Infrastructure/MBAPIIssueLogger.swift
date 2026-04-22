import Foundation
import os

actor MBAPIIssueLogger {
    private let fileManager: FileManager
    private let logsDirectoryURL: URL
    private let maxStoredEntries: Int
    private let maxBodyBytes: Int
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "co.Faria.MobileManageBac.MBAPI", category: "MBAPIIssueLogger")

    init(
        fileManager: FileManager = .default,
        logsDirectoryURL: URL? = nil,
        maxStoredEntries: Int = 50,
        maxBodyBytes: Int = 200_000
    ) {
        self.fileManager = fileManager
        self.logsDirectoryURL = logsDirectoryURL ?? Self.defaultLogsDirectoryURL(using: fileManager)
        self.maxStoredEntries = maxStoredEntries
        self.maxBodyBytes = maxBodyBytes

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func log(_ issue: MBAPIIssue) async {
        do {
            try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            try pruneIfNeeded()

            let logEntry = StoredIssue(issue: issue, maxBodyBytes: maxBodyBytes)
            let fileURL = logsDirectoryURL.appending(path: fileName(for: issue), directoryHint: .notDirectory)
            let data = try encoder.encode(logEntry)
            try data.write(to: fileURL, options: .atomic)

            logger.info("API issue log written to \(fileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to write API issue log: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pruneIfNeeded() throws {
        guard maxStoredEntries > 0 else {
            return
        }

        let existingFiles = try fileManager.contentsOfDirectory(
            at: logsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        guard existingFiles.count >= maxStoredEntries else {
            return
        }

        let sortedFiles = try existingFiles.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate < rhsDate
        }

        let filesToDelete = sortedFiles.prefix(sortedFiles.count - maxStoredEntries + 1)
        for fileURL in filesToDelete {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func fileName(for issue: MBAPIIssue) -> String {
        "\(Self.timestampFormatter.string(from: issue.timestamp))-\(issue.kind.rawValue)-\(UUID().uuidString).json"
    }

    private static func defaultLogsDirectoryURL(using fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return baseURL
            .appending(path: "MobileManageBac", directoryHint: .isDirectory)
            .appending(path: "APIIssueLogs", directoryHint: .isDirectory)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }()
}

struct MBAPIIssue: Sendable {
    enum Kind: String, Codable, Sendable {
        case transportError
        case invalidResponse
        case unexpectedStatusCode
        case decodingFailed
    }

    let timestamp: Date
    let kind: Kind
    let method: String
    let endpointPath: String
    let requestURL: URL
    let role: String
    let childID: String?
    let responseType: String?
    let statusCode: Int?
    let contentType: String?
    let errorDescription: String
    let responseBody: Data?

    init(
        timestamp: Date = Date(),
        kind: Kind,
        method: String,
        endpointPath: String,
        requestURL: URL,
        role: String,
        childID: String?,
        responseType: String? = nil,
        statusCode: Int? = nil,
        contentType: String? = nil,
        errorDescription: String,
        responseBody: Data? = nil
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.method = method
        self.endpointPath = endpointPath
        self.requestURL = requestURL
        self.role = role
        self.childID = childID
        self.responseType = responseType
        self.statusCode = statusCode
        self.contentType = contentType
        self.errorDescription = errorDescription
        self.responseBody = responseBody
    }
}

private struct StoredIssue: Codable {
    let timestamp: String
    let kind: String
    let method: String
    let endpointPath: String
    let requestURL: String
    let role: String
    let childID: String?
    let responseType: String?
    let statusCode: Int?
    let contentType: String?
    let errorDescription: String
    let responseBodyEncoding: String?
    let responseBody: String?
    let responseBodyWasTruncated: Bool

    init(issue: MBAPIIssue, maxBodyBytes: Int) {
        timestamp = ISO8601DateFormatter().string(from: issue.timestamp)
        kind = issue.kind.rawValue
        method = issue.method
        endpointPath = issue.endpointPath
        requestURL = issue.requestURL.absoluteString
        role = issue.role
        childID = issue.childID
        responseType = issue.responseType
        statusCode = issue.statusCode
        contentType = issue.contentType
        errorDescription = issue.errorDescription

        guard let responseBody = issue.responseBody, !responseBody.isEmpty else {
            responseBodyEncoding = nil
            self.responseBody = nil
            responseBodyWasTruncated = false
            return
        }

        let truncatedBody = responseBody.count > maxBodyBytes
            ? responseBody.prefix(maxBodyBytes)
            : responseBody.prefix(responseBody.count)
        let bodyData = Data(truncatedBody)
        responseBodyWasTruncated = responseBody.count > maxBodyBytes

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            responseBodyEncoding = "utf8"
            self.responseBody = bodyString
        } else {
            responseBodyEncoding = "base64"
            self.responseBody = bodyData.base64EncodedString()
        }
    }
}
