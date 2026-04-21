import SwiftUI
import MBAPI

struct SignedInRootView: View {
    @State private var sessionModel: SignedInSessionModel
    @State private var isShowingChildSwitcher = false
    @State private var isShowingClassSwitcher = false
    @State private var isShowingSignOutConfirmation = false

    private let parentAssociationService: ParentAssociationService
    private let classesService: ClassesService
    private let faceEnrollmentStore: FaceEnrollmentStore
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
                childrenService: dependencies.childrenService,
                classesService: dependencies.classesService,
                childSelectionStore: dependencies.childSelectionStore,
                classSelectionStore: dependencies.classSelectionStore
            )
        )
        self.parentAssociationService = dependencies.parentAssociationService
        self.classesService = dependencies.classesService
        self.faceEnrollmentStore = dependencies.faceEnrollmentStore
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessionModel.isLoading {
                    ProgressView(loadingLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = sessionModel.errorMessage {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "person.2.slash",
                        description: Text(errorMessage)
                    )
                } else {
                    switch sessionModel.resolvedRole ?? .parent {
                    case .parent:
                        ParentHomeView(
                            session: sessionModel.session,
                            childContext: sessionModel.selectedChildContext,
                            selectedContextTitle: sessionModel.selectedChildTitle,
                            selectedContextSubtitle: sessionModel.selectedChildSubtitle,
                            canShowChildSwitcher: sessionModel.canShowChildSwitcher,
                            onShowChildSwitcher: { isShowingChildSwitcher = true },
                            onSignOut: { isShowingSignOutConfirmation = true },
                            parentAssociationService: parentAssociationService
                        )
                    case .teacher, .student:
                        TeacherHomeView(
                            session: sessionModel.session,
                            classContext: sessionModel.selectedClassContext,
                            selectedClass: sessionModel.selectedClass,
                            selectedContextTitle: sessionModel.selectedClassTitle,
                            selectedContextSubtitle: sessionModel.selectedClassSubtitle,
                            canShowClassSwitcher: sessionModel.canShowClassSwitcher,
                            classesService: classesService,
                            faceEnrollmentStore: faceEnrollmentStore,
                            onShowClassSwitcher: { isShowingClassSwitcher = true },
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
        case .teacher, .student:
            return "Loading classes…"
        case .parent, .none:
            return "Loading children…"
        }
    }

    private var emptyTitle: String {
        switch sessionModel.resolvedRole {
        case .teacher, .student:
            return "Unable to load classes"
        case .parent, .none:
            return "Unable to load children"
        }
    }

    private var showsRootNavigationChrome: Bool {
        switch sessionModel.resolvedRole {
        case .teacher, .student:
            return false
        case .parent, .none:
            return true
        }
    }
}
