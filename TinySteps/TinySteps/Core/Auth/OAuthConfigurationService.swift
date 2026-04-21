import Foundation

protocol OAuthConfigurationService {
    func bootstrapConfiguration() async throws -> OAuthConfiguration
    func configuration(for schoolHost: SchoolHost) async throws -> OAuthConfiguration
}

final class LiveOAuthConfigurationService: OAuthConfigurationService {
    private struct OAuthSettingsResponse: Decodable {
        let signInHost: String
        let disabled: Bool

        enum CodingKeys: String, CodingKey {
            case signInHost = "sign_in_host"
            case disabled = "mobile_oauth_disabled"
        }
    }

    private let bootstrapLoader: @Sendable () async throws -> OAuthConfiguration
    private let loader: @Sendable (SchoolHost) async throws -> OAuthConfiguration

    init(
        bootstrapLoader: @escaping @Sendable () async throws -> OAuthConfiguration = {
            throw AuthError.configurationUnavailable
        },
        loader: @escaping @Sendable (SchoolHost) async throws -> OAuthConfiguration = { _ in
        throw AuthError.configurationUnavailable
        }
    ) {
        self.bootstrapLoader = bootstrapLoader
        self.loader = loader
    }

    convenience init(
        environment: AppEnvironment = .live,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            bootstrapLoader: {
                let settings = try await Self.fetchSettings(
                    environment: environment,
                    session: session,
                    decoder: decoder
                )
                return try await MainActor.run {
                    try Self.makeConfiguration(
                        environment: environment,
                        signInHost: settings.signInHost,
                        authority: environment.apiBaseURL
                    )
                }
            },
            loader: { schoolHost in
                let settings = try await Self.fetchSettings(
                    environment: environment,
                    session: session,
                    decoder: decoder
                )
                return try await MainActor.run {
                    try Self.makeConfiguration(
                        environment: environment,
                        signInHost: settings.signInHost,
                        authority: schoolHost.baseURL
                    )
                }
            }
        )
    }

    func bootstrapConfiguration() async throws -> OAuthConfiguration {
        try await bootstrapLoader()
    }

    func configuration(for schoolHost: SchoolHost) async throws -> OAuthConfiguration {
        try await loader(schoolHost)
    }

    private static func fetchSettings(
        environment: AppEnvironment,
        session: URLSession,
        decoder: JSONDecoder
    ) async throws -> OAuthSettingsResponse {
        let requestURL = environment.apiBaseURL.appendingEndpointPath(environment.oauth.settingsEndpointPath)
        let (data, response) = try await session.data(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AuthError.configurationUnavailable
        }

        let settings = try decoder.decode(OAuthSettingsResponse.self, from: data)

        guard !settings.disabled else {
            throw AuthError.configurationUnavailable
        }

        return settings
    }

    private static func makeConfiguration(
        environment: AppEnvironment,
        signInHost: String,
        authority: URL
    ) throws -> OAuthConfiguration {
        guard let loginHost = URL(string: signInHost) else {
            throw AuthError.configurationUnavailable
        }

        return OAuthConfiguration(
            loginHost: loginHost,
            authority: authority,
            clientID: environment.oauth.clientID,
            scopes: environment.oauth.scopes,
            loginRedirectURL: environment.oauth.loginRedirectURL,
            postLogoutRedirectURL: environment.oauth.postLogoutRedirectURL,
            deepLinkBaseURL: environment.oauth.deepLinkBaseURL,
            customLogoutEndpoint: environment.oauth.customLogoutEndpoint
        )
    }
}
