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
            evidenceQuotes: evidenceQuotes,
            selectionSource: source
        )
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
