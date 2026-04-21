import Foundation

enum ClassContext: Codable, Equatable, Sendable {
    case allClasses
    case schoolClass(id: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
    }

    private enum Kind: String, Codable {
        case allClasses
        case schoolClass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .allClasses:
            self = .allClasses
        case .schoolClass:
            self = .schoolClass(id: try container.decode(String.self, forKey: .id))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .allClasses:
            try container.encode(Kind.allClasses, forKey: .kind)
        case .schoolClass(let id):
            try container.encode(Kind.schoolClass, forKey: .kind)
            try container.encode(id, forKey: .id)
        }
    }

    var apiClassID: String? {
        if case .schoolClass(let id) = self {
            return id
        }

        return nil
    }
}
