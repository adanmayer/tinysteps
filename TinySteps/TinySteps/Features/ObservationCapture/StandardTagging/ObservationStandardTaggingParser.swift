import Foundation
import MBAPI

struct ObservationStandardTaggingParser: Sendable {
    private let maxSuggestions: Int

    init(maxSuggestions: Int = 4) {
        self.maxSuggestions = maxSuggestions
    }

    func parse(
        data: Data,
        transcript: String,
        candidatesByID: [String: MBStandardReference]
    ) throws -> ObservationStandardTaggingResult {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ObservationStandardTaggingParserError.missingTranscript
        }

        let normalizedData = normalizeJSON(data: data)
        let response = try decodeEnvelope(from: normalizedData)
        let tagIDs = deduplicatedCandidateIDs(response.standardTagIDs)
        let transcriptForMatch = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var evidenceByID: [String: [String]] = [:]
        for span in response.evidenceSpans {
            guard let validated = validateEvidence(span, transcript: transcriptForMatch, candidatesByID: candidatesByID) else {
                continue
            }

            var quotes = evidenceByID[validated.standardID] ?? []
            if quotes.contains(validated.quote) == false {
                quotes.append(validated.quote)
                evidenceByID[validated.standardID] = quotes
            }
        }

        var suggestions: [ObservationStandardTagSuggestion] = []
        for id in tagIDs where candidatesByID.keys.contains(id) && hasEvidence(for: id, in: evidenceByID) {
            let evidenceQuotes = evidenceByID[id] ?? []
            guard evidenceQuotes.isEmpty == false else { continue }
            guard let reference = candidatesByID[id] else { continue }

            suggestions.append(
                ObservationStandardTagSuggestion(
                    reference: reference,
                    selectionSource: .localAI,
                    evidenceQuotes: evidenceQuotes
                )
            )
        }

        let selectedSuggestions = suggestions
            .filter { referenceIDsAreAllowed($0.referenceID, candidatesByID: candidatesByID) }
            .prefix(maxSuggestions)

        return ObservationStandardTaggingResult(
            suggestions: Array(selectedSuggestions),
            confidence: clamp(response.confidence),
            pendingRetag: selectedSuggestions.isEmpty
        )
    }

    func parsePartialSuggestionIDs(
        from data: Data,
        candidatesByID: [String: MBStandardReference]
    ) -> [String] {
        guard let raw = String(data: data, encoding: .utf8) else { return [] }
        return parseEmbeddedArray(from: raw, candidatesByID: candidatesByID)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func decodeEnvelope(from data: Data) throws -> StandardTaggingResponse {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let unwrapped = unwrapEnvelope(jsonObject: json) else {
            throw ObservationStandardTaggingParserError.malformedEnvelope
        }
        guard let decoded = decodePayload(unwrapped) else {
            throw ObservationStandardTaggingParserError.malformedResponse
        }
        return decoded
    }

    private func unwrapEnvelope(jsonObject: Any) -> [String: Any]? {
        guard let root = jsonObject as? [String: Any] else { return nil }
        if root.keys.contains("standardTagIDs") {
            return root
        }

        let wrapperKeys: Set<String> = ["result", "data", "response", "output", "payload", "observation"]
        guard wrapperKeys.count == wrapperKeys.count else { return nil }
        if root.count == 1,
           let firstKey = root.keys.first,
           wrapperKeys.contains(firstKey),
           let wrapped = root[firstKey] as? [String: Any],
           wrapped.keys.contains("standardTagIDs") {
            return wrapped
        }

        return nil
    }

    private func decodePayload(_ raw: [String: Any]) -> StandardTaggingResponse? {
        guard
            let standardTagIDs = raw["standardTagIDs"] as? [String],
            let confidence = raw["confidence"] as? Double,
            let evidenceSpansRaw = raw["evidenceSpans"] as? [Any]
        else {
            return nil
        }

        let evidenceSpans: [StandardTaggingEvidenceSpan] = evidenceSpansRaw.compactMap { item in
            guard let itemObject = item as? [String: Any],
                  let standardID = itemObject["standardID"] as? String,
                  let quote = itemObject["quote"] as? String else {
                return nil
            }

            let start = itemObject["start"] as? Int
            let end = itemObject["end"] as? Int

            return StandardTaggingEvidenceSpan(standardID: standardID, quote: quote, start: start, end: end)
        }

        return StandardTaggingResponse(standardTagIDs: standardTagIDs, confidence: confidence, evidenceSpans: evidenceSpans)
    }

    private func deduplicatedCandidateIDs(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.compactMap { id in
            guard id.isEmpty == false, seen.contains(id) == false else {
                return nil
            }
            seen.insert(id)
            return id
        }
    }

    private func validateEvidence(
        _ span: StandardTaggingEvidenceSpan,
        transcript: String,
        candidatesByID: [String: MBStandardReference]
    ) -> StandardTaggingEvidenceSpan? {
        let quote = span.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard quote.isEmpty == false else { return nil }
        guard candidatesByID[span.standardID] != nil else { return nil }
        guard transcript.localizedCaseInsensitiveContains(quote) else { return nil }

        if let start = span.start, let end = span.end {
            guard start >= 0, end > start, end <= transcript.count else { return nil }
            let startIndex = transcript.index(transcript.startIndex, offsetBy: start)
            let endIndex = transcript.index(transcript.startIndex, offsetBy: end)
            let offsetQuote = String(transcript[startIndex..<endIndex])
            guard offsetQuote.localizedCaseInsensitiveContains(quote) else { return nil }
        }

        return StandardTaggingEvidenceSpan(
            standardID: span.standardID,
            quote: quote,
            start: span.start,
            end: span.end
        )
    }

    private func normalizeJSON(data: Data) -> Data {
        data
    }

    private func hasEvidence(for standardID: String, in evidenceByID: [String: [String]]) -> Bool {
        guard let quotes = evidenceByID[standardID] else {
            return false
        }

        return quotes.isEmpty == false
    }

    private func referenceIDsAreAllowed(_ referenceID: String, candidatesByID: [String: MBStandardReference]) -> Bool {
        candidatesByID.keys.contains(referenceID)
    }

    private func parseEmbeddedArray(from raw: String, candidatesByID: [String: MBStandardReference]) -> [String] {
        guard let range = raw.range(of: "\"standardTagIDs\"") else { return [] }
        guard let startBracket = raw[range.upperBound...].firstIndex(of: "[") else { return [] }
        let remainder = String(raw[raw.index(after: startBracket)...])
        guard let endBracket = remainder.firstIndex(of: "]") else { return [] }
        let inside = String(remainder[..<endBracket])
        return inside
            .split(separator: "\"")
            .compactMap { token in
                let cleaned = token
                    .trimmingCharacters(in: CharacterSet(charactersIn: ", []\n\t"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard candidatesByID.keys.contains(cleaned), cleaned.isEmpty == false else {
                    return nil
                }
                return cleaned
            }
    }
}

private struct StandardTaggingEvidenceSpan: Sendable {
    let standardID: String
    let quote: String
    let start: Int?
    let end: Int?
}

private struct StandardTaggingResponse: Sendable {
    let standardTagIDs: [String]
    let confidence: Double
    let evidenceSpans: [StandardTaggingEvidenceSpan]
}
