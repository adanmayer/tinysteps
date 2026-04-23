import Foundation
import os

final class MBAPIMockRequestor: MBEndpointRequesting, Sendable {
    private let decoder: JSONDecoder
    private let demoDataStore: MBAPIDemoDataStore
    private let logger = Logger(
        subsystem: "co.Faria.MobileManageBac.MBAPI",
        category: "MBAPIMockRequestor"
    )

    init(
        demoDataStore: MBAPIDemoDataStore,
        decoder: JSONDecoder
    ) {
        self.demoDataStore = demoDataStore
        self.decoder = decoder
    }

    func loadItems<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [Response] {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        let responseTypeName = String(describing: responseType)

        guard let data = await demoDataStore.snapshotData(for: requestURL, responseType: responseTypeName) else {
            logger.error("Mock fixture not found for \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.fixtureNotFound(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString
            )
        }

        do {
            return try decoder.decode(MBAPIResponseContainer<Response>.self, from: data).items
        } catch {
            do {
                return try decoder.decode([Response].self, from: data)
            } catch {
                logger.error("Mock fixture decode failed for \(requestURL.absoluteString, privacy: .public)")
                throw MBMockClientError.decodingFailed(
                    endpointPath: endpointPath,
                    responseType: responseTypeName,
                    requestURL: requestURL.absoluteString,
                    reason: error.localizedDescription
                )
            }
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

        guard let data = await demoDataStore.snapshotData(for: requestURL, responseType: responseTypeName) else {
            logger.error("Mock fixture not found for \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.fixtureNotFound(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString
            )
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            logger.error("Mock fixture decode failed for object response \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.decodingFailed(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString,
                reason: error.localizedDescription
            )
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
        let responseType = "NoResponse"

        guard let data = await demoDataStore.snapshotData(for: requestURL, responseType: responseType) else {
            logger.error("Mock fixture not found for \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.fixtureNotFound(
                endpointPath: endpointPath,
                responseType: responseType,
                requestURL: requestURL.absoluteString
            )
        }

        _ = data
        _ = body
        _ = method
        _ = context
    }

    func send<Response: Decodable, Body: Encodable>(
        _ responseType: Response.Type,
        to endpointPath: String,
        in context: MBSessionContext,
        method: String,
        query: [String: String],
        body: Body
    ) async throws -> Response {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        let responseTypeName = String(describing: responseType)

        guard let data = await demoDataStore.snapshotData(for: requestURL, responseType: responseTypeName) else {
            logger.error("Mock fixture not found for \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.fixtureNotFound(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString
            )
        }

        _ = body
        _ = method

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            logger.error("Mock fixture decode failed for post response \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.decodingFailed(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString,
                reason: error.localizedDescription
            )
        }
    }

    func uploadMultipart<Response: Decodable>(
        as responseType: Response.Type,
        to endpointPath: String,
        in context: MBSessionContext,
        query: [String: String],
        file: MBMultipartFile
    ) async throws -> Response {
        let requestURL = MBAPIEndpointRequestBuilder.requestURL(for: endpointPath, in: context, query: query)
        let responseTypeName = String(describing: responseType)

        guard let data = await demoDataStore.snapshotData(for: requestURL, responseType: responseTypeName) else {
            logger.error("Mock fixture not found for \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.fixtureNotFound(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString
            )
        }

        _ = file

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            logger.error("Mock fixture decode failed for multipart response \(requestURL.absoluteString, privacy: .public)")
            throw MBMockClientError.decodingFailed(
                endpointPath: endpointPath,
                responseType: responseTypeName,
                requestURL: requestURL.absoluteString,
                reason: error.localizedDescription
            )
        }
    }
}
