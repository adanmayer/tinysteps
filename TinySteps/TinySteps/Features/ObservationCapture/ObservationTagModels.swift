import Foundation

enum ObservationPYPTagCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case transdisciplinaryTheme
    case keyConcept
    case atlSkill
    case learnerProfile

    var displayTitle: String {
        switch self {
        case .transdisciplinaryTheme:
            return "Theme"
        case .keyConcept:
            return "Concept"
        case .atlSkill:
            return "ATL"
        case .learnerProfile:
            return "Profile"
        }
    }
}

struct ObservationPYPTagReference: Hashable, Codable, Sendable {
    var category: ObservationPYPTagCategory
    var value: String
}

struct ObservationEvidenceSpan: Identifiable, Codable, Equatable, Sendable {
    var category: ObservationPYPTagCategory
    var value: String
    var quote: String
    var start: Int?
    var end: Int?

    var id: String {
        "\(category.rawValue)-\(value)-\(quote)-\(start ?? -1)-\(end ?? -1)"
    }

    var reference: ObservationPYPTagReference {
        ObservationPYPTagReference(category: category, value: value)
    }
}

struct ObservationPYPTagBundle: Codable, Equatable, Sendable {
    var transdisciplinaryTheme: PYPTheme?
    var keyConcepts: [PYPKeyConcept]
    var atlSkills: [PYPATLSkillCluster]
    var learnerProfile: [PYPLearnerProfile]

    static let empty = ObservationPYPTagBundle(
        transdisciplinaryTheme: nil,
        keyConcepts: [],
        atlSkills: [],
        learnerProfile: []
    )

    var isEmpty: Bool {
        transdisciplinaryTheme == nil &&
        keyConcepts.isEmpty &&
        atlSkills.isEmpty &&
        learnerProfile.isEmpty
    }

    func contains(category: ObservationPYPTagCategory, value: String) -> Bool {
        switch category {
        case .transdisciplinaryTheme:
            return transdisciplinaryTheme?.rawValue == value
        case .keyConcept:
            return keyConcepts.contains { $0.rawValue == value }
        case .atlSkill:
            return atlSkills.contains { $0.rawValue == value }
        case .learnerProfile:
            return learnerProfile.contains { $0.rawValue == value }
        }
    }

    mutating func remove(category: ObservationPYPTagCategory, value: String) {
        switch category {
        case .transdisciplinaryTheme:
            if transdisciplinaryTheme?.rawValue == value {
                transdisciplinaryTheme = nil
            }
        case .keyConcept:
            keyConcepts.removeAll { $0.rawValue == value }
        case .atlSkill:
            atlSkills.removeAll { $0.rawValue == value }
        case .learnerProfile:
            learnerProfile.removeAll { $0.rawValue == value }
        }
    }
}

enum PYPTheme: String, CaseIterable, Codable, Sendable {
    case whoWeAre = "Who we are"
    case whereWeAreInPlaceAndTime = "Where we are in place and time"
    case howWeExpressOurselves = "How we express ourselves"
    case howTheWorldWorks = "How the world works"
    case howWeOrganizeOurselves = "How we organize ourselves"
    case sharingThePlanet = "Sharing the planet"

    init?(modelValue: String) {
        guard let match = Self.firstNormalizedMatch(for: modelValue) else {
            return nil
        }
        self = match
    }
}

enum PYPKeyConcept: String, CaseIterable, Codable, Sendable {
    case form = "Form"
    case function = "Function"
    case causation = "Causation"
    case change = "Change"
    case connection = "Connection"
    case perspective = "Perspective"
    case responsibility = "Responsibility"

    init?(modelValue: String) {
        guard let match = Self.firstNormalizedMatch(for: modelValue) else {
            return nil
        }
        self = match
    }
}

enum PYPATLSkillCluster: String, CaseIterable, Codable, Sendable {
    case thinking = "Thinking skills"
    case research = "Research skills"
    case communication = "Communication skills"
    case social = "Social skills"
    case selfManagement = "Self-management skills"

    init?(modelValue: String) {
        guard let match = Self.firstNormalizedMatch(for: modelValue) else {
            return nil
        }
        self = match
    }
}

enum PYPLearnerProfile: String, CaseIterable, Codable, Sendable {
    case inquirer = "Inquirer"
    case knowledgeable = "Knowledgeable"
    case thinker = "Thinker"
    case communicator = "Communicator"
    case principled = "Principled"
    case openMinded = "Open-minded"
    case caring = "Caring"
    case riskTaker = "Risk-taker"
    case balanced = "Balanced"
    case reflective = "Reflective"

    init?(modelValue: String) {
        guard let match = Self.firstNormalizedMatch(for: modelValue) else {
            return nil
        }
        self = match
    }
}

private extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static func firstNormalizedMatch(for value: String) -> Self? {
        let normalizedValue = ObservationTagValueNormalizer.normalize(value)
        return allCases.first {
            ObservationTagValueNormalizer.normalize($0.rawValue) == normalizedValue
        }
    }
}

enum ObservationTagValueNormalizer {
    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
