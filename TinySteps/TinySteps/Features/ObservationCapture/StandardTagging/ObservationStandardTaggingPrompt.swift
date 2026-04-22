import Foundation

enum ObservationStandardTaggingPrompt {
    static let systemPrompt = """
You are an assistant that maps classroom observation transcripts to standards.
Only return JSON with no additional commentary.

Rules:
- Choose only standard IDs from the provided candidate list.
- Use evidence from the transcript for every selected standard.
- Return up to 4 standard IDs in the order of strongest relevance.
- Do not invent new IDs, hashtags, titles, or labels.
- Do not return the same standard twice.
- Skip any standard that is not explicitly evidenced by the transcript.
"""

    struct ObservationStandardTaggingPayload: Codable, Sendable {
        var transcript: String
        let classContext: ClassContext
        let selectedUnit: UnitContext
        let candidates: [CandidateContext]
        let rules: RulesContext

        struct ClassContext: Codable, Sendable {
            let id: String
            let name: String
        }

        struct UnitContext: Codable, Sendable {
            let id: String
            let title: String
        }

        struct CandidateContext: Codable, Sendable {
            let id: String
            let kind: String
            let sourceID: String
            let code: String?
            let hashtag: String
            let title: String
            let detail: String?
            let unitID: String
        }

        struct RulesContext: Codable, Sendable {
            let maxSelections: Int
            let requireEvidenceQuote: Bool
            let returnOnlyCandidateIDs: Bool
        }
    }

    static func payload(
        classID: String,
        className: String,
        selectedUnitID: String,
        selectedUnitTitle: String,
        transcript: String,
        candidates: [ObservationStandardTagCandidate],
        maxSuggestions: Int
    ) -> ObservationStandardTaggingPayload {
        ObservationStandardTaggingPayload(
            transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            classContext: .init(id: classID, name: className),
            selectedUnit: .init(id: selectedUnitID, title: selectedUnitTitle),
            candidates: candidates.map { candidate in
                ObservationStandardTaggingPayload.CandidateContext(
                    id: candidate.id,
                    kind: candidate.kind.rawValue,
                    sourceID: candidate.sourceID,
                    code: candidate.code,
                    hashtag: candidate.displayHashtag,
                    title: candidate.title,
                    detail: candidate.detail,
                    unitID: candidate.unitID
                )
            },
            rules: .init(
                maxSelections: maxSuggestions,
                requireEvidenceQuote: true,
                returnOnlyCandidateIDs: true
            )
        )
    }

    static func payloadString(from payload: ObservationStandardTaggingPayload) -> String? {
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            return nil
        }
        return String(data: payloadData, encoding: .utf8)
    }
}
