import Foundation
import Observation

@Observable
@MainActor
final class AppNavigationState {
    private(set) var shouldShowOnboarding = false

    func handleIncomingURL(_ url: URL) -> Bool {
        let _ = url
        return false
    }

    func queueOnboarding() {
        shouldShowOnboarding = true
    }

    func consumeOnboarding() -> Bool {
        defer { shouldShowOnboarding = false }
        return shouldShowOnboarding
    }

    func resetForSignedOutState() {
        shouldShowOnboarding = false
    }
}
