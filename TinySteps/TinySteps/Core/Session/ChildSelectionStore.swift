import Foundation

protocol ChildSelectionStore {
    func loadSelection(for session: AuthSession) -> ChildContext?
    func saveSelection(_ context: ChildContext, for session: AuthSession)
    func clearSelection(for session: AuthSession)
}

final class UserDefaultsChildSelectionStore: ChildSelectionStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "child-selection"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSelection(for session: AuthSession) -> ChildContext? {
        guard let data = defaults.data(forKey: key(for: session)) else {
            return nil
        }

        return try? decoder.decode(ChildContext.self, from: data)
    }

    func saveSelection(_ context: ChildContext, for session: AuthSession) {
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
