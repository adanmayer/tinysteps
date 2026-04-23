import Foundation

struct ObservationCaptureDraft: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var classID: String
    var className: String
    var transcript: String
    var matchedChildren: [ObservationMatchedChild]
    var tags: ObservationPYPTagBundle
    var standardTagSuggestions: [ObservationStandardTagSuggestion]
    var confidence: Double
    var evidenceSpans: [ObservationEvidenceSpan]
    var pendingRetag: Bool
    var dismissedChildMatchKeys: Set<String>
    var status: ObservationDraftStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        classID: String,
        className: String,
        transcript: String,
        matchedChildren: [ObservationMatchedChild] = [],
        tags: ObservationPYPTagBundle = .empty,
        standardTagSuggestions: [ObservationStandardTagSuggestion] = [],
        confidence: Double = 0,
        evidenceSpans: [ObservationEvidenceSpan] = [],
        pendingRetag: Bool = true,
        dismissedChildMatchKeys: Set<String> = [],
        status: ObservationDraftStatus = .localDraft,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.classID = classID
        self.className = className
        self.transcript = transcript
        self.matchedChildren = matchedChildren
        self.tags = tags
        self.standardTagSuggestions = standardTagSuggestions
        self.confidence = confidence
        self.evidenceSpans = evidenceSpans
        self.pendingRetag = pendingRetag
        self.dismissedChildMatchKeys = dismissedChildMatchKeys
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case classID
        case className
        case transcript
        case matchedChildren
        case tags
        case standardTagSuggestions
        case confidence
        case evidenceSpans
        case pendingRetag
        case dismissedChildMatchKeys
        case status
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        classID = try container.decode(String.self, forKey: .classID)
        className = try container.decode(String.self, forKey: .className)
        transcript = try container.decode(String.self, forKey: .transcript)
        matchedChildren = try container.decode([ObservationMatchedChild].self, forKey: .matchedChildren)
        tags = try container.decode(ObservationPYPTagBundle.self, forKey: .tags)
        standardTagSuggestions = try container.decodeIfPresent([ObservationStandardTagSuggestion].self, forKey: .standardTagSuggestions) ?? []
        confidence = try container.decode(Double.self, forKey: .confidence)
        evidenceSpans = try container.decode([ObservationEvidenceSpan].self, forKey: .evidenceSpans)
        pendingRetag = try container.decode(Bool.self, forKey: .pendingRetag)
        dismissedChildMatchKeys = try container.decodeIfPresent(Set<String>.self, forKey: .dismissedChildMatchKeys) ?? []
        status = try container.decode(ObservationDraftStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(classID, forKey: .classID)
        try container.encode(className, forKey: .className)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(matchedChildren, forKey: .matchedChildren)
        try container.encode(tags, forKey: .tags)
        try container.encode(standardTagSuggestions, forKey: .standardTagSuggestions)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(evidenceSpans, forKey: .evidenceSpans)
        try container.encode(pendingRetag, forKey: .pendingRetag)
        try container.encode(dismissedChildMatchKeys, forKey: .dismissedChildMatchKeys)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum ObservationDraftStatus: String, Codable, Equatable, Sendable {
    case localDraft
    case savedForReview

    var isRecoverableActiveDraft: Bool {
        switch self {
        case .localDraft:
            return true
        case .savedForReview:
            return false
        }
    }
}

struct ObservationMatchedChild: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let studentKey: String
    let userID: String?
    let displayName: String
    let matchText: String
    let confidence: Double

    init(
        studentKey: String,
        userID: String? = nil,
        displayName: String,
        matchText: String,
        confidence: Double = 1
    ) {
        self.id = studentKey
        self.studentKey = studentKey
        self.userID = userID
        self.displayName = displayName
        self.matchText = matchText
        self.confidence = confidence
    }
}
