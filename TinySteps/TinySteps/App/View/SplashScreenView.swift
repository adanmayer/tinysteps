import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Image("Splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.08), location: 0.0),
                    .init(color: .black.opacity(0.18), location: 0.52),
                    .init(color: .black.opacity(0.52), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text("TinySteps")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }

                    SplashLoadingIndicator()

                    Text("Preparing your day")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 74)
                .shadow(color: .black.opacity(0.22), radius: 24, y: 14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading TinySteps")
    }
}

private struct SplashLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.55)
                    .opacity(isAnimating ? 1.0 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.72)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
}
