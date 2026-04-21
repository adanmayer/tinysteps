import Foundation
import MBAPI

enum MBMockDataPreviewFactory {
    private static let fileManager = FileManager.default

    static func replayClient(filePath: String = #filePath) -> any MBClient {
        MBMockClient(
            demoDataStore: MBAPIDemoDataStore(
                mode: .replay,
                snapshotsDirectoryURL: snapshotsDirectoryURL(filePath: filePath)
            )
        )
    }

    static func snapshotsDirectoryURL(filePath: String) -> URL? {
        guard let overridePath = resolveOverridePath() else {
            return resolvedProjectFixturesDirectory(filePath: filePath)
        }
        return URL(fileURLWithPath: overridePath)
    }

    private static func resolveOverridePath() -> String? {
        let overrideCandidates = [
            "MOBILEMANAGEBAC_DEMO_DATA_DIR",
            "MOBILEMANAGEBAC_DEMO_DATA_PATH",
            "MOBILEMANAGEBAC_MOCK_DATA_DIR"
        ]

        for key in overrideCandidates {
            if let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private static func resolvedProjectFixturesDirectory(filePath: String) -> URL? {
        let fileBasedCandidates = [
            filePath,
            ProcessInfo.processInfo.environment["PROJECT_DIR"],
            ProcessInfo.processInfo.environment["SRCROOT"],
            ProcessInfo.processInfo.environment["PWD"],
            ProcessInfo.processInfo.environment["WORKSPACE_DIR"]
        ]

        for candidate in fileBasedCandidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !candidate.isEmpty {
            let resolved = findMockDataDirectory(startingAt: candidate)
            if let resolved {
                return resolved
            }
        }

        return nil
    }

    private static func findMockDataDirectory(startingAt startPath: String) -> URL? {
        var cursor = URL(fileURLWithPath: startPath)
        if cursor.pathExtension == "swift" {
            cursor = cursor.deletingLastPathComponent()
        }

        for _ in 0..<12 {
            let candidate = cursor
                .appending(path: "MobileManageBacUITests", directoryHint: .isDirectory)
                .appending(path: "MockData", directoryHint: .isDirectory)

            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            if fileManager.fileExists(atPath: cursor.appending(path: "MobileManageBac.xcodeproj").path) {
                let fromProject = cursor
                    .appending(path: "MobileManageBacUITests", directoryHint: .isDirectory)
                    .appending(path: "MockData", directoryHint: .isDirectory)

                if fileManager.fileExists(atPath: fromProject.path) {
                    return fromProject
                }
            }

            let parent = cursor.deletingLastPathComponent()
            if parent == cursor {
                break
            }
            cursor = parent
        }

        return nil
    }
}
