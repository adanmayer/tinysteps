import Foundation

protocol MBStandardHashtagGenerating: Sendable {
    func hashtags(for references: [MBStandardReference]) async -> [String: String]
}

struct MBStandardHashtagGenerator: MBStandardHashtagGenerating, Sendable {
    private static let maxHashtagLength = 24
    private static let collisionAttemptSuffixLimit = 4

    func hashtags(for references: [MBStandardReference]) async -> [String: String] {
        var resolvedTags: [String: String] = [:]
        var usedTags: Set<String> = []

        for reference in references {
            let fallbackBase = fallbackHashtag(for: reference)
            let base = sanitize(fallbackBase)
            let unique = uniquefy(
                referenceID: reference.sourceID,
                requestedTag: base,
                usedTags: &usedTags
            )
            resolvedTags[reference.id] = unique
        }

        return resolvedTags
    }

    private func fallbackHashtag(for reference: MBStandardReference) -> String {
        let codeCandidate = sanitizedToken(reference.code)
        let meaningfulWords = meaningfulWords(from: reference.title)

        var components = meaningfulWords

        if let codeCandidate, codeCandidate.isEmpty == false, components.count <= 2 {
            components = [codeCandidate] + components
        }

        if components.isEmpty {
            components = [reference.sourceID]
        }

        let hashtagBase = components
            .prefix(3)
            .compactMap { sanitizedToken($0) }
            .map(styleHashtagWord)
            .joined()

        if hashtagBase.isEmpty {
            return "#Ref\(reference.sourceID.suffix(4))"
        }

        return "#\(hashtagBase.prefix(Self.maxHashtagLength - 1))"
    }

    private func sanitize(_ tag: String) -> String {
        let parsed = tag.first == "#" ? String(tag.dropFirst()) : tag

        let sanitizedCore = parsed
            .compactMap { $0.unicodeScalars.first }
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(Character.init)
            .map(String.init)
            .joined()

        if sanitizedCore.isEmpty {
            return "#Ref"
        }

        return "#\(trimLength(sanitizedCore))"
    }

    private func trimLength(_ value: String, allowanceForHash: Int = 1) -> String {
        let maxLength = Self.maxHashtagLength - allowanceForHash
        if value.count <= maxLength {
            return value
        }

        return String(value.prefix(maxLength))
    }

    private func uniquefy(referenceID: String, requestedTag: String, usedTags: inout Set<String>) -> String {
        guard usedTags.contains(requestedTag) == false else {
            return resolveCollision(referenceID: referenceID, requestedTag: requestedTag, usedTags: &usedTags)
        }

        usedTags.insert(requestedTag)
        return requestedTag
    }

    private func resolveCollision(referenceID: String, requestedTag: String, usedTags: inout Set<String>) -> String {
        let core = requestedTag.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let seed = collisionSuffix(from: referenceID)
        var attempt = 1

        while attempt <= Self.collisionAttemptSuffixLimit {
            let suffix = "\(seed)\(attempt > 1 ? String(attempt) : "")"
            let suffixCore = trimLength(core + suffix, allowanceForHash: 1)
            let tagged = "#\(suffixCore)"

            if usedTags.contains(tagged) == false {
                usedTags.insert(tagged)
                return tagged
            }

            attempt += 1
        }

        let fallback = String(requestedTag.dropFirst()).prefix(Self.maxHashtagLength - 8)
        let fallbackTag = "#\(fallback)"
        usedTags.insert(fallbackTag)
        return fallbackTag
    }

    private func collisionSuffix(from referenceID: String) -> String {
        let cleaned = referenceID
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        if cleaned.isEmpty {
            return "X"
        }

        return String(cleaned.prefix(3).uppercased())
    }

    private func meaningfulWords(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .filter { sanitizedToken($0) != nil }
    }

    private func sanitizedToken(_ raw: String?) -> String? {
        guard let raw else {
            return nil
        }

        let cleaned = raw
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        guard let first = cleaned.first else {
            return nil
        }

        let normalized = cleaned.lowercased()
        let rest = normalized.dropFirst()
        return String(first).uppercased() + rest
    }

    private func styleHashtagWord(_ raw: String) -> String {
        guard let styled = sanitizedToken(raw), styled.isEmpty == false else {
            return ""
        }

        return styled
    }
}
