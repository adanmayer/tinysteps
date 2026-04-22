import Foundation

struct LocalObservationStandardTaggingConfiguration: Sendable {
    let ollamaHost: URL
    let model: String
    let requestTimeout: TimeInterval
    let maxSuggestedStandards: Int
    let maxCandidates: Int
    let think: Bool?

    init(
        ollamaHost: URL,
        model: String = "qwen3.5:35b-a3b",
        requestTimeout: TimeInterval = 120,
        maxSuggestedStandards: Int = 4,
        maxCandidates: Int = 40,
        think: Bool? = false
    ) {
        self.ollamaHost = ollamaHost
        self.model = model
        self.requestTimeout = requestTimeout
        self.maxSuggestedStandards = max(1, maxSuggestedStandards)
        self.maxCandidates = max(1, maxCandidates)
        self.think = think
    }

    static func defaultHost() -> URL {
        URL(string: "http://192.168.14.108:11434") ?? URL(string: "http://127.0.0.1:11434")!
    }

    static func resolveEnabled(
        hostOverride: String? = nil,
        enabledOverride: String? = nil
    ) -> LocalObservationStandardTaggingConfiguration? {
        let explicitEnabled = (enabledOverride ?? ProcessInfo.processInfo.environment["TS_STANDARD_TAGGING_LOCAL_AI"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if explicitEnabled.isEmpty == false,
           ["0", "false", "off", "no", "disabled", "disable"].contains(explicitEnabled) {
            return nil
        }

        let hostOverrideValue = hostOverride ?? ProcessInfo.processInfo.environment["TS_STANDARD_TAGGING_LOCAL_AI_HOST"]

        #if DEBUG
        let resolvedHost = URL(string: hostOverrideValue ?? "")
            ?? defaultHost()
        #else
        guard
            explicitEnabled.isEmpty == false,
            let explicitHost = URL(string: hostOverrideValue ?? ""),
            explicitHost.scheme?.isEmpty == false
        else {
            return nil
        }
        let resolvedHost = explicitHost
        #endif

        return LocalObservationStandardTaggingConfiguration(
            ollamaHost: resolvedHost,
            maxSuggestedStandards: 4,
            maxCandidates: 40
        )
    }
}

enum StandardTaggingServiceError: LocalizedError {
    case disabled
    case unavailable

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Standard tagging is not enabled."
        case .unavailable:
            return "Standard tagging service is currently unavailable."
        }
    }
}
