import Foundation
import os

public enum MBAPIDemoDataMode: String, Sendable {
    case off
    case capture
    case replay

    var isCaptureEnabled: Bool { self == .capture }
    var isReplayEnabled: Bool { self == .replay }
}

public actor MBAPIDemoDataStore {
    private let fileManager: FileManager
    private let snapshotsDirectoryURL: URL
    private let currentMode: MBAPIDemoDataMode
    private let maxStoredSnapshots: Int
    private let maxBodyBytes: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(
        subsystem: "co.Faria.MobileManageBac.MBAPI",
        category: "MBAPIDemoDataStore"
    )

    public init(
        mode: MBAPIDemoDataMode,
        fileManager: FileManager = .default,
        snapshotsDirectoryURL: URL? = nil,
        maxStoredSnapshots: Int = 200,
        maxBodyBytes: Int = 200_000
    ) {
        self.fileManager = fileManager
        self.currentMode = mode
        self.snapshotsDirectoryURL = snapshotsDirectoryURL ?? Self.defaultSnapshotsDirectoryURL(using: fileManager)
        self.maxStoredSnapshots = maxStoredSnapshots
        self.maxBodyBytes = maxBodyBytes

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public var mode: MBAPIDemoDataMode { currentMode }
    public var isCapturing: Bool { currentMode.isCaptureEnabled }
    public var isReplaying: Bool { currentMode.isReplayEnabled }

    public func snapshotData(for requestURL: URL, responseType: String) async -> Data? {
        guard isReplaying else {
            return nil
        }

        let snapshotURL = fileURL(for: requestURL, responseType: responseType)
        let isReachable = (try? snapshotURL.checkResourceIsReachable()) == true
        guard isReachable else {
            return nil
        }

        do {
            let storedData = try Data(contentsOf: snapshotURL)
            let storedSnapshot = try decoder.decode(StoredDemoSnapshot.self, from: storedData)
            return storedSnapshot.responseBody(for: responseType)
        } catch {
            logger.error("Failed to load demo snapshot \(snapshotURL.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func storeSnapshot(
        _ responseData: Data,
        for requestURL: URL,
        responseType: String,
        endpointPath: String,
        statusCode: Int?,
        contentType: String?,
        context: MBSessionContext
    ) async {
        guard isCapturing else {
            return
        }

        do {
            let snapshotURL = fileURL(for: requestURL, responseType: responseType)
            try fileManager.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try pruneIfNeeded()

            let snapshot = StoredDemoSnapshot(
                timestamp: Self.timestampFormatter.string(from: Date()),
                endpointPath: endpointPath,
                requestURL: requestURL.absoluteString,
                role: context.role.rawValue,
                childID: context.childID,
                responseType: responseType,
                statusCode: statusCode,
                contentType: contentType,
                responseBody: responseData,
                maxBodyBytes: maxBodyBytes
            )

            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
            logger.info("Demo snapshot written to \(snapshotURL.absoluteString, privacy: .public)")
        } catch {
            logger.error("Failed to store demo snapshot for \(requestURL.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(for requestURL: URL, responseType: String) -> URL {
        let queryKey = queryKey(for: requestURL)
        let endpointSegments = endpointPathComponents(for: requestURL)
        let responseTypeDirectory = responseTypeDirectoryName(for: responseType)

        var snapshotURL = snapshotsDirectoryURL
            .appending(path: "GET", directoryHint: .isDirectory)

        for segment in endpointSegments {
            snapshotURL = snapshotURL.appending(path: segment, directoryHint: .isDirectory)
        }

        snapshotURL = snapshotURL
            .appending(path: responseTypeDirectory, directoryHint: .isDirectory)
            .appending(path: "q-\(queryKey)", directoryHint: .notDirectory)

        return snapshotURL.appendingPathExtension("json")
    }

    private func pruneIfNeeded() throws {
        guard maxStoredSnapshots > 0 else {
            return
        }

        let existingFiles = snapshotsDirectoryURL
            .snapshotFiles(fileManager: fileManager)
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }

        guard existingFiles.count >= maxStoredSnapshots else {
            return
        }

        let filesToDelete = existingFiles.prefix(existingFiles.count - maxStoredSnapshots + 1)
        for fileURL in filesToDelete {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func queryKey(for requestURL: URL) -> String {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return "default"
        }

        let normalizedQuery = queryItems
            .filter { !$0.name.isEmpty }
            .sorted {
                if $0.name == $1.name {
                    return ($0.value ?? "") < ($1.value ?? "")
                }
                return $0.name < $1.name
            }
            .map { item in
                let value = item.value ?? ""
                return "\(item.name)=\(value)"
            }
            .joined(separator: "&")

        guard !normalizedQuery.isEmpty else {
            return "default"
        }

        let safeQuery = normalizedQuery.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "-._="))
        ) ?? normalizedQuery.fnv1a64Hex

        return safeQuery.count > 160 ? String(safeQuery.fnv1a64Hex.prefix(16)) : safeQuery
    }

    private func endpointPathComponents(for requestURL: URL) -> [String] {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
            return ["unresolved"]
        }

        let allSegments = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        var segments = allSegments
        if segments.count >= 2,
           segments[0] == "api",
           segments[1] == "mobile" {
            segments.removeFirst(2)
        }

        let safeSegments = segments.map { segment in
            sanitizePathSegment(segment.isEmpty ? "empty" : segment)
        }

        return safeSegments.isEmpty ? ["root"] : safeSegments
    }

    private func sanitizePathSegment(_ segment: String) -> String {
        let safe = segment
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._")))
        return safe?.isEmpty == false ? safe! : "segment"
    }

    private func responseTypeDirectoryName(for responseType: String) -> String {
        guard let responseTypeComponents = responseType.split(separator: ".").last else {
            return "Response"
        }
        return String(responseTypeComponents)
    }

    private static func defaultSnapshotsDirectoryURL(using fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return baseURL
            .appending(path: "MobileManageBac", directoryHint: .isDirectory)
            .appending(path: "DemoData", directoryHint: .isDirectory)
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

private extension URL {
    func snapshotFiles(fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: self,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let fileURL = item as? URL,
                  fileURL.pathExtension == "json",
                  (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else {
                return nil
            }
            return fileURL
        }
    }
}

private extension String {
    var fnv1a64Hex: String {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}

private struct StoredDemoSnapshot: Codable {
    let timestamp: String
    let endpointPath: String
    let requestURL: String
    let role: String
    let childID: String?
    let responseType: String
    let statusCode: Int?
    let contentType: String?
    let responseBodyEncoding: String
    let responseBody: String

    init(
        timestamp: String,
        endpointPath: String,
        requestURL: String,
        role: String,
        childID: String?,
        responseType: String,
        statusCode: Int?,
        contentType: String?,
        responseBody: Data,
        maxBodyBytes: Int
    ) {
        self.timestamp = timestamp
        self.endpointPath = endpointPath
        self.requestURL = requestURL
        self.role = role
        self.childID = childID
        self.responseType = responseType
        self.statusCode = statusCode
        self.contentType = contentType

        let truncatedBody = responseBody.count > maxBodyBytes
            ? responseBody.prefix(maxBodyBytes)
            : responseBody.prefix(responseBody.count)

        if let responseBodyString = String(data: Data(truncatedBody), encoding: .utf8) {
            responseBodyEncoding = "utf8"
            self.responseBody = responseBodyString
        } else {
            responseBodyEncoding = "base64"
            self.responseBody = Data(truncatedBody).base64EncodedString()
        }
    }

    func responseBody(for responseType: String) -> Data? {
        guard responseType == self.responseType else {
            return nil
        }

        if responseBodyEncoding == "base64" {
            return Data(base64Encoded: responseBody)
        }
        return responseBody.data(using: .utf8)
    }
}
