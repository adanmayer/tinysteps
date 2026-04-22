import Foundation
import os

enum ObservationStandardTaggingServiceError: Error {
    case noCandidates
}

private let standardTaggingLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TinySteps",
    category: "ObservationStandardTagging"
)

struct DisabledObservationStandardTaggingService: ObservationStandardTaggingService {
    func suggestStandardTags(
        request: ObservationStandardTaggingRequest
    ) -> AsyncThrowingStream<ObservationStandardTaggingEvent, Error> {
        standardTaggingLogger.warning(
            "Standard tagging disabled. Falling back to manual tagging for classID=\(request.classID, privacy: .public), unitID=\(request.selectedUnitID, privacy: .public)"
        )

        return AsyncThrowingStream(
            bufferingPolicy: .unbounded
        ) { continuation in
            continuation.yield(ObservationStandardTaggingEvent.unavailable)
            continuation.finish()
        }
    }
}

struct OllamaObservationStandardTaggingService: ObservationStandardTaggingService {
    private let configuration: LocalObservationStandardTaggingConfiguration
    private let client: StandardTaggingOllamaClient
    private let parser: ObservationStandardTaggingParser

    init(configuration: LocalObservationStandardTaggingConfiguration) {
        self.configuration = configuration
        self.client = StandardTaggingOllamaClient(
            hostURL: configuration.ollamaHost,
            timeout: configuration.requestTimeout
        )
        self.parser = ObservationStandardTaggingParser(maxSuggestions: configuration.maxSuggestedStandards)
    }

    func suggestStandardTags(
        request: ObservationStandardTaggingRequest
    ) -> AsyncThrowingStream<ObservationStandardTaggingEvent, Error> {
        AsyncThrowingStream(
            bufferingPolicy: .unbounded
        ) { continuation in
            Task {
                do {
                    if request.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        standardTaggingLogger.debug("Skipping standard tagging: transcript empty.")
                        continuation.yield(.suggestions(
                            ObservationStandardTaggingResult(
                                suggestions: [],
                                confidence: 0,
                                pendingRetag: true
                            )
                        ))
                        continuation.finish()
                        return
                    }

                    if request.candidates.isEmpty {
                        standardTaggingLogger.info("Standard tagging unavailable for classID=\(request.classID, privacy: .public), unitID=\(request.selectedUnitID, privacy: .public): no candidates.")
                        continuation.yield(ObservationStandardTaggingEvent.unavailable)
                        continuation.finish()
                        return
                    }

                    let schema = ObservationStandardTaggingSchema.make(
                        candidateIDs: request.candidates.map(\.id),
                        maxSuggestions: configuration.maxSuggestedStandards
                    )

                    let payloadTemplate = ObservationStandardTaggingPrompt.ObservationStandardTaggingPayload(
                        transcript: "",
                        classContext: .init(
                            id: request.classID,
                            name: request.className
                        ),
                        selectedUnit: .init(
                            id: request.selectedUnitID,
                            title: request.selectedUnitTitle
                        ),
                        candidates: request.candidates.map {
                            ObservationStandardTaggingPrompt.ObservationStandardTaggingPayload.CandidateContext(
                                id: $0.id,
                                kind: $0.kind.rawValue,
                                sourceID: $0.sourceID,
                                sourceIdentity: $0.sourceIdentity.stableKey,
                                code: $0.code,
                                hashtag: $0.displayHashtag,
                                title: $0.title,
                                detail: $0.detail,
                                unitID: $0.unitID
                            )
                        },
                        rules: .init(
                            maxSelections: configuration.maxSuggestedStandards,
                            requireEvidenceQuote: true,
                            returnOnlyCandidateIDs: true
                        )
                    )

                    guard let userPayloadString = ObservationStandardTaggingPayloadBuilder.make(
                        template: payloadTemplate,
                        transcript: request.transcript
                    ) else {
                        standardTaggingLogger.error("Standard tagging payload serialization failed for classID=\(request.classID, privacy: .public), unitID=\(request.selectedUnitID, privacy: .public).")
                        continuation.finish(throwing: StandardTaggingOllamaError.invalidResponse(statusCode: -1, body: "Cannot build payload"))
                        return
                    }

                    let messages = [
                        StandardTaggingOllamaMessage(
                            role: "system",
                            content: ObservationStandardTaggingPrompt.systemPrompt
                        ),
                        StandardTaggingOllamaMessage(
                            role: "user",
                            content: userPayloadString
                        )
                    ]

                    let stream = client.streamChat(
                        model: configuration.model,
                        messages: messages,
                        format: schema,
                        options: .qwen3Structured(seed: 42),
                        think: configuration.think
                    )

                    var accumulator = Data()
                    for try await chunk in stream {
                        accumulator.append(chunk)
                    }

                    let parsed = try parser.parse(
                        data: accumulator,
                        transcript: request.transcript,
                        candidatesByID: request.candidateLookup
                    )
                    continuation.yield(.suggestions(parsed))
                    continuation.finish()
                } catch {
                    if isAvailabilityError(error) || isRecoverableModelError(error) {
                        standardTaggingLogger.error("Standard tagging service availability error for classID=\(request.classID, privacy: .public), unitID=\(request.selectedUnitID, privacy: .public).")
                        continuation.yield(ObservationStandardTaggingEvent.unavailable)
                        continuation.finish()
                    } else {
                        standardTaggingLogger.error("Standard tagging failed with non-recoverable error for classID=\(request.classID, privacy: .public), unitID=\(request.selectedUnitID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    private func isAvailabilityError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            if case StandardTaggingOllamaError.transport = error {
                return true
            }
            return false
        }

        switch urlError.code {
        case .notConnectedToInternet,
             .timedOut,
             .cannotConnectToHost,
             .networkConnectionLost,
             .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private func isRecoverableModelError(_ error: Error) -> Bool {
        if error is ObservationStandardTaggingParserError {
            return true
        }
        if case StandardTaggingOllamaError.decodingFailed = error {
            return true
        }
        if case StandardTaggingOllamaError.invalidResponse(_, _) = error {
            return true
        }
        if case StandardTaggingOllamaError.transport = error {
            return true
        }

        return false
    }
}

private enum ObservationStandardTaggingPayloadBuilder {
    static func make(template: ObservationStandardTaggingPrompt.ObservationStandardTaggingPayload, transcript: String) -> String? {
        var updated = template
        updated.transcript = transcript
        guard let payloadData = try? JSONEncoder().encode(updated) else {
            return nil
        }
        return String(data: payloadData, encoding: .utf8)
    }
}
