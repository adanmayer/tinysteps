import Foundation
import MBAPI

struct MBStandardsCacheKey: Hashable, Sendable {
    let classID: String
    let programIdentifier: String

    init(classID: String, program: MBClassProgram?) {
        self.classID = classID
        self.programIdentifier = MBStandardsProgramDetector.programIdentifier(from: program)
    }
}

struct MBStandardsUnitFailure: Equatable, Sendable {
    let unitID: String
    let unitTitle: String
    let errorDescription: String
}

struct MBStandardUnitSection: Identifiable, Equatable, Sendable {
    let id: String
    let unitTitle: String
    let references: [MBStandardReference]

    init(unitID: String, unitTitle: String, references: [MBStandardReference]) {
        self.id = unitID
        self.unitTitle = unitTitle
        self.references = references
    }
}

enum MBStandardsLoadStatus: String, Sendable {
    case loaded
    case empty
    case partialFailure
    case failed
}

struct MBStandardsLoadResult: Equatable, Sendable {
    let classID: String
    let className: String
    let classProgramCode: String?
    let isPYP: Bool
    let status: MBStandardsLoadStatus
    let references: [MBStandardReference]
    let unitSections: [MBStandardUnitSection]
    let unitLoadFailures: [MBStandardsUnitFailure]
    let loadedAt: Date
    let errorMessage: String?

    var referencesByKind: [MBStandardReference.Kind: [MBStandardReference]] {
        Dictionary(grouping: references, by: \.kind)
    }
}

struct MBStandardsCacheEntry: Equatable, Sendable {
    let key: MBStandardsCacheKey
    let result: MBStandardsLoadResult
    let loadedAt: Date
}

enum MBStandardSourceIdentity: Codable, Equatable, Hashable, Sendable {
    case standard(unitID: String, standardID: String)
    case syllabus(unitID: String, syllabusID: String)
    case scopeSequence(unitID: String, expectationID: String)
    case pypTheme(themeID: String)
    case pypThemeDescription(themeID: String, descriptionID: String)
    case unresolved(kind: String, generatedID: String)

    var isPersistable: Bool {
        switch self {
        case .unresolved:
            return false
        case .standard, .syllabus, .scopeSequence, .pypTheme, .pypThemeDescription:
            return true
        }
    }

    var stableKey: String {
        switch self {
        case .standard(let unitID, let standardID):
            return "standard|unit=\(unitID)|standard=\(standardID)"
        case .syllabus(let unitID, let syllabusID):
            return "syllabus|unit=\(unitID)|syllabus=\(syllabusID)"
        case .scopeSequence(let unitID, let expectationID):
            return "scopeSequence|unit=\(unitID)|expectation=\(expectationID)"
        case .pypTheme(let themeID):
            return "pypTheme|theme=\(themeID)"
        case .pypThemeDescription(let themeID, let descriptionID):
            return "pypThemeDescription|theme=\(themeID)|description=\(descriptionID)"
        case .unresolved(let kind, let generatedID):
            return "unresolved|\(kind)|generated=\(generatedID)"
        }
    }
}

struct MBStandardReference: Equatable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case standard
        case syllabus
        case scopeSequence
        case pypTheme
    }

    let kind: Kind
    let classID: String
    let unitID: String
    let unitTitle: String
    let programCode: String?
    let sourceID: String
    let code: String?
    let title: String
    let detail: String?
    let isUnresolvedTheme: Bool
    let displayHashtag: String
    let sourceIdentity: MBStandardSourceIdentity
    let stableIdentity: String?

    var id: String {
        stableIdentity ?? "\(classID)|\(unitID)|\(sourceIdentity.stableKey)"
    }
}

enum MBStandardsProgramDetector {
    static let pypAliases: Set<String> = [
        "pyp",
        "ibpyp",
        "primary",
        "primaryyearsprogramme",
        "internationalbaccalaureatepyp",
        "internationalbaccalaureate",
        "primaryyearsprogram"
    ]

    static func normalizedValue(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func programCode(for program: MBClassProgram?) -> String? {
        if let code = program?.code, programCodeHasValue(code) {
            let normalized = normalizedValue(code)
            if normalized.isEmpty == false { return code }
        }

        if let name = program?.name, normalizedValue(name).isEmpty == false {
            return name
        }

        if let uid = program?.uid {
            let normalized = normalizedValue(uid)
            if normalized.isEmpty == false { return uid }
        }

        return nil
    }

    static func programIdentifier(from program: MBClassProgram?) -> String {
        if let value = program?.code, normalizedValue(value).isEmpty == false {
            return normalizedValue(value)
        }

        if let value = program?.name, normalizedValue(value).isEmpty == false {
            return normalizedValue(value)
        }

        if let value = program?.uid, normalizedValue(value).isEmpty == false {
            return normalizedValue(value)
        }

        return "unknown-program"
    }

    static func programIsPYP(_ program: MBClassProgram?) -> Bool {
        guard let program else {
            return false
        }

        let candidates = [program.code, program.name, program.uid]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return candidates.contains { candidate in
            let normalized = normalizedValue(candidate)
            if normalized == "pyp" {
                return true
            }

            if normalized == "ibpyp" {
                return true
            }

            if normalized == "primaryyearsprogramme" || normalized == "primaryyearsprogram" {
                return true
            }

            let words = normalized.split(separator: " ").map(String.init)
            let normalizedWords = Set(words)
            if normalizedWords.contains("primary") && normalizedWords.contains("years") {
                return true
            }

            if pypAliases.contains(normalized) {
                return true
            }

            return false
        }
    }

    private static func programCodeHasValue(_ code: String) -> Bool {
        let normalizedCode = normalizedValue(code)
        return normalizedCode.isEmpty == false
    }
}
