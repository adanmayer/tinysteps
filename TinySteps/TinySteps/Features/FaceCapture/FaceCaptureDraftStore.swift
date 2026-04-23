import Foundation

protocol FaceCaptureDraftStore: Sendable {
    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID
    func loadDrafts(forClassID classID: String) async throws -> [FaceCaptureDraft]
    func deleteDraft(id: FaceCaptureDraft.ID) async throws
}

actor FileFaceCaptureDraftStore: FaceCaptureDraftStore {
    private let directoryURL: URL
    private let retentionDays: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURL: URL? = nil,
        retentionDays: Int = 30
    ) {
        self.directoryURL = directoryURL ?? FileFaceCaptureDraftStore.defaultDirectoryURL()
        self.retentionDays = retentionDays

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID {
        try prepareDirectory()
        try cleanupExpiredDrafts(now: draft.capturedAt)

        let data = try encoder.encode(draft)
        let fileURL = url(for: draft.id)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        try protectItem(at: fileURL)

        return draft.id
    }

    func loadDrafts(forClassID classID: String) async throws -> [FaceCaptureDraft] {
        try prepareDirectory()
        try cleanupExpiredDrafts(now: .now)

        return try draftFileURLs().compactMap { fileURL in
            let data = try Data(contentsOf: fileURL)
            let draft = try decoder.decode(FaceCaptureDraft.self, from: data)
            return draft.classID == classID ? draft : nil
        }
        .sorted { $0.capturedAt < $1.capturedAt }
    }

    func deleteDraft(id: FaceCaptureDraft.ID) async throws {
        let fileURL = url(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    private static func defaultDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return baseURL
            .appendingPathComponent("FaceCapture", isDirectory: true)
            .appendingPathComponent("Drafts", isDirectory: true)
    }

    private func prepareDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try protectItem(at: directoryURL)
    }

    private func protectItem(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    private func url(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func draftFileURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
    }

    private func cleanupExpiredDrafts(now: Date) throws {
        guard retentionDays > 0 else {
            return
        }

        let expirationInterval = TimeInterval(retentionDays * 24 * 60 * 60)
        for fileURL in try draftFileURLs() {
            guard
                let data = try? Data(contentsOf: fileURL),
                let draft = try? decoder.decode(FaceCaptureDraft.self, from: data),
                now.timeIntervalSince(draft.capturedAt) > expirationInterval
            else {
                continue
            }

            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

actor InMemoryFaceCaptureDraftStore: FaceCaptureDraftStore {
    private var drafts: [FaceCaptureDraft.ID: FaceCaptureDraft] = [:]

    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID {
        drafts[draft.id] = draft
        return draft.id
    }

    func loadDrafts(forClassID classID: String) async throws -> [FaceCaptureDraft] {
        drafts.values
            .filter { $0.classID == classID }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func deleteDraft(id: FaceCaptureDraft.ID) async throws {
        drafts.removeValue(forKey: id)
    }

    func allDraftIDs() -> [FaceCaptureDraft.ID] {
        Array(drafts.keys)
    }
}
