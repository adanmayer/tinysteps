import Foundation

struct AuthComposition {
    let authController: AuthController
    let credentialsProvider: MBAPICredentialsProvider

    static func live(environment: AppEnvironment = .live) -> AuthComposition {
        let tokenStore = KeychainTokenStore()
        let configurationService = LiveOAuthConfigurationService(environment: environment)
        let sessionDriver = AppAuthOAuthSessionDriver(environment: environment)
        let credentialsProvider = StoredTokenMBAPICredentialsProvider(tokenStore: tokenStore)
        let authController = AuthController(
            tokenStore: tokenStore,
            configurationService: configurationService,
            sessionDriver: sessionDriver
        )

        return AuthComposition(
            authController: authController,
            credentialsProvider: credentialsProvider
        )
    }
}
