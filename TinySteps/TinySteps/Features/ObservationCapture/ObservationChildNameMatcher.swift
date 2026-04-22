import Foundation

protocol ObservationChildNameMatching: Sendable {
    func matchChildren(
        in transcript: String,
        roster: [ObservationRosterStudent]
    ) -> [ObservationMatchedChild]
}

struct LocalObservationChildNameMatcher: ObservationChildNameMatching {
    let allowsFuzzyMatching: Bool

    init(allowsFuzzyMatching: Bool = false) {
        self.allowsFuzzyMatching = allowsFuzzyMatching
    }

    func matchChildren(
        in transcript: String,
        roster: [ObservationRosterStudent]
    ) -> [ObservationMatchedChild] {
        let transcriptTokens = tokenize(transcript)
        guard transcriptTokens.isEmpty == false else {
            return []
        }

        let aliases = aliasMap(for: roster)
        var matchedByKey: [String: ObservationMatchedChild] = [:]

        for alias in aliases.keys.sorted(by: { $0.count > $1.count }) {
            guard let students = aliases[alias], students.count == 1 else {
                continue
            }

            let aliasTokens = alias.split(separator: " ").map(String.init)
            guard contains(aliasTokens: aliasTokens, in: transcriptTokens) else {
                continue
            }

            let student = students[0]
            matchedByKey[student.studentKey] = ObservationMatchedChild(
                studentKey: student.studentKey,
                displayName: student.displayName,
                matchText: alias,
                confidence: 1
            )
        }

        return matchedByKey.values.sorted { $0.displayName < $1.displayName }
    }

    private func aliasMap(for roster: [ObservationRosterStudent]) -> [String: [ObservationRosterStudent]] {
        var aliases: [String: [ObservationRosterStudent]] = [:]

        for student in roster {
            let candidates = [
                student.firstName,
                student.displayName
            ]

            for candidate in candidates {
                let alias = tokenize(candidate).joined(separator: " ")
                guard alias.isEmpty == false else {
                    continue
                }
                aliases[alias, default: []].append(student)
            }
        }

        return aliases
    }

    private func contains(aliasTokens: [String], in transcriptTokens: [String]) -> Bool {
        guard aliasTokens.isEmpty == false, transcriptTokens.count >= aliasTokens.count else {
            return false
        }

        for startIndex in transcriptTokens.indices {
            let endIndex = startIndex + aliasTokens.count
            guard endIndex <= transcriptTokens.count else {
                return false
            }

            if Array(transcriptTokens[startIndex..<endIndex]) == aliasTokens {
                return true
            }
        }

        return false
    }

    private func tokenize(_ text: String) -> [String] {
        let normalizedText = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return normalizedText
            .replacingOccurrences(
                of: #"[']s\b|[’]s\b"#,
                with: "",
                options: .regularExpression
            )
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
