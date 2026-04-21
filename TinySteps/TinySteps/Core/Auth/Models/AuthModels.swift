import Foundation
import MBAPI

struct SchoolHost: Codable, Equatable, Hashable, Sendable {
    let baseURL: URL

    init(baseURL: URL) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let host = components.host,
              var normalizedComponents = URLComponents(string: "\(scheme)://\(host)") else {
            throw AuthError.invalidSchoolHost
        }

        normalizedComponents.port = components.port

        guard let normalizedURL = normalizedComponents.url else {
            throw AuthError.invalidSchoolHost
        }

        self.baseURL = normalizedURL
    }

    init(rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.invalidSchoolHost
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"

        guard let url = URL(string: candidate) else {
            throw AuthError.invalidSchoolHost
        }

        try self.init(baseURL: url)
    }

    var displayName: String {
        baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
    }

    var apiBaseURL: URL {
        baseURL.appendingEndpointPath("api/mobile")
    }
}

struct OAuthConfiguration: Codable, Equatable, Sendable {
    let loginHost: URL?
    let authority: URL
    let clientID: String
    let scopes: [String]
    let loginRedirectURL: URL
    let postLogoutRedirectURL: URL?
    let deepLinkBaseURL: URL?
    let customLogoutEndpoint: URL?
}

struct OAuthLoginResult: Codable, Equatable, Sendable {
    let resolvedSchoolHost: SchoolHost
    let tokenResult: OAuthTokenResult
    let message: String?
}

struct OAuthTokenResult: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresAt: Date?
    let tokenType: String
    let authority: URL?
    let accountIdentifier: String?
}

struct StoredTokenState: Codable, Equatable, Sendable {
    let schoolHost: SchoolHost
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresAt: Date?
    let authority: URL?
    let accountIdentifier: String?
    let apiRole: MBAPIRole?
    let savedAt: Date

    var needsRefresh: Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt <= Date().addingTimeInterval(300)
    }

    var isExpired: Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt <= Date()
    }

    init(
        schoolHost: SchoolHost,
        tokenResult: OAuthTokenResult,
        apiRole: MBAPIRole? = nil,
        savedAt: Date = Date()
    ) {
        self.schoolHost = schoolHost
        self.accessToken = tokenResult.accessToken
        self.refreshToken = tokenResult.refreshToken
        self.idToken = tokenResult.idToken
        self.tokenType = tokenResult.tokenType
        self.expiresAt = tokenResult.expiresAt
        self.authority = tokenResult.authority
        self.accountIdentifier = tokenResult.accountIdentifier
        self.apiRole = apiRole
        self.savedAt = savedAt
    }

    func with(apiRole: MBAPIRole) -> StoredTokenState {
        StoredTokenState(
            schoolHost: schoolHost,
            tokenResult: OAuthTokenResult(
                accessToken: accessToken,
                refreshToken: refreshToken,
                idToken: idToken,
                expiresAt: expiresAt,
                tokenType: tokenType,
                authority: authority,
                accountIdentifier: accountIdentifier
            ),
            apiRole: apiRole,
            savedAt: savedAt
        )
    }
}

struct AuthSession: Equatable, Sendable {
    let schoolHost: SchoolHost
    let accountIdentifier: String?
    let apiRole: MBAPIRole?
    let establishedAt: Date

    init(tokenState: StoredTokenState, establishedAt: Date = Date()) {
        self.schoolHost = tokenState.schoolHost
        self.accountIdentifier = tokenState.accountIdentifier
        self.apiRole = tokenState.apiRole
        self.establishedAt = establishedAt
    }

    var signedInScopeID: String {
        let account = accountIdentifier ?? "anonymous"
        return "\(schoolHost.displayName)|\(account)"
    }
}

enum AuthState: Equatable, Sendable {
    case signedOut(lastHost: SchoolHost?)
    case restoring
    case authenticating
    case signedIn(AuthSession)
    case failed(lastHost: SchoolHost?, message: String)
    case expired(lastHost: SchoolHost?)
}

enum AuthError: LocalizedError, Equatable, Sendable {
    case invalidSchoolHost
    case configurationUnavailable
    case signInUnavailable
    case refreshUnavailable
    case tokenPersistenceFailed
    case sessionExpired
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidSchoolHost:
            "The server returned an invalid school host."
        case .configurationUnavailable:
            "OAuth configuration is unavailable for the sign-in flow."
        case .signInUnavailable:
            "OAuth sign-in is not configured yet."
        case .refreshUnavailable:
            "The stored session could not be refreshed."
        case .tokenPersistenceFailed:
            "The app could not persist your session securely."
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        case .custom(let message):
            message
        }
    }
}

extension SchoolHost {
    static let preview = try! SchoolHost(rawValue: "school.managebac.com")
}

extension AuthSession {
    static let preview = AuthSession(
        tokenState: StoredTokenState(
            schoolHost: .preview,
            tokenResult: OAuthTokenResult(
                accessToken: "preview-token",
                refreshToken: "preview-refresh",
                idToken: nil,
                expiresAt: .distantFuture,
                tokenType: "Bearer",
                authority: nil,
                accountIdentifier: "parent@example.com"
            ),
            apiRole: .parent
        )
    )

    static let previewTeacher = AuthSession(
        tokenState: StoredTokenState(
            schoolHost: .preview,
            tokenResult: OAuthTokenResult(
                accessToken: "preview-token",
                refreshToken: "preview-refresh",
                idToken: nil,
                expiresAt: .distantFuture,
                tokenType: "Bearer",
                authority: nil,
                accountIdentifier: "teacher@example.com"
            ),
            apiRole: .teacher
        )
    )
}
