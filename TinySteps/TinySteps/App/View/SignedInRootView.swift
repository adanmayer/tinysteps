import SwiftUI
import MBAPI

struct SignedInRootView: View {
    @State private var sessionModel: SignedInSessionModel
    @State private var isShowingChildSwitcher = false
    @State private var isShowingClassSwitcher = false
    @State private var isShowingSignOutConfirmation = false

    private let parentAssociationService: ParentAssociationService
    private let portfolioService: PortfolioService
    private let classesService: ClassesService
    private let faceEnrollmentStore: FaceEnrollmentStore
    private let faceCaptureDraftStore: FaceCaptureDraftStore
    private let observationDraftStore: ObservationCaptureDraftStore
    private let observationDraftPublisher: ObservationDraftPublishing
    private let observationTaggingService: ObservationTaggingService
    private let standardsLoadingService: MBStandardsLoadingService
    private let observationSpeechTranscriber: ObservationSpeechTranscribing
    private let observationChildMatcher: ObservationChildNameMatching
    private let onSignOut: () -> Void

    init(
        session: AuthSession,
        dependencies: AppDependencies,
        onSignOut: @escaping () -> Void
    ) {
        _sessionModel = State(
            initialValue: SignedInSessionModel(
                session: session,
                authController: dependencies.authController,
                accountService: dependencies.accountService,
                childrenService: dependencies.childrenService,
                classesService: dependencies.classesService,
                childSelectionStore: dependencies.childSelectionStore,
                classSelectionStore: dependencies.classSelectionStore
            )
        )
        self.parentAssociationService = dependencies.parentAssociationService
        self.portfolioService = dependencies.portfolioService
        self.classesService = dependencies.classesService
        self.faceEnrollmentStore = dependencies.faceEnrollmentStore
        self.faceCaptureDraftStore = dependencies.faceCaptureDraftStore
        self.observationDraftStore = dependencies.observationDraftStore
        self.observationDraftPublisher = dependencies.observationDraftPublisher
        self.observationTaggingService = dependencies.observationTaggingService
        self.standardsLoadingService = dependencies.standardsLoadingService
        self.observationSpeechTranscriber = dependencies.observationSpeechTranscriber
        self.observationChildMatcher = dependencies.observationChildMatcher
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessionModel.isLoading {
                    ProgressView(loadingLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = sessionModel.errorMessage {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: "person.2.slash",
                            description: Text(errorMessage)
                        )

                        Button("Log Out", role: .destructive) {
                            isShowingSignOutConfirmation = true
                        }
                    }
                } else {
                    switch sessionModel.resolvedRole ?? .parent {
                    case .parent:
                        ParentHomeView(
                            session: sessionModel.session,
                            childContext: sessionModel.selectedChildContext,
                            selectedContextTitle: sessionModel.selectedChildTitle,
                            selectedContextSubtitle: sessionModel.selectedChildSubtitle,
                            canShowChildSwitcher: sessionModel.canShowChildSwitcher,
                            availableChildren: sessionModel.availableChildren,
                            portfolioService: portfolioService,
                            classesService: classesService,
                            onShowChildSwitcher: { isShowingChildSwitcher = true },
                            onSignOut: { isShowingSignOutConfirmation = true },
                            parentAssociationService: parentAssociationService
                        )
                    case .teacher, .advisor, .student:
                        TeacherHomeView(
                            session: sessionModel.session,
                            classContext: sessionModel.selectedClassContext,
                            selectedClass: sessionModel.selectedClass,
                            selectedContextTitle: sessionModel.selectedClassTitle,
                            selectedContextSubtitle: sessionModel.selectedClassSubtitle,
                            canShowClassSwitcher: sessionModel.canShowClassSwitcher,
                            classesService: classesService,
                            portfolioService: portfolioService,
                            faceEnrollmentStore: faceEnrollmentStore,
                            faceCaptureDraftStore: faceCaptureDraftStore,
                            observationDraftStore: observationDraftStore,
                            observationDraftPublisher: observationDraftPublisher,
                            observationTaggingService: observationTaggingService,
                            standardsLoadingService: standardsLoadingService,
                            observationSpeechTranscriber: observationSpeechTranscriber,
                            observationChildMatcher: observationChildMatcher,
                            onShowClassSwitcher: {
                                isShowingClassSwitcher = true
                            },
                            onSignOut: { isShowingSignOutConfirmation = true }
                        )
                    }
                }
            }
            .navigationTitle(showsRootNavigationChrome ? "Home" : "")
            .toolbar(showsRootNavigationChrome ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                if showsRootNavigationChrome {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Log Out", role: .destructive) {
                            isShowingSignOutConfirmation = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingChildSwitcher) {
                ChildSwitcherView(
                    options: sessionModel.childSwitcherOptions,
                    onSelect: sessionModel.selectChild
                )
            }
            .sheet(isPresented: $isShowingClassSwitcher) {
                ClassSwitcherView(
                    options: sessionModel.classSwitcherOptions,
                    onSelect: sessionModel.selectClass
                )
            }
            .confirmationDialog(
                "Log out of this session?",
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive, action: onSignOut)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to sign in again to access your dashboard.")
            }
        }
        .task {
            await sessionModel.loadIfNeeded()
        }
    }

    private var loadingLabel: String {
        switch sessionModel.resolvedRole {
        case .teacher, .advisor, .student:
            return "Loading classes…"
        case .parent, .none:
            return "Loading children…"
        }
    }

    private var emptyTitle: String {
        switch sessionModel.resolvedRole {
        case .teacher, .advisor, .student:
            return "Unable to load classes"
        case .parent, .none:
            return "Unable to load children"
        }
    }

    private var showsRootNavigationChrome: Bool {
        switch sessionModel.resolvedRole {
        case .teacher, .advisor, .student:
            return false
        case .parent, .none:
            return true
        }
    }
}
