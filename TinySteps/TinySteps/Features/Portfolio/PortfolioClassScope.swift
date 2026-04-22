import Foundation

struct PortfolioClassScope: Identifiable, Equatable, Sendable {
    static let allID = "all"

    let id: String
    let classID: String?
    let title: String
    let subtitle: String?

    init(classID: String?, title: String, subtitle: String? = nil) {
        self.classID = classID
        self.id = classID ?? Self.allID
        self.title = title
        self.subtitle = subtitle
    }
}
