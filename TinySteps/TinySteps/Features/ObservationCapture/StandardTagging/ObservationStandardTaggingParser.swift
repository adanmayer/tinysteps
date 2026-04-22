import Foundation
import MBAPI
import os

private let standardTaggingParserLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TinySteps",
    category: "ObservationStandardTaggingParser"
)

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
        if response.standardTagIDs.isEmpty {
            standardTaggingParserLogger.debug("Standard tagging response had zero standardTagIDs; returning no AI suggestions.")
        }
        let tagIDs = deduplicatedCandidateIDs(response.standardTagIDs)
        let transcriptForMatch = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let transcriptTokens = tokenSet(for: transcriptForMatch)

        guard transcriptTokens.count >= 2 else {
            standardTaggingParserLogger.debug("Skipping standard tagging suggestions: transcript token count is too low (\(transcriptTokens.count)).")
            return ObservationStandardTaggingResult(
                suggestions: [],
                confidence: 0,
                pendingRetag: true
            )
        }

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
            guard referencesTranscript(reference, tokens: transcriptTokens) else { continue }

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
        var parsed = parseEmbeddedArray(
            from: raw,
            candidatesByID: candidatesByID,
            key: "standardTagIDs"
        )

        if parsed.isEmpty {
            parsed = parseEmbeddedArray(
                from: raw,
                candidatesByID: candidatesByID,
                key: "selectedStandards"
            )
        }

        return parsed
    }

    func parseVisibleSuggestionIDs(
        from data: Data,
        transcript: String,
        candidatesByID: [String: MBStandardReference]
    ) -> [String] {
        let candidateIDs = parsePartialSuggestionIDs(
            from: data,
            candidatesByID: candidatesByID
        )

        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcriptTokens = tokenSet(for: trimmedTranscript)
        guard transcriptTokens.count >= 2 else {
            return []
        }

        var filtered: [String] = []
        var seen = Set<String>()

        for candidateID in candidateIDs {
            guard seen.insert(candidateID).inserted else { continue }
            guard let reference = candidatesByID[candidateID] else { continue }
            let referenceTokens = Set(referenceTokens(for: reference))
            guard referenceTokens.intersection(transcriptTokens).isEmpty == false else {
                continue
            }
            filtered.append(candidateID)
        }

        return filtered
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func decodeEnvelope(from data: Data) throws -> StandardTaggingResponse {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let unwrapped = unwrapEnvelope(jsonObject: json) else {
            throw ObservationStandardTaggingParserError.malformedEnvelope
        }
        let normalized = normalizeSchemaKeys(unwrapped)
        let decoded = decodePayload(normalized)
        return decoded
    }

    private func unwrapEnvelope(jsonObject: Any) -> [String: Any]? {
        guard let root = jsonObject as? [String: Any] else { return nil }
        if root.keys.contains("standardTagIDs") {
            return root
        }
        if root.keys.contains("selectedStandards") {
            return root
        }

        if let message = root["message"] as? [String: Any],
           let content = message["content"] as? String,
           let normalized = normalizeJSON(from: content),
           let parsed = try? JSONSerialization.jsonObject(with: normalized) as? [String: Any],
           let unwrapped = unwrapEnvelope(jsonObject: parsed) {
            return unwrapped
        }

        for wrapperKey in ["result", "data", "response", "output", "payload", "observation", "message"] {
            guard let wrapped = root[wrapperKey] else { continue }

            if let wrappedDict = wrapped as? [String: Any],
               let unwrapped = unwrapEnvelope(jsonObject: wrappedDict) {
                return unwrapped
            }

            if let wrappedString = wrapped as? String,
               let normalized = normalizeJSON(from: wrappedString),
               let parsed = try? JSONSerialization.jsonObject(with: normalized) as? [String: Any],
               let unwrapped = unwrapEnvelope(jsonObject: parsed) {
                return unwrapped
            }
        }

        if root.count == 1,
           let firstKey = root.keys.first,
           let wrapped = root[firstKey] as? [String: Any],
           let unwrapped = unwrapEnvelope(jsonObject: wrapped) {
            return unwrapped
        }

        return nil
    }

    private func normalizeSchemaKeys(_ payload: [String: Any]) -> [String: Any] {
        guard payload.keys.contains("standardTagIDs") == false else {
            return payload
        }

        var normalized = payload

        if normalized["standardTagIDs"] == nil,
           let selected = normalized["selectedStandards"] {
            normalized["standardTagIDs"] = selected
            standardTaggingParserLogger.debug("Normalized legacy field 'selectedStandards' to 'standardTagIDs'.")
        }
        if normalized["standardTagIDs"] == nil,
           let candidates = normalized["standardStandardIDs"] {
            normalized["standardTagIDs"] = candidates
            standardTaggingParserLogger.debug("Normalized legacy field 'standardStandardIDs' to 'standardTagIDs'.")
        }

        if normalized["confidence"] == nil,
           let confidence = normalized["confidenceScore"] {
            normalized["confidence"] = confidence
            standardTaggingParserLogger.debug("Normalized legacy field 'confidenceScore' to 'confidence'.")
        }
        if normalized["evidenceSpans"] == nil,
           let evidence = normalized["evidence"] {
            normalized["evidenceSpans"] = evidence
            standardTaggingParserLogger.debug("Normalized legacy field 'evidence' to 'evidenceSpans'.")
        }

        return normalized
    }

    private func decodePayload(_ raw: [String: Any]) -> StandardTaggingResponse {
        let standardTagIDs = parseStandardTagIDs(raw["standardTagIDs"]) ?? []
        let confidence = parseConfidence(raw["confidence"]) ?? 0
        let evidenceSpansRaw = (raw["evidenceSpans"] as? [Any]) ?? []

        let evidenceSpans: [StandardTaggingEvidenceSpan] = evidenceSpansRaw.compactMap { item in
            guard let itemObject = item as? [String: Any],
                  let standardID = parseString(itemObject["standardID"]),
                  let quote = itemObject["quote"] as? String else {
                return nil
            }

            let start = parseInt(itemObject["start"])
            let end = parseInt(itemObject["end"])

            return StandardTaggingEvidenceSpan(standardID: standardID, quote: quote, start: start, end: end)
        }

        return StandardTaggingResponse(standardTagIDs: standardTagIDs, confidence: confidence, evidenceSpans: evidenceSpans)
    }

    private func parseStandardTagIDs(_ raw: Any?) -> [String]? {
        guard let raw = raw else { return nil }
        if let rawIDs = raw as? [Any] {
            var ids: [String] = []
            for idValue in rawIDs {
                if let normalized = parseString(idValue),
                   normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    ids.append(normalized)
                }
            }
            return ids
        }

        guard let rawID = parseString(raw) else {
            return nil
        }

        let trimmedRawID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRawID.isEmpty == false else { return nil }

        if let start = trimmedRawID.firstIndex(of: "["),
           let end = trimmedRawID.lastIndex(of: "]") {
            let list = String(trimmedRawID[trimmedRawID.index(after: start)...trimmedRawID.index(before: end)])
            let extracted = list
                .split(separator: "\"")
                .compactMap { (token: Substring) -> String? in
                    let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ", []\n\t"))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard cleaned.isEmpty == false else { return nil }
                    return cleaned
                }
            return extracted
        } else if trimmedRawID.isEmpty == false {
            return [trimmedRawID]
        }

        return nil
    }

    private func parseConfidence(_ raw: Any?) -> Double? {
        if let value = raw as? Double {
            return value
        }
        if let value = raw as? Int {
            return Double(value)
        }
        if let value = raw as? NSNumber {
            return value.doubleValue
        }
        if let value = raw as? String {
            return Double(value)
        }
        return nil
    }

    private func parseString(_ raw: Any?) -> String? {
        if let stringValue = raw as? String { return stringValue }
        if let numberValue = raw as? NSNumber { return numberValue.stringValue }
        return nil
    }

    private func parseInt(_ raw: Any?) -> Int? {
        if let intValue = raw as? Int { return intValue }
        if let numberValue = raw as? NSNumber { return numberValue.intValue }
        if let stringValue = raw as? String { return Int(stringValue) }
        return nil
    }

    private func normalizeJSON(from source: String) -> Data? {
        var cleaned = source
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(cleaned[start...end])
        return jsonString.data(using: .utf8)
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

        var validStart: Int?
        var validEnd: Int?

        if let start = span.start, let end = span.end {
            guard start >= 0, end > start, end <= transcript.count else {
                return StandardTaggingEvidenceSpan(
                    standardID: span.standardID,
                    quote: quote,
                    start: nil,
                    end: nil
                )
            }
            let startIndex = transcript.index(transcript.startIndex, offsetBy: start)
            let endIndex = transcript.index(transcript.startIndex, offsetBy: end)
            let offsetQuote = String(transcript[startIndex..<endIndex])
            if offsetQuote.localizedCaseInsensitiveContains(quote) {
                validStart = start
                validEnd = end
            }
        }

        return StandardTaggingEvidenceSpan(
            standardID: span.standardID,
            quote: quote,
            start: validStart,
            end: validEnd
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

    private func referencesTranscript(
        _ candidateTokens: Set<String>,
        intersects transcriptTokens: Set<String>
    ) -> Bool {
        guard transcriptTokens.isEmpty == false else {
            return false
        }
        guard candidateTokens.isEmpty == false else {
            return false
        }
        return candidateTokens.intersection(transcriptTokens).isEmpty == false
    }

    private func referencesTranscript(_ reference: MBStandardReference, tokens transcriptTokens: Set<String>) -> Bool {
        return referencesTranscript(
            referenceTokens(for: reference),
            intersects: transcriptTokens
        )
    }

    private func referenceTokens(for reference: MBStandardReference) -> Set<String> {
        let content = [
            reference.title,
            reference.code,
            reference.detail,
            reference.displayHashtag
        ].compactMap { $0 }.joined(separator: " ")

        return tokenSet(for: content)
    }

    private func tokenSet(for text: String) -> Set<String> {
        Set(tokens(from: text))
    }

    private func tokens(from text: String) -> [String] {
        expandedForTokenization(text)
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
    }

    private func expandedForTokenization(_ text: String) -> String {
        var result = ""
        var previous: Character?

        for character in text {
            if let previous,
               previous.isLowercase || previous.isNumber,
               character.isUppercase {
                result.append(" ")
            }

            result.append(character)
            previous = character
        }

        return result
    }

    private func referenceIDsAreAllowed(_ referenceID: String, candidatesByID: [String: MBStandardReference]) -> Bool {
        candidatesByID.keys.contains(referenceID)
    }

    private func parseEmbeddedArray(
        from raw: String,
        candidatesByID: [String: MBStandardReference],
        key: String
    ) -> [String] {
        guard let range = raw.range(of: "\"\(key)\"") else { return [] }
        guard let startBracket = raw[range.upperBound...].firstIndex(of: "[") else { return [] }
        let remainder = String(raw[raw.index(after: startBracket)...])
        let inside: String
        if let endBracket = remainder.firstIndex(of: "]") {
            inside = String(remainder[..<endBracket])
        } else {
            inside = remainder
        }
        let values = inside
            .split(separator: "\"")
            .compactMap { (token: Substring) -> String? in
                let cleaned = String(token)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ", []\n\t"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard candidatesByID.keys.contains(cleaned), cleaned.isEmpty == false else {
                    return nil
                }
                return cleaned
            }

        return deduplicatedCandidateIDs(values)
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
