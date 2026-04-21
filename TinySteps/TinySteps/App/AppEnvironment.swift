import Foundation

struct AppEnvironment: Sendable {
    let apiBaseURL: URL
    let oauth: OAuthEnvironment

    static let live = AppEnvironment(
        apiBaseURL: URL(string: "https://api.managebac.com")!,
        oauth: .manageBac
    )
}

struct OAuthEnvironment: Sendable {
    let clientID: String
    let scopes: [String]
    let loginRedirectURL: URL
    let postLogoutRedirectURL: URL?
    let loginActivationPath: String
    let postLogoutActivationPath: String?
    let deepLinkBaseURL: URL?
    let customLogoutEndpoint: URL?
    let authorizationEndpointPath: String
    let tokenEndpointPath: String
    let settingsEndpointPath: String

    static let manageBac = OAuthEnvironment(
        clientID: "VXEC4-1DWVYwfU-YXpTEO9hm94Z-rIVhkX6iIRzmSpI",
        scopes: ["mobile_api"],
        loginRedirectURL: URL(string: "faria-auth.co.Faria.MobileManageBac://authentication-callback")!,
        postLogoutRedirectURL: URL(string: "faria-auth.co.Faria.MobileManageBac://logout")!,
        loginActivationPath: "/oauth/callback",
        postLogoutActivationPath: "/oauth/logoutcallback",
        deepLinkBaseURL: nil,
        customLogoutEndpoint: nil,
        authorizationEndpointPath: "/oauth/authorize",
        tokenEndpointPath: "/oauth/token",
        settingsEndpointPath: "/oauth/authorize/info"
    )

    func loginActivationURL(for host: URL) -> URL {
        host.appendingEndpointPath(loginActivationPath)
    }

    func postLogoutActivationURL(for host: URL) -> URL? {
        guard let postLogoutActivationPath else {
            return nil
        }

        return host.appendingEndpointPath(postLogoutActivationPath)
    }
}
