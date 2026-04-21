import SwiftUI

struct AuthView: View {
    let viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign In")
                        .font(.largeTitle.weight(.semibold))
                    Text("Start the OAuth2 sign-in flow. The active school host is returned by the server during authentication.")
                        .foregroundStyle(.secondary)
                }

                if let lastConnectedHost = viewModel.lastConnectedHost {
                    Text("Last connected school: \(lastConnectedHost)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    viewModel.signIn()
                } label: {
                    HStack {
                        if viewModel.isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isAuthenticating ? "Signing In…" : "Continue with OAuth2")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAuthenticating)
                .accessibilityLabel("Continue with OAuth2")

                Spacer()
            }
            .padding(24)
            .navigationTitle("Sign In")
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel(authController: AppDependencies.live().authController))
}
