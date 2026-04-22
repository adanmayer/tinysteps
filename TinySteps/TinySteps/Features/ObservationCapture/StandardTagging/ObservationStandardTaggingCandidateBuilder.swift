import Foundation

struct ObservationStandardTaggingCandidateBuilder {
    private let commonWordMinLength = 2

    func buildCandidates(
        from unitSection: MBStandardUnitSection,
        transcript: String,
        maxCandidates: Int
    ) -> [ObservationStandardTagCandidate] {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcriptTokens = transcriptTokens(from: cleanedTranscript)
        let persistableReferences = unitSection.references.filter(\.sourceIdentity.isPersistable)
        let pypThemes = persistableReferences.filter { $0.kind == .pypTheme }
        let nonThemes = persistableReferences.filter { $0.kind != .pypTheme }

        let ranked = nonThemes
            .uniqueByID()
            .map { reference in
                (
                    reference: reference,
                    score: lexicalScore(reference: reference, transcriptTokens: transcriptTokens)
                )
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.reference.sourceID < $1.reference.sourceID
                }
                return $0.score > $1.score
            }
            .prefix(max(0, maxCandidates - pypThemes.count))
            .map(\.reference)

        var selected = [MBStandardReference]()
        selected.append(contentsOf: ranked)
        selected.append(contentsOf: pypThemes)

        return selected
            .uniqueByID()
            .prefix(maxCandidates)
            .map { reference in
                ObservationStandardTagCandidate(
                    id: reference.id,
                    kind: reference.kind,
                    sourceID: reference.sourceID,
                    unitID: reference.unitID,
                    unitTitle: reference.unitTitle,
                    classID: reference.classID,
                    className: "",
                    programCode: reference.programCode,
                    code: reference.code,
                    title: taggingTitle(for: reference),
                    detail: reference.detail,
                    displayHashtag: reference.displayHashtag,
                    sourceIdentity: reference.sourceIdentity,
                    stableIdentity: reference.stableIdentity
                )
            }
    }

    func candidatePreviewHashtags(for references: [MBStandardReference]) -> [String] {
        Array(
            references
                .filter(\.sourceIdentity.isPersistable)
                .uniqueByID()
                .compactMap(\.displayHashtag)
                .prefix(4)
        )
    }

    private func lexicalScore(reference: MBStandardReference, transcriptTokens: Set<String>) -> Int {
        guard transcriptTokens.isEmpty == false else { return 0 }

        let referenceWords = Set(
            tokens(
                from: [reference.code, reference.title, reference.detail, reference.displayHashtag].compactMap { $0 }.joined(separator: " ")
            )
        )
        return transcriptTokens.intersection(referenceWords).count
    }

    private func transcriptTokens(from text: String) -> Set<String> {
        guard text.isEmpty == false else { return [] }
        return Set(
            tokens(from: text)
                .filter { $0.count >= commonWordMinLength }
        )
    }

    private func tokens(from text: String) -> [String] {
        expandedForTokenization(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .compactMap { token in
                let trimmed = token
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return nil }
                return trimmed
            }
    }

    private func taggingTitle(for reference: MBStandardReference) -> String {
        guard reference.kind == .pypTheme,
              reference.isUnresolvedTheme,
              let title = titleFromHashtag(reference.displayHashtag) else {
            return reference.title
        }

        return title
    }

    private func titleFromHashtag(_ hashtag: String) -> String? {
        let words = tokens(from: hashtag)
            .filter { $0 != "ref" && $0 != "pyp" && $0 != "theme" }

        guard words.isEmpty == false else {
            return nil
        }

        return words
            .map { word in
                guard let first = word.first else { return word }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
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
}

private extension Array where Element == MBStandardReference {
    func uniqueByID() -> [MBStandardReference] {
        var seen: Set<String> = []
        return filter {
            guard seen.contains($0.id) == false else { return false }
            seen.insert($0.id)
            return true
        }
    }
}
