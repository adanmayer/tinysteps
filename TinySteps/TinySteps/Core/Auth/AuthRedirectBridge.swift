import Foundation

final class AuthRedirectBridge {
    static let shared = AuthRedirectBridge()

    var handler: ((URL) -> Bool)?

    private init() {}

    func handle(_ url: URL) -> Bool {
        handler?(url) ?? false
    }
}