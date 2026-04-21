import Foundation
import OSLog
import SwiftData

enum FaceIDModelContainer {
    private static let log = Logger(subsystem: "co.Faria.MobileManageBac", category: "FaceID")

    static let requiredEmbeddingCount = 3
    static let requiredVectorLength = 64
    static let requiredModelIdentifier = "com.fariasystems.faceid.vnFeaturePrint"

    @MainActor
    static func make() throws -> ModelContainer {
        let schema = Schema([EnrolledIdentity.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        applyFileProtection(to: configuration.url)
        return container
    }

    @MainActor
    static func applyFileProtection(to storeURL: URL) {
        let fileManager = FileManager.default
        let storeFiles = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        for url in storeFiles {
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }

            do {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            } catch {
                log.error("Failed to apply file protection: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
