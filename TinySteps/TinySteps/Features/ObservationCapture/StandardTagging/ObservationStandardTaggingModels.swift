import Foundation
import MBAPI

enum ObservationStandardTaggingSelectionSource: String, Codable, Sendable {
    case localAI
    case manual
}

struct ObservationStandardTagCandidate: Sendable {
    let id: String
    let kind: MBStandardReference.Kind
    let sourceID: String
    let unitID: String
    let unitTitle: String
    let classID: String
    let className: String
    let programCode: String?
    let code: String?
    let title: String
    let detail: String?
    let displayHashtag: String
    let sourceIdentity: MBStandardSourceIdentity
    let stableIdentity: String?
}

struct ObservationStandardTagSuggestion: Codable, Equatable, Sendable, Identifiable {
    var id: String { referenceID }
    let referenceID: String
    let sourceID: String
    let kind: MBStandardReference.Kind
    let classID: String
    let unitID: String
    let unitTitle: String
    let programCode: String?
    let code: String?
    let title: String
    let detail: String?
    let displayHashtag: String
    let sourceIdentity: MBStandardSourceIdentity
    var evidenceQuotes: [String]
    let selectionSource: ObservationStandardTaggingSelectionSource

    init(
        referenceID: String,
        sourceID: String,
        kind: MBStandardReference.Kind,
        classID: String,
        unitID: String,
        unitTitle: String,
        programCode: String?,
        code: String?,
        title: String,
        detail: String?,
        displayHashtag: String,
        sourceIdentity: MBStandardSourceIdentity? = nil,
        evidenceQuotes: [String],
        selectionSource: ObservationStandardTaggingSelectionSource
    ) {
        self.referenceID = referenceID
        self.sourceID = sourceID
        self.kind = kind
        self.classID = classID
        self.unitID = unitID
        self.unitTitle = unitTitle
        self.programCode = programCode
        self.code = code
        self.title = title
        self.detail = detail
        self.displayHashtag = displayHashtag
        self.sourceIdentity = sourceIdentity ?? Self.inferredSourceIdentity(kind: kind, unitID: unitID, sourceID: sourceID)
        self.evidenceQuotes = evidenceQuotes
        self.selectionSource = selectionSource
    }

    init(reference: MBStandardReference, selectionSource: ObservationStandardTaggingSelectionSource, evidenceQuotes: [String] = []) {
        self.referenceID = reference.id
        self.sourceID = reference.sourceID
        self.kind = reference.kind
        self.classID = reference.classID
        self.unitID = reference.unitID
        self.unitTitle = reference.unitTitle
        self.programCode = reference.programCode
        self.code = reference.code
        self.title = reference.title
        self.detail = reference.detail
        self.displayHashtag = reference.displayHashtag
        self.sourceIdentity = reference.sourceIdentity
        self.evidenceQuotes = evidenceQuotes
        self.selectionSource = selectionSource
    }

    init(referenceID: String, evidenceQuotes: [String], source: ObservationStandardTaggingSelectionSource, from candidate: ObservationStandardTagCandidate) {
        self.init(
            referenceID: referenceID,
            sourceID: candidate.sourceID,
            kind: candidate.kind,
            classID: candidate.classID,
            unitID: candidate.unitID,
            unitTitle: candidate.unitTitle,
            programCode: candidate.programCode,
            code: candidate.code,
            title: candidate.title,
            detail: candidate.detail,
            displayHashtag: candidate.displayHashtag,
            sourceIdentity: candidate.sourceIdentity,
            evidenceQuotes: evidenceQuotes,
            selectionSource: source
        )
    }

    private enum CodingKeys: String, CodingKey {
        case referenceID
        case sourceID
        case kind
        case classID
        case unitID
        case unitTitle
        case programCode
        case code
        case title
        case detail
        case displayHashtag
        case sourceIdentity
        case evidenceQuotes
        case selectionSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        referenceID = try container.decode(String.self, forKey: .referenceID)
        sourceID = try container.decode(String.self, forKey: .sourceID)
        kind = try container.decode(MBStandardReference.Kind.self, forKey: .kind)
        classID = try container.decode(String.self, forKey: .classID)
        unitID = try container.decode(String.self, forKey: .unitID)
        unitTitle = try container.decode(String.self, forKey: .unitTitle)
        programCode = try container.decodeIfPresent(String.self, forKey: .programCode)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        displayHashtag = try container.decode(String.self, forKey: .displayHashtag)
        sourceIdentity = try container.decodeIfPresent(MBStandardSourceIdentity.self, forKey: .sourceIdentity)
            ?? Self.inferredSourceIdentity(kind: kind, unitID: unitID, sourceID: sourceID)
        evidenceQuotes = try container.decodeIfPresent([String].self, forKey: .evidenceQuotes) ?? []
        selectionSource = try container.decode(ObservationStandardTaggingSelectionSource.self, forKey: .selectionSource)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(referenceID, forKey: .referenceID)
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(kind, forKey: .kind)
        try container.encode(classID, forKey: .classID)
        try container.encode(unitID, forKey: .unitID)
        try container.encode(unitTitle, forKey: .unitTitle)
        try container.encodeIfPresent(programCode, forKey: .programCode)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encode(displayHashtag, forKey: .displayHashtag)
        try container.encode(sourceIdentity, forKey: .sourceIdentity)
        try container.encode(evidenceQuotes, forKey: .evidenceQuotes)
        try container.encode(selectionSource, forKey: .selectionSource)
    }

    private static func inferredSourceIdentity(
        kind: MBStandardReference.Kind,
        unitID: String,
        sourceID: String
    ) -> MBStandardSourceIdentity {
        switch kind {
        case .standard:
            return .standard(unitID: unitID, standardID: sourceID)
        case .syllabus:
            return .syllabus(unitID: unitID, syllabusID: sourceID)
        case .scopeSequence:
            return .scopeSequence(unitID: unitID, expectationID: sourceID)
        case .pypTheme:
            return .pypTheme(themeID: sourceID)
        }
    }
}

struct ObservationStandardTaggingResult: Equatable, Sendable {
    let suggestions: [ObservationStandardTagSuggestion]
    let confidence: Double
    let pendingRetag: Bool
}

struct ObservationStandardTaggingRequest: Sendable {
    let classID: String
    let className: String
    let selectedUnitID: String
    let selectedUnitTitle: String
    let transcript: String
    let candidates: [ObservationStandardTagCandidate]
    let excludedSuggestionIDs: Set<String>
    let candidateLookup: [String: MBStandardReference]
}

enum ObservationStandardTaggingEvent: Equatable, Sendable {
    case partial([ObservationStandardTagSuggestion])
    case suggestions(ObservationStandardTaggingResult)
    case unavailable
}

protocol ObservationStandardTaggingService: Sendable {
    func suggestStandardTags(
        request: ObservationStandardTaggingRequest
    ) -> AsyncThrowingStream<ObservationStandardTaggingEvent, Error>
}

enum ObservationStandardTaggingParserError: LocalizedError, Equatable {
    case malformedResponse
    case malformedEnvelope
    case missingTranscript

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Standard tagging response was not valid JSON."
        case .malformedEnvelope:
            return "Standard tagging response was missing required fields."
        case .missingTranscript:
            return "Standard tagging requires transcript text."
        }
    }
}
