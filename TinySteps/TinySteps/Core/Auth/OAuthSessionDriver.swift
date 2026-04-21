import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

protocol OAuthSessionDriver {
    func signIn(using configuration: OAuthConfiguration) async throws -> OAuthLoginResult
    func refresh(using tokenState: StoredTokenState) async throws -> OAuthTokenResult
    func handleRedirectURL(_ url: URL) -> Bool
}

private struct OAuthDeviceContext {
    let uid: String
    let type: String
    let info: String

    static func current() -> OAuthDeviceContext {
        let environment = ProcessInfo.processInfo.environment
        let simulatorName = environment["SIMULATOR_DEVICE_NAME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceType = simulatorName.flatMap { $0.isEmpty ? nil : $0 } ?? UIDevice.current.model

        return OAuthDeviceContext(
            uid: UIDevice.current.identifierForVendor?.uuidString ?? "",
            type: deviceType,
            info: UIDevice.current.name
        )
    }
}

@MainActor
final class AppAuthOAuthSessionDriver: NSObject, OAuthSessionDriver, ASWebAuthenticationPresentationContextProviding {
    private struct CallbackPayload {
        let code: String
        let schoolHost: String
        let message: String?

        init(url: URL, expectedState: String) throws {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw AuthError.custom("The login response could not be read.")
            }

            let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

            if let error = items["error"] {
                let description = items["error_description"] ?? error
                throw AuthError.custom(description)
            }

            guard items["state"] == expectedState else {
                throw AuthError.custom("The login response did not match the active sign-in request.")
            }

            guard let code = items["code"], !code.isEmpty else {
                throw AuthError.custom("The login response did not include an authorization code.")
            }

            guard let schoolHost = items["school_host"], !schoolHost.isEmpty else {
                throw AuthError.custom("The login response did not include a school host.")
            }

            self.code = code
            self.schoolHost = schoolHost
            self.message = items["message"]
        }
    }

    private struct PKCEContext {
        let state: String
        let nonce: String
        let codeVerifier: String
        let authorizationURL: URL
        let redirectURL: URL
        let callbackScheme: String
    }

    private struct PendingRedirect {
        let expectedRedirectURL: URL
        let activationPath: String
        let continuation: CheckedContinuation<URL, Error>
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let idToken: String?
        let expiresIn: TimeInterval?
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }
    }

    private struct OAuthServerError: Decodable {
        let error: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    private let environment: AppEnvironment
    private let urlSession: URLSession
    private let webAuthenticationSessionFactory: @MainActor (URL, String, @escaping (URL?, Error?) -> Void) -> ASWebAuthenticationSession
    private var activeSession: ASWebAuthenticationSession?
    private var pendingRedirect: PendingRedirect?

    init(
        environment: AppEnvironment,
        urlSession: URLSession = .shared,
        webAuthenticationSessionFactory: @escaping @MainActor (URL, String, @escaping (URL?, Error?) -> Void) -> ASWebAuthenticationSession = { url, scheme, completion in
            ASWebAuthenticationSession(url: url, callbackURLScheme: scheme, completionHandler: completion)
        }
    ) {
        self.environment = environment
        self.urlSession = urlSession
        self.webAuthenticationSessionFactory = webAuthenticationSessionFactory
        super.init()
    }

    func signIn(using configuration: OAuthConfiguration) async throws -> OAuthLoginResult {
        let context = try makePKCEContext(using: configuration)
        let callbackURL = try await startWebAuthenticationSession(context: context)
        let callbackPayload = try CallbackPayload(url: callbackURL, expectedState: context.state)
        let resolvedSchoolHost = try SchoolHost(rawValue: callbackPayload.schoolHost)
        let tokenEndpoint = resolvedSchoolHost.baseURL.appendingEndpointPath(environment.oauth.tokenEndpointPath)
        let tokenResult = try await exchangeAuthorizationCode(
            code: callbackPayload.code,
            codeVerifier: context.codeVerifier,
            redirectURL: configuration.loginRedirectURL,
            tokenEndpoint: tokenEndpoint,
            authority: resolvedSchoolHost.baseURL
        )

        return OAuthLoginResult(
            resolvedSchoolHost: resolvedSchoolHost,
            tokenResult: tokenResult,
            message: callbackPayload.message
        )
    }

    func refresh(using tokenState: StoredTokenState) async throws -> OAuthTokenResult {
        guard let refreshToken = tokenState.refreshToken, !refreshToken.isEmpty else {
            throw AuthError.refreshUnavailable
        }

        let authority = tokenState.schoolHost.baseURL
        let tokenEndpoint = authority.appendingEndpointPath(environment.oauth.tokenEndpointPath)
        return try await exchangeRefreshToken(
            refreshToken: refreshToken,
            tokenEndpoint: tokenEndpoint,
            authority: authority,
            fallbackAccountIdentifier: tokenState.accountIdentifier
        )
    }

    func handleRedirectURL(_ url: URL) -> Bool {
        guard let pendingRedirect,
                            let resumeURL = Self.resumeRedirectURL(
                                from: url,
                                expectedRedirectURL: pendingRedirect.expectedRedirectURL,
                                activationPath: pendingRedirect.activationPath
                            ) else {
            return false
        }

        activeSession?.cancel()
        activeSession = nil
        self.pendingRedirect = nil
                pendingRedirect.continuation.resume(returning: resumeURL)
        return true
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let _ = session

        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
        if let scene = windowScenes.first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: \.isKeyWindow) {
            return window
        }

        if let scene = windowScenes.first {
            return scene.windows.first ?? UIWindow(windowScene: scene)
        }

        preconditionFailure("ASWebAuthenticationSession requires an active UIWindowScene.")
    }

    private func makePKCEContext(using configuration: OAuthConfiguration) throws -> PKCEContext {
        guard let loginHost = configuration.loginHost else {
            throw AuthError.configurationUnavailable
        }

        guard let callbackScheme = configuration.loginRedirectURL.scheme, !callbackScheme.isEmpty else {
            throw AuthError.configurationUnavailable
        }

        let state = Self.randomURLSafeString(length: 32)
        let nonce = Self.randomURLSafeString(length: 32)
        let codeVerifier = Self.randomURLSafeString(length: 64)
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        let authorizationURL = try makeAuthorizationURL(
            loginHost: loginHost,
            configuration: configuration,
            state: state,
            codeChallenge: codeChallenge,
            nonce: nonce
        )

        return PKCEContext(
            state: state,
            nonce: nonce,
            codeVerifier: codeVerifier,
            authorizationURL: authorizationURL,
            redirectURL: configuration.loginRedirectURL,
            callbackScheme: callbackScheme
        )
    }

    private func makeAuthorizationURL(
        loginHost: URL,
        configuration: OAuthConfiguration,
        state: String,
        codeChallenge: String,
        nonce: String
    ) throws -> URL {
        let endpoint = loginHost.appendingEndpointPath(environment.oauth.authorizationEndpointPath)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.configurationUnavailable
        }

        let device = OAuthDeviceContext.current()

        components.queryItems = Self.makeAuthorizationQueryItems(
            configuration: configuration,
            state: state,
            nonce: nonce,
            codeChallenge: codeChallenge,
            deviceUID: device.uid,
            deviceType: device.type,
            deviceInfo: device.info
        )

        guard let url = components.url else {
            throw AuthError.configurationUnavailable
        }

        return url
    }

    private func startWebAuthenticationSession(context: PKCEContext) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            pendingRedirect = PendingRedirect(
                expectedRedirectURL: context.redirectURL,
                activationPath: environment.oauth.loginActivationPath,
                continuation: continuation
            )

            let session = webAuthenticationSessionFactory(context.authorizationURL, context.callbackScheme) { [weak self] callbackURL, error in
                self?.handleAuthenticationSessionCallback(callbackURL: callbackURL, error: error)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.activeSession = session

            if !session.start() {
                self.activeSession = nil
                let pendingRedirect = self.pendingRedirect
                self.pendingRedirect = nil
                pendingRedirect?.continuation.resume(throwing: AuthError.signInUnavailable)
            }
        }
    }

    private func handleAuthenticationSessionCallback(callbackURL: URL?, error: Error?) {
        activeSession = nil

        guard let pendingRedirect else {
            return
        }

        self.pendingRedirect = nil

        if let callbackURL {
            pendingRedirect.continuation.resume(returning: callbackURL)
            return
        }

        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
            pendingRedirect.continuation.resume(throwing: AuthError.custom("Sign-in was cancelled."))
            return
        }

        pendingRedirect.continuation.resume(throwing: error ?? AuthError.signInUnavailable)
    }

    private func exchangeAuthorizationCode(
        code: String,
        codeVerifier: String,
        redirectURL: URL,
        tokenEndpoint: URL,
        authority: URL
    ) async throws -> OAuthTokenResult {
        let device = OAuthDeviceContext.current()
        let parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": environment.oauth.clientID,
            "redirect_uri": redirectURL.absoluteString,
            "code_verifier": codeVerifier,
            "device[uid]": device.uid,
            "device[type]": device.type,
            "device[info]": device.info,
        ]

        return try await sendTokenRequest(
            parameters: parameters,
            tokenEndpoint: tokenEndpoint,
            authority: authority,
            fallbackAccountIdentifier: nil
        )
    }

    private func exchangeRefreshToken(
        refreshToken: String,
        tokenEndpoint: URL,
        authority: URL,
        fallbackAccountIdentifier: String?
    ) async throws -> OAuthTokenResult {
        let device = OAuthDeviceContext.current()
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": environment.oauth.clientID,
            "scope": environment.oauth.scopes.joined(separator: " "),
            "device[uid]": device.uid,
            "device[type]": device.type,
            "device[info]": device.info,
        ]

        return try await sendTokenRequest(
            parameters: parameters,
            tokenEndpoint: tokenEndpoint,
            authority: authority,
            fallbackAccountIdentifier: fallbackAccountIdentifier
        )
    }

    private func sendTokenRequest(
        parameters: [String: String],
        tokenEndpoint: URL,
        authority: URL,
        fallbackAccountIdentifier: String?
    ) async throws -> OAuthTokenResult {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Self.formEncodedData(from: parameters)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw Self.tokenRequestError(from: error, tokenEndpoint: tokenEndpoint)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.refreshUnavailable
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let serverError = try? JSONDecoder().decode(OAuthServerError.self, from: data),
               let description = serverError.errorDescription ?? serverError.error {
                throw AuthError.custom(description)
            }

            throw AuthError.refreshUnavailable
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuthTokenResult(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            idToken: tokenResponse.idToken,
            expiresAt: tokenResponse.expiresIn.map { Date().addingTimeInterval($0) },
            tokenType: tokenResponse.tokenType,
            authority: authority,
            accountIdentifier: fallbackAccountIdentifier
        )
    }

    nonisolated static func tokenRequestError(from error: Error, tokenEndpoint: URL) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return .custom(error.localizedDescription)
        }

        switch nsError.code {
        case URLError.secureConnectionFailed.rawValue,
             URLError.serverCertificateHasBadDate.rawValue,
             URLError.serverCertificateUntrusted.rawValue,
             URLError.serverCertificateHasUnknownRoot.rawValue,
             URLError.serverCertificateNotYetValid.rawValue,
             URLError.clientCertificateRejected.rawValue,
             URLError.clientCertificateRequired.rawValue:
            let host = tokenEndpoint.host(percentEncoded: false) ?? tokenEndpoint.absoluteString
            return .custom("Secure connection to \(host) failed. If a proxy such as Proxyman or Charles is intercepting HTTPS traffic, trust its certificate on the simulator/device or disable SSL proxying for this host.")
        default:
            return .custom(error.localizedDescription)
        }
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomURLSafeString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func formEncodedData(from parameters: [String: String]) -> Data {
        let body = parameters
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")

        return Data(body.utf8)
    }

    private static func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    nonisolated static func makeAuthorizationQueryItems(
        configuration: OAuthConfiguration,
        state: String,
        nonce: String,
        codeChallenge: String,
        deviceUID: String,
        deviceType: String,
        deviceInfo: String
    ) -> [URLQueryItem] {
        [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.loginRedirectURL.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "provider", value: "default"),
            URLQueryItem(name: "device[uid]", value: deviceUID),
            URLQueryItem(name: "device[type]", value: deviceType),
            URLQueryItem(name: "device[info]", value: deviceInfo),
        ]
    }

    nonisolated static func resumeRedirectURL(
        from incomingURL: URL,
        expectedRedirectURL: URL,
        activationPath: String
    ) -> URL? {
        if matchesRedirectURL(incomingURL, expectedRedirectURL: expectedRedirectURL) {
            return incomingURL
        }

        guard matchesActivationURL(incomingURL, activationPath: activationPath),
              var components = URLComponents(url: expectedRedirectURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.query = incomingURL.query
        components.fragment = nil
        return components.url
    }

    nonisolated static func matchesRedirectURL(_ url: URL, expectedRedirectURL: URL) -> Bool {
        guard let incoming = normalizedRedirectComponents(for: url),
              let expected = normalizedRedirectComponents(for: expectedRedirectURL) else {
            return false
        }

        return incoming.scheme == expected.scheme
            && incoming.host == expected.host
            && incoming.port == expected.port
            && incoming.path == expected.path
    }

    nonisolated static func matchesActivationURL(_ url: URL, activationPath: String) -> Bool {
        guard let components = normalizedRedirectComponents(for: url) else {
            return false
        }

        let normalizedActivationPath: String
        if activationPath.isEmpty {
            normalizedActivationPath = "/"
        } else if activationPath.hasPrefix("/") {
            normalizedActivationPath = activationPath
        } else {
            normalizedActivationPath = "/\(activationPath)"
        }

        return components.path == normalizedActivationPath
    }

    private nonisolated static func normalizedRedirectComponents(for url: URL) -> URLComponents? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.query = nil
        components.fragment = nil
        components.host = components.host?.lowercased()

        let path = components.path.isEmpty ? "/" : components.path
        components.path = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path

        return components
    }
}
