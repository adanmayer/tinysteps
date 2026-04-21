import Foundation
import Security

protocol TokenStore {
    func loadTokenState() throws -> StoredTokenState?
    func saveTokenState(_ tokenState: StoredTokenState) throws
    func clearTokenState() throws
}

final class KeychainTokenStore: TokenStore {
    private let service = "co.faria.TinySteps.auth"
    private let account = "active-auth-state"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadTokenState() throws -> StoredTokenState? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw AuthError.tokenPersistenceFailed
            }

            return try decoder.decode(StoredTokenState.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw AuthError.tokenPersistenceFailed
        }
    }

    func saveTokenState(_ tokenState: StoredTokenState) throws {
        let data = try encoder.encode(tokenState)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData] = data

            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AuthError.tokenPersistenceFailed
            }

            return
        }

        guard updateStatus == errSecSuccess else {
            throw AuthError.tokenPersistenceFailed
        }
    }

    func clearTokenState() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.tokenPersistenceFailed
        }
    }
}

final class InMemoryTokenStore: TokenStore {
    private var tokenState: StoredTokenState?

    func loadTokenState() throws -> StoredTokenState? {
        tokenState
    }

    func saveTokenState(_ tokenState: StoredTokenState) throws {
        self.tokenState = tokenState
    }

    func clearTokenState() throws {
        tokenState = nil
    }
}
