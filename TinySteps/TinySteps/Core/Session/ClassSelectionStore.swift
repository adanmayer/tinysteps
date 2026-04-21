import Foundation

protocol ClassSelectionStore {
    func loadSelection(for session: AuthSession) -> ClassContext?
    func saveSelection(_ context: ClassContext, for session: AuthSession)
    func clearSelection(for session: AuthSession)
}

final class UserDefaultsClassSelectionStore: ClassSelectionStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "class-selection"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSelection(for session: AuthSession) -> ClassContext? {
        guard let data = defaults.data(forKey: key(for: session)) else {
            return nil
        }

        return try? decoder.decode(ClassContext.self, from: data)
    }

    func saveSelection(_ context: ClassContext, for session: AuthSession) {
        guard let data = try? encoder.encode(context) else {
            return
        }

        defaults.set(data, forKey: key(for: session))
    }

    func clearSelection(for session: AuthSession) {
        defaults.removeObject(forKey: key(for: session))
    }

    private func key(for session: AuthSession) -> String {
        let account = session.accountIdentifier ?? "anonymous"
        return "\(keyPrefix).\(session.schoolHost.displayName).\(account)"
    }
}
