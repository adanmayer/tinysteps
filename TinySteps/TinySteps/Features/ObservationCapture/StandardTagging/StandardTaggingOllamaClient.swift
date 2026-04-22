import Foundation

struct StandardTaggingOllamaMessage: Sendable {
    let role: String
    let content: String
}

struct StandardTaggingOllamaOptions: Sendable {
    let temperature: Double
    let seed: Int
    let topP: Double
    let topK: Int
    let minP: Double
    let presencePenalty: Double
    let repeatPenalty: Double

    static func qwen3Structured(seed: Int = 42) -> StandardTaggingOllamaOptions {
        StandardTaggingOllamaOptions(
            temperature: 0.3,
            seed: seed,
            topP: 0.8,
            topK: 20,
            minP: 0.0,
            presencePenalty: 0.0,
            repeatPenalty: 1.1
        )
    }
}

struct StandardTaggingOllamaResponse: Decodable, Sendable {
    struct Message: Decodable, Sendable {
        let content: String
    }

    let message: Message
    let done: Bool
}

enum StandardTaggingOllamaError: LocalizedError, Error {
    case invalidResponse(statusCode: Int, body: String)
    case decodingFailed(underlying: Error, body: String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let code, let body):
            return "HTTP \(code): \(body.prefix(250))"
        case .decodingFailed(let err, let body):
            return "decode failed: \(err) • \(body.prefix(250))"
        case .transport(let error):
            return "transport: \(error)"
        }
    }
}

struct StandardTaggingOllamaClient {
    private let hostURL: URL
    private let session: URLSession

    init(hostURL: URL, timeout: TimeInterval) {
        self.hostURL = hostURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    func version() async throws -> String {
        struct VersionResponse: Decodable { let version: String }
        let url = hostURL.appendingPathComponent("api/version")
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(VersionResponse.self, from: data)
        return response.version
    }

    func streamChat(
        model: String,
        messages: [StandardTaggingOllamaMessage],
        format: [String: Any],
        options: StandardTaggingOllamaOptions,
        think: Bool?
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            var request = URLRequest(url: hostURL.appendingPathComponent("api/chat"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            var body: [String: Any] = [
                "model": model,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
                "format": format,
                "stream": true,
                "options": [
                    "temperature": options.temperature,
                    "seed": options.seed,
                    "top_p": options.topP,
                    "top_k": options.topK,
                    "min_p": options.minP,
                    "presence_penalty": options.presencePenalty,
                    "repeat_penalty": options.repeatPenalty
                ]
            ]
            if let think {
                body["think"] = think
            }
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let delegate = StandardTaggingStreamDelegate(continuation: continuation)
            let streamSession = URLSession(
                configuration: session.configuration,
                delegate: delegate,
                delegateQueue: nil
            )
            let task = streamSession.dataTask(with: request)
            continuation.onTermination = { _ in
                task.cancel()
                streamSession.invalidateAndCancel()
            }
            task.resume()
        }
    }

    func streamChatNonJSON(
        model: String,
        messages: [StandardTaggingOllamaMessage],
        format: [String: Any],
        options: StandardTaggingOllamaOptions,
        think: Bool?
    ) async throws -> String {
        return try await performSingleChat(model: model, messages: messages, format: format, options: options, think: think).message.content
    }

    private func performSingleChat(
        model: String,
        messages: [StandardTaggingOllamaMessage],
        format: [String: Any],
        options: StandardTaggingOllamaOptions,
        think: Bool?
    ) async throws -> StandardTaggingOllamaResponse {
        var request = URLRequest(url: hostURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "format": format,
            "stream": false,
            "options": [
                "temperature": options.temperature,
                "seed": options.seed,
                "top_p": options.topP,
                "top_k": options.topK,
                "min_p": options.minP,
                "presence_penalty": options.presencePenalty,
                "repeat_penalty": options.repeatPenalty
            ]
        ]
        if let think {
            body["think"] = think
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw error
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StandardTaggingOllamaError.transport(error)
        }

        let bodyString = String(data: data, encoding: .utf8) ?? ""
        guard let http = response as? HTTPURLResponse else {
            throw StandardTaggingOllamaError.invalidResponse(statusCode: -1, body: bodyString)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw StandardTaggingOllamaError.invalidResponse(statusCode: http.statusCode, body: bodyString)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(StandardTaggingOllamaResponse.self, from: data)
        } catch {
            throw StandardTaggingOllamaError.decodingFailed(underlying: error, body: bodyString)
        }
    }
}

private struct StandardTaggingOllamaStreamChunk: Decodable, Sendable {
    let message: Message
    let done: Bool

    struct Message: Decodable, Sendable {
        let content: String?
    }
}

final class StandardTaggingStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var buffer = Data()
    private var accumulated = Data()

    init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)

        while let newLineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newLineIndex)
            buffer.removeSubrange(buffer.startIndex...newLineIndex)
            guard line.isEmpty == false else { continue }
            guard let chunk = try? JSONDecoder().decode(StandardTaggingOllamaStreamChunk.self, from: line),
                  let text = chunk.message.content?.data(using: .utf8) else { continue }
            accumulated.append(text)
            continuation.yield(text)
            if chunk.done {
                continuation.finish()
                return
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }
}
