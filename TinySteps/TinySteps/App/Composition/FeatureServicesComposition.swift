import Foundation
import MBAPI
import os

struct FeatureServicesComposition {
    let accountService: AccountService
    let childrenService: ChildrenService
    let classesService: ClassesService
    let filesService: FilesService
    let parentAssociationService: ParentAssociationService
    let portfolioService: PortfolioService
    let faceEnrollmentStore: FaceEnrollmentStore
    private static let demoDataLogger = Logger(
        subsystem: "co.Faria.MobileManageBac",
        category: "FeatureServicesComposition"
    )

    static func live(
        credentialsProvider: MBAPICredentialsProvider,
        demoDataMode: MBAPIDemoDataMode = .off
    ) -> FeatureServicesComposition {
        let effectiveCredentialsProvider: MBAPICredentialsProvider = demoDataMode == .replay
            ? DemoMBAPICredentialsProvider()
            : credentialsProvider
        let snapshotsDirectoryURL = resolveDemoDataSnapshotsDirectory()

        let demoDataStore = MBAPIDemoDataStore(
            mode: demoDataMode,
            snapshotsDirectoryURL: snapshotsDirectoryURL
        )

        let client: any MBClient = {
            switch demoDataMode {
            case .replay:
                demoDataLogger.info("Using MBMockClient for replay mode.")
                return MBMockClient(demoDataStore: demoDataStore)
            case .capture, .off:
                return MBLiveClient(demoDataStore: demoDataStore)
            }
        }()

        if let snapshotsDirectoryURL {
            demoDataLogger.info("Demo snapshots directory: \(snapshotsDirectoryURL.absoluteString, privacy: .public)")
        }

        let faceEnrollmentStore: FaceEnrollmentStore = {
            if let store = try? SwiftDataFaceEnrollmentStore() {
                return store
            }
            return FaceEnrollmentStoreUnavailable()
        }()

        return FeatureServicesComposition(
            accountService: MBAccountService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            childrenService: MBChildrenService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            classesService: MBClassesService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            filesService: MBFilesService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            parentAssociationService: MBParentAssociationService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            portfolioService: MBPortfolioService(
                credentialsProvider: effectiveCredentialsProvider,
                client: client
            ),
            faceEnrollmentStore: faceEnrollmentStore
        )
    }

    private static func resolveDemoDataSnapshotsDirectory() -> URL? {
        let overrideCandidates = [
            "MOBILEMANAGEBAC_DEMO_DATA_DIR",
            "MOBILEMANAGEBAC_DEMO_DATA_PATH"
        ]
        guard let overridePath = overrideCandidates.compactMap({ ProcessInfo.processInfo.environment[$0] }).first(where: { !$0.isEmpty }) else {
            return nil
        }

        let trimmedPath = overridePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }

        demoDataLogger.info("Using override demo snapshot directory from env: \(trimmedPath, privacy: .public)")
        return URL(fileURLWithPath: trimmedPath)
    }
}
