import Foundation
import MBAPI
import os

@MainActor
final class AppDependencies {
    private static let demoDataModeLogger = Logger(
        subsystem: "co.Faria.MobileManageBac",
        category: "DemoDataMode"
    )

    let authController: AuthController
    let accountService: AccountService
    let childrenService: ChildrenService
    let classesService: ClassesService
    let filesService: FilesService
    let parentAssociationService: ParentAssociationService
    let portfolioService: PortfolioService
    let faceEnrollmentStore: FaceEnrollmentStore
    let faceCaptureDraftStore: FaceCaptureDraftStore
    let childSelectionStore: ChildSelectionStore
    let classSelectionStore: ClassSelectionStore

    init(
        authController: AuthController,
        accountService: AccountService,
        childrenService: ChildrenService,
        classesService: ClassesService,
        filesService: FilesService,
        parentAssociationService: ParentAssociationService,
        portfolioService: PortfolioService,
        faceEnrollmentStore: FaceEnrollmentStore,
        faceCaptureDraftStore: FaceCaptureDraftStore,
        childSelectionStore: ChildSelectionStore,
        classSelectionStore: ClassSelectionStore
    ) {
        self.authController = authController
        self.accountService = accountService
        self.childrenService = childrenService
        self.classesService = classesService
        self.filesService = filesService
        self.parentAssociationService = parentAssociationService
        self.portfolioService = portfolioService
        self.faceEnrollmentStore = faceEnrollmentStore
        self.faceCaptureDraftStore = faceCaptureDraftStore
        self.childSelectionStore = childSelectionStore
        self.classSelectionStore = classSelectionStore
    }

    static func live() -> AppDependencies {
        let demoDataMode = resolveDemoDataMode()
        demoDataModeLogger.info("Demo data mode: \(demoDataMode.rawValue, privacy: .public)")

        return live(demoDataMode: demoDataMode)
    }

    static func live(demoDataMode: MBAPIDemoDataMode) -> AppDependencies {
        let auth = AuthComposition.live()
        let session = SessionComposition.live()
        let features = FeatureServicesComposition.live(
            credentialsProvider: auth.credentialsProvider,
            demoDataMode: demoDataMode
        )

        let faceCaptureDraftStore: FaceCaptureDraftStore = InMemoryFaceCaptureDraftStore()

        return AppDependencies(
            authController: auth.authController,
            accountService: features.accountService,
            childrenService: features.childrenService,
            classesService: features.classesService,
            filesService: features.filesService,
            parentAssociationService: features.parentAssociationService,
            portfolioService: features.portfolioService,
            faceEnrollmentStore: features.faceEnrollmentStore,
            faceCaptureDraftStore: faceCaptureDraftStore,
            childSelectionStore: session.childSelectionStore,
            classSelectionStore: session.classSelectionStore
        )
    }

    private static func resolveDemoDataMode() -> MBAPIDemoDataMode {
        #if !DEBUG
        demoDataModeLogger.info("Demo data mode is disabled outside DEBUG builds.")
        return .off
        #endif

        if ProcessInfo.processInfo.arguments.contains("--demoDataReplay")
            || ProcessInfo.processInfo.arguments.contains("-demoDataReplay") {
            return .replay
        }

        if ProcessInfo.processInfo.arguments.contains("--demoDataCapture")
            || ProcessInfo.processInfo.arguments.contains("-demoDataCapture") {
            return .capture
        }

        guard let envMode = ProcessInfo.processInfo.environment["MOBILEMANAGEBAC_DEMO_DATA_MODE"]?.lowercased() else {
            return .off
        }

        switch envMode {
        case "capture", "record":
            return .capture
        case "replay", "mock":
            return .replay
        default:
            return .off
        }
    }
}
