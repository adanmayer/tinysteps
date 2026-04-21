import Foundation

struct ChildSwitcherOption: Identifiable, Equatable, Sendable {
    let context: ChildContext
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var id: String {
        switch context {
        case .allChildren:
            return "all-children"
        case .child(let id):
            return id
        }
    }
}