import Foundation

enum ChildContext: Codable, Equatable, Sendable {
    case allChildren
    case child(id: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
    }

    private enum Kind: String, Codable {
        case allChildren
        case child
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .allChildren:
            self = .allChildren
        case .child:
            self = .child(id: try container.decode(String.self, forKey: .id))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .allChildren:
            try container.encode(Kind.allChildren, forKey: .kind)
        case .child(let id):
            try container.encode(Kind.child, forKey: .kind)
            try container.encode(id, forKey: .id)
        }
    }

    var apiChildID: String? {
        if case .child(let id) = self {
            return id
        }

        return nil
    }
}
