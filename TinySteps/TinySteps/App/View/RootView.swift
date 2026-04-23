import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies
    @State private var authViewModel: AuthViewModel
    @State private var flowModel: AppShellModel
    @State private var loadedSignedInScopeID: String?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let navigationState = AppNavigationState()

        _authViewModel = State(initialValue: AuthViewModel(authController: dependencies.authController))
        _flowModel = State(initialValue: AppShellModel(
            authController: dependencies.authController,
            navigationState: navigationState
        ))
    }

    var body: some View {
        ZStack {
            rootContent

            if shouldShowSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.65), value: shouldShowSplash)
        .task {
            flowModel.start()
        }
        .task(id: currentSignedInScopeID) {
            if currentSignedInScopeID == nil {
                loadedSignedInScopeID = nil
            }
        }
        .onOpenURL { url in
            _ = flowModel.handleIncomingURL(url)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        Group {
            switch flowModel.flow {
            case .launching:
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut, .authenticating, .authFailure, .expiredSession:
                AuthView(viewModel: authViewModel)
            case .signedIn(let session):
                SignedInRootView(
                    session: session,
                    dependencies: dependencies,
                    onInitialLoadCompleted: {
                        loadedSignedInScopeID = session.signedInScopeID
                    },
                    onSignOut: {
                        Task {
                            await dependencies.standardsLoadingService.clearCache()
                            flowModel.signOut()
                        }
                    }
                )
                .id(session.signedInScopeID)
            case .blockingError(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Unable to continue")
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var shouldShowSplash: Bool {
        if flowModel.hasCompletedInitialRestore == false {
            return true
        }

        switch flowModel.flow {
        case .signedIn(let session):
            return loadedSignedInScopeID != session.signedInScopeID
        case .launching:
            return true
        case .signedOut, .authenticating, .authFailure, .expiredSession, .blockingError:
            return false
        }
    }

    private var currentSignedInScopeID: String? {
        switch flowModel.flow {
        case .signedIn(let session):
            return session.signedInScopeID
        case .launching, .signedOut, .authenticating, .authFailure, .expiredSession, .blockingError:
            return nil
        }
    }
}

#Preview {
    RootView(dependencies: .live())
}
