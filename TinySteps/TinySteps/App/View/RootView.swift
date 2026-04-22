import SwiftUI

struct RootView: View {
    private let dependencies: AppDependencies
    @State private var authViewModel: AuthViewModel
    @State private var flowModel: AppShellModel

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
        Group {
            switch flowModel.flow {
            case .launching:
                ProgressView("Restoring session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut, .authenticating, .authFailure, .expiredSession:
                AuthView(viewModel: authViewModel)
            case .signedIn(let session):
                SignedInRootView(
                    session: session,
                    dependencies: dependencies,
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
        .task {
            flowModel.start()
        }
        .onOpenURL { url in
            _ = flowModel.handleIncomingURL(url)
        }
    }
}

#Preview {
    RootView(dependencies: .live())
}
