import Foundation

enum ObservationStandardTaggingSchema {
    static func make(candidateIDs: [String], maxSuggestions: Int) -> [String: Any] {
        let uniqueCandidateIDs = Array(NSOrderedSet(array: candidateIDs)) as? [String] ?? candidateIDs

        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["standardTagIDs", "confidence", "evidenceSpans"],
            "properties": [
                "standardTagIDs": [
                    "type": "array",
                    "maxItems": maxSuggestions,
                    "items": [
                        "type": "string",
                        "enum": uniqueCandidateIDs
                    ] as [String: Any],
                    "description": "Up to the top-k supported standard IDs."
                ] as [String: Any],
                "confidence": [
                    "type": "number",
                    "minimum": 0.0,
                    "maximum": 1.0,
                    "description": "Confidence 0 to 1 for current standard suggestions."
                ] as [String: Any],
                "evidenceSpans": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["standardID", "quote"],
                        "properties": [
                            "standardID": [
                                "type": "string",
                                "enum": uniqueCandidateIDs
                            ] as [String: Any],
                            "quote": [
                                "type": "string",
                                "minLength": 2,
                                "description": "Phrase copied verbatim from transcript."
                            ] as [String: Any],
                            "start": [
                                "type": "integer",
                                "minimum": 0,
                                "description": "Optional zero-based start index."
                            ] as [String: Any],
                            "end": [
                                "type": "integer",
                                "minimum": 1,
                                "description": "Optional exclusive end index."
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
    }
}
