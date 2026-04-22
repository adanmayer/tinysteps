import Foundation

protocol ObservationTaggingService: Sendable {
    func suggestTags(
        transcript: String,
        classContext: ObservationCaptureSession
    ) -> AsyncThrowingStream<ObservationTaggingEvent, Error>
}

enum ObservationTaggingEvent: Equatable, Sendable {
    case suggestions(ObservationTaggingResult)
    case unavailable
}

struct ObservationTaggingResult: Equatable, Sendable {
    var tags: ObservationPYPTagBundle
    var confidence: Double
    var evidenceSpans: [ObservationEvidenceSpan]
    var pendingRetag: Bool
}

struct DisabledObservationTaggingService: ObservationTaggingService {
    func suggestTags(
        transcript: String,
        classContext: ObservationCaptureSession
    ) -> AsyncThrowingStream<ObservationTaggingEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.unavailable)
            continuation.finish()
        }
    }
}

struct ObservationTaggingParser: Sendable {
    private let minimumTranscriptTokenCount = 2

    private func transcriptTokenSet(for text: String) -> Set<String> {
        Set(
            text
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .compactMap { token in
                    let normalized = token
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard normalized.isEmpty == false else { return nil }
                    guard normalized.count >= 3 else { return nil }
                    return normalized
                }
        )
    }

    func parse(data: Data, transcript: String) throws -> ObservationTaggingResult {
        guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return ObservationTaggingResult(
                tags: .empty,
                confidence: 0,
                evidenceSpans: [],
                pendingRetag: true
            )	
        }

        guard transcriptTokenSet(for: transcript).count >= minimumTranscriptTokenCount else {
            return ObservationTaggingResult(
                tags: .empty,
                confidence: 0,
                evidenceSpans: [],
                pendingRetag: true
            )
        }

        let response: TaggingResponse
        do {
            response = try JSONDecoder().decode(TaggingResponse.self, from: data)
        } catch {
            throw ObservationTaggingParserError.malformedResponse
        }

        let proposedTheme = response.tags.transdisciplinaryTheme.flatMap(PYPTheme.init(modelValue:))
        let proposedConcepts = response.tags.keyConcepts.compactMap(PYPKeyConcept.init(modelValue:))
        let proposedATL = response.tags.atlSkills.compactMap(PYPATLSkillCluster.init(modelValue:))
        let proposedProfile = response.tags.learnerProfile.compactMap(PYPLearnerProfile.init(modelValue:))
        let evidenceSpans = response.evidenceSpans.compactMap {
            parseEvidenceSpan($0, transcript: transcript)
        }
        let evidenceReferences = Set(evidenceSpans.map(\.reference))

        var finalTags = ObservationPYPTagBundle.empty
        if let proposedTheme,
           evidenceReferences.contains(
            ObservationPYPTagReference(
                category: .transdisciplinaryTheme,
                value: proposedTheme.rawValue
            )
           ) {
            finalTags.transdisciplinaryTheme = proposedTheme
        }

        finalTags.keyConcepts = proposedConcepts
            .filter {
                evidenceReferences.contains(
                    ObservationPYPTagReference(category: .keyConcept, value: $0.rawValue)
                )
            }
            .prefix(2)
            .map { $0 }

        finalTags.atlSkills = proposedATL
            .filter {
                evidenceReferences.contains(
                    ObservationPYPTagReference(category: .atlSkill, value: $0.rawValue)
                )
            }
            .prefix(2)
            .map { $0 }

        finalTags.learnerProfile = proposedProfile
            .filter {
                evidenceReferences.contains(
                    ObservationPYPTagReference(category: .learnerProfile, value: $0.rawValue)
                )
            }
            .prefix(2)
            .map { $0 }

        let finalEvidence = evidenceSpans.filter {
            finalTags.contains(category: $0.category, value: $0.value)
        }

        return ObservationTaggingResult(
            tags: finalTags,
            confidence: min(max(response.confidence ?? 0, 0), 1),
            evidenceSpans: finalEvidence,
            pendingRetag: finalTags.isEmpty
        )
    }

    private func parseEvidenceSpan(
        _ evidence: EvidenceSpanResponse,
        transcript: String
    ) -> ObservationEvidenceSpan? {
        let normalizedQuote = evidence.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let category = ObservationPYPTagCategory(modelValue: evidence.category),
            let value = canonicalValue(for: evidence.value, category: category),
            normalizedQuote.isEmpty == false,
            transcript.localizedCaseInsensitiveContains(normalizedQuote),
            hasValidOffsets(evidence, transcript: transcript)
        else {
            return nil
        }

        return ObservationEvidenceSpan(
            category: category,
            value: value,
            quote: normalizedQuote,
            start: evidence.start,
            end: evidence.end
        )
    }

    private func hasValidOffsets(
        _ evidence: EvidenceSpanResponse,
        transcript: String
    ) -> Bool {
        guard let start = evidence.start, let end = evidence.end else {
            return true
        }

        guard start >= 0, end > start, end <= transcript.count else {
            return false
        }

        let startIndex = transcript.index(transcript.startIndex, offsetBy: start)
        let endIndex = transcript.index(transcript.startIndex, offsetBy: end)
        let offsetQuote = String(transcript[startIndex..<endIndex])

        return offsetQuote.localizedCaseInsensitiveContains(evidence.quote)
    }

    private func canonicalValue(for value: String, category: ObservationPYPTagCategory) -> String? {
        switch category {
        case .transdisciplinaryTheme:
            return PYPTheme(modelValue: value)?.rawValue
        case .keyConcept:
            return PYPKeyConcept(modelValue: value)?.rawValue
        case .atlSkill:
            return PYPATLSkillCluster(modelValue: value)?.rawValue
        case .learnerProfile:
            return PYPLearnerProfile(modelValue: value)?.rawValue
        }
    }
}

enum ObservationTaggingParserError: LocalizedError, Equatable, Sendable {
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Tagging response was not valid structured JSON."
        }
    }
}

private struct TaggingResponse: Decodable {
    let tags: TagBundleResponse
    let confidence: Double?
    let evidenceSpans: [EvidenceSpanResponse]
}

private struct TagBundleResponse: Decodable {
    let transdisciplinaryTheme: String?
    let keyConcepts: [String]
    let atlSkills: [String]
    let learnerProfile: [String]
}

private struct EvidenceSpanResponse: Decodable {
    let category: String
    let value: String
    let quote: String
    let start: Int?
    let end: Int?
}

private extension ObservationPYPTagCategory {
    init?(modelValue: String) {
        let normalizedValue = ObservationTagValueNormalizer.normalize(modelValue)
        switch normalizedValue {
        case "theme", "transdisciplinary theme", "transdisciplinarytheme":
            self = .transdisciplinaryTheme
        case "concept", "key concept", "key concepts", "keyconcept", "keyconcepts":
            self = .keyConcept
        case "atl", "atl skill", "atl skills", "atlskill", "atlskills":
            self = .atlSkill
        case "profile", "learner profile", "learnerprofile":
            self = .learnerProfile
        default:
            return nil
        }
    }
}
