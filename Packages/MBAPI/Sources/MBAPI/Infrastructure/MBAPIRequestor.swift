import Foundation
import os

final class MBAPIRequestor: MBEndpointRequesting, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let issueLogger: MBAPIIssueLogger
    private let demoDataStore: MBAPIDemoDataStore?
    private let logger = Logger(subsystem: "co.Faria.MobileManageBac.MBAPI", category: "MBAPIRequestor")
    private let responseBodyLogLength = 2_000

    init(
        session: URLSession,
        decoder: JSONDecoder,
        issueLogger: MBAPIIssueLogger = MBAPIIssueLogger(),
        demoDataStore: MBAPIDemoDataStore? = nil
    ) {
        self.session = session
        self.decoder = decoder
        self.issueLogger = issueLogger
        self.demoDataStore = demoDataStore
    }

    func loadItems<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [Response] {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        let responseTypeName = String(describing: responseType)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        if let replayData = await demoDataStore?.snapshotData(for: requestURL, responseType: responseTypeName) {
            do {
                return try decoder.decode(MBAPIResponseContainer<Response>.self, from: replayData).items
            } catch {
                logger.error("Demo replay decode failed for responseType=\(String(describing: responseType), privacy: .public)")
                logger.error("Request URL: \(requestURL.absoluteString, privacy: .public)")
                logger.error("Error: \(error.localizedDescription, privacy: .public)")

                await logIssue(
                    kind: .decodingFailed,
                    requestURL: requestURL,
                    endpointPath: endpointPath,
                    method: "GET",
                    context: context,
                    responseType: responseTypeName,
                    statusCode: 200,
                    errorDescription: "Demo replay decoding failed: \(error.localizedDescription)"
                )
                throw MBClientError.decodingFailed(error.localizedDescription)
            }
        }

        if await demoDataStore?.isReplaying ?? false {
            await logIssue(
                kind: .decodingFailed,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                responseType: responseTypeName,
                statusCode: nil,
                errorDescription: "No demo snapshot available for request."
            )
            throw MBClientError.decodingFailed("No demo snapshot available for \(endpointPath).")
        }

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if error is CancellationError {
                throw error
            }

            await logIssue(
                kind: .transportError,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                errorDescription: error.localizedDescription
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await logIssue(
                kind: .invalidResponse,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                errorDescription: MBClientError.invalidResponse.localizedDescription ?? "Invalid response",
                responseBody: data
            )
            throw MBClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            await logIssue(
                kind: .unexpectedStatusCode,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                errorDescription: MBClientError.unexpectedStatusCode(httpResponse.statusCode).localizedDescription ?? "Unexpected status code",
                responseBody: data
            )
            throw MBClientError.unexpectedStatusCode(httpResponse.statusCode)
        }

        do {
            let parsedResponse = try decoder.decode(MBAPIResponseContainer<Response>.self, from: data).items
            await demoDataStore?.storeSnapshot(
                data,
                for: requestURL,
                responseType: responseTypeName,
                endpointPath: endpointPath,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                context: context
            )
            return parsedResponse
        } catch {
            do {
                let fallbackResponse = try decoder.decode([Response].self, from: data)
                await logIssue(
                    kind: .decodingFailed,
                    requestURL: requestURL,
                    endpointPath: endpointPath,
                    method: "GET",
                    context: context,
                    responseType: "\(responseTypeName)[]",
                    statusCode: httpResponse.statusCode,
                    contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                    errorDescription: "Decoded as raw array after wrapper decode failed: \(error.localizedDescription)",
                    responseBody: data
                )
                return fallbackResponse
            } catch {}

            let responsePreview = String(data: data, encoding: .utf8)?
                .prefix(responseBodyLogLength) ?? "<non-UTF8 body>"
            logger.error("Decoding failed for responseType=\(String(describing: responseType), privacy: .public)")
            logger.error("Request URL: \(requestURL.absoluteString, privacy: .public)")
            logger.error("Status: \(httpResponse.statusCode)")
            logger.error("Error: \(error.localizedDescription, privacy: .public)")
            logger.error("Body preview: \(String(responsePreview), privacy: .public)")

            await logIssue(
                kind: .decodingFailed,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                responseType: responseTypeName,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                errorDescription: error.localizedDescription,
                responseBody: data
            )
            throw MBClientError.decodingFailed(error.localizedDescription)
        }
    }

    func loadObject<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> Response {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        let responseTypeName = String(describing: responseType)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        if let replayData = await demoDataStore?.snapshotData(for: requestURL, responseType: responseTypeName) {
            do {
                return try decoder.decode(responseType.self, from: replayData)
            } catch {
                logger.error("Demo replay decode failed for responseType=\(String(describing: responseType), privacy: .public)")
                logger.error("Request URL: \(requestURL.absoluteString, privacy: .public)")
                logger.error("Error: \(error.localizedDescription, privacy: .public)")

                await logIssue(
                    kind: .decodingFailed,
                    requestURL: requestURL,
                    endpointPath: endpointPath,
                    method: "GET",
                    context: context,
                    responseType: responseTypeName,
                    statusCode: 200,
                    errorDescription: "Demo replay decoding failed: \(error.localizedDescription)"
                )
                throw MBClientError.decodingFailed(error.localizedDescription)
            }
        }

        if await demoDataStore?.isReplaying ?? false {
            await logIssue(
                kind: .decodingFailed,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                responseType: responseTypeName,
                statusCode: nil,
                errorDescription: "No demo snapshot available for request."
            )
            throw MBClientError.decodingFailed("No demo snapshot available for \(endpointPath).")
        }

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if error is CancellationError {
                throw error
            }

            await logIssue(
                kind: .transportError,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                errorDescription: error.localizedDescription
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await logIssue(
                kind: .invalidResponse,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                errorDescription: MBClientError.invalidResponse.localizedDescription ?? "Invalid response",
                responseBody: data
            )
            throw MBClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            await logIssue(
                kind: .unexpectedStatusCode,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                errorDescription: MBClientError.unexpectedStatusCode(httpResponse.statusCode).localizedDescription ?? "Unexpected status code",
                responseBody: data
            )
            throw MBClientError.unexpectedStatusCode(httpResponse.statusCode)
        }

        do {
            let parsedResponse = try decoder.decode(responseType.self, from: data)
            await demoDataStore?.storeSnapshot(
                data,
                for: requestURL,
                responseType: responseTypeName,
                endpointPath: endpointPath,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                context: context
            )
            return parsedResponse
        } catch {
            let responsePreview = String(data: data, encoding: .utf8)?
                .prefix(responseBodyLogLength) ?? "<non-UTF8 body>"
            logger.error("Decoding failed for responseType=\(String(describing: responseType), privacy: .public)")
            logger.error("Request URL: \(requestURL.absoluteString, privacy: .public)")
            logger.error("Status: \(httpResponse.statusCode)")
            logger.error("Error: \(error.localizedDescription, privacy: .public)")
            logger.error("Body preview: \(String(responsePreview), privacy: .public)")

            await logIssue(
                kind: .decodingFailed,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: "GET",
                context: context,
                responseType: responseTypeName,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                errorDescription: error.localizedDescription,
                responseBody: data
            )
            throw MBClientError.decodingFailed(error.localizedDescription)
        }
    }

    func send(
        to endpointPath: String,
        in context: MBSessionContext,
        method: String,
        query: [String: String],
        body: Data?
    ) async throws {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")

        if let bodyData = body {
            request.httpBody = bodyData
        }

        if await demoDataStore?.isReplaying ?? false {
            if let replayData = await demoDataStore?.snapshotData(for: requestURL, responseType: "NoResponse") {
                _ = replayData
                return
            }

            await logIssue(
                kind: .decodingFailed,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: method,
                context: context,
                statusCode: nil,
                errorDescription: "No demo snapshot available for request."
            )
            throw MBClientError.decodingFailed("No demo snapshot available for \(endpointPath).")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if error is CancellationError {
                throw error
            }

            await logIssue(
                kind: .transportError,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: method,
                context: context,
                errorDescription: error.localizedDescription
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await logIssue(
                kind: .invalidResponse,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: method,
                context: context,
                errorDescription: MBClientError.invalidResponse.localizedDescription ?? "Invalid response",
                responseBody: data
            )
            throw MBClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            await logIssue(
                kind: .unexpectedStatusCode,
                requestURL: requestURL,
                endpointPath: endpointPath,
                method: method,
                context: context,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                errorDescription: MBClientError.unexpectedStatusCode(httpResponse.statusCode).localizedDescription ?? "Unexpected status code",
                responseBody: data
            )
            throw MBClientError.unexpectedStatusCode(httpResponse.statusCode)
        }

        await demoDataStore?.storeSnapshot(
            data,
            for: requestURL,
            responseType: "NoResponse",
            endpointPath: endpointPath,
            statusCode: httpResponse.statusCode,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
            context: context
        )
    }

    private func logIssue(
        kind: MBAPIIssue.Kind,
        requestURL: URL,
        endpointPath: String,
        method: String,
        context: MBSessionContext,
        responseType: String? = nil,
        statusCode: Int? = nil,
        contentType: String? = nil,
        errorDescription: String,
        responseBody: Data? = nil
    ) async {
        await issueLogger.log(
            MBAPIIssue(
                kind: kind,
                method: method,
                endpointPath: endpointPath,
                requestURL: requestURL,
                role: context.role.rawValue,
                childID: context.childID,
                responseType: responseType,
                statusCode: statusCode,
                contentType: contentType,
                errorDescription: errorDescription,
                responseBody: responseBody
            )
        )
    }
}
