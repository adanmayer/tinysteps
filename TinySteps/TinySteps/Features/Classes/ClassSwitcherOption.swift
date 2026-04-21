import Foundation

struct ClassSwitcherOption: Identifiable, Equatable, Sendable {
    let context: ClassContext
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var id: String {
        switch context {
        case .allClasses:
            return "all-classes"
        case .schoolClass(let id):
            return id
        }
    }
}
