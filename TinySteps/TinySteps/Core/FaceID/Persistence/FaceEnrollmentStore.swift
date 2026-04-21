import Foundation
import SwiftData

enum FaceEnrollmentStoreError: LocalizedError {
    case unavailable
    case invalidEmbeddingData

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Face setup is not available on this device right now."
        case .invalidEmbeddingData:
            return "Failed to save face embedding payload."
        }
    }
}

protocol FaceEnrollmentStore {
    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus]
    func status(for studentKey: String) async throws -> FaceEnrollmentStatus
    func deleteEnrollment(for studentKey: String) async throws
    func upsertEnrollment(
        for studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        vectorLength: Int,
        elementType: Int,
        modelIdentifier: String
    ) async throws
}

@MainActor
final class SwiftDataFaceEnrollmentStore: FaceEnrollmentStore {
    private let modelContext: ModelContext

    init() throws {
        let container = try FaceIDModelContainer.make()
        self.modelContext = ModelContext(container)
    }

    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus] {
        guard studentKeys.isEmpty == false else {
            return [:]
        }

        let identities = try modelContext.fetch(FetchDescriptor<EnrolledIdentity>())
        let uniqueKeys = Set(studentKeys)
        let matching = identities.filter { uniqueKeys.contains($0.studentKey) }

        var result: [String: FaceEnrollmentStatus] = [:]
        for studentKey in studentKeys {
            guard let latest = matching
                .filter({ $0.studentKey == studentKey })
                .max(by: { $0.updatedAt < $1.updatedAt }) else {
                result[studentKey] = .needsSetup
                continue
            }

            result[studentKey] = Self.status(for: latest)
        }

        return result
    }

    func status(for studentKey: String) async throws -> FaceEnrollmentStatus {
        guard studentKey.isEmpty == false else {
            return .needsSetup
        }

        let identity = try modelContext.fetch(
            FetchDescriptor(
                predicate: #Predicate<EnrolledIdentity> { identity in
                    identity.studentKey == studentKey
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).first

        guard let identity else {
            return .needsSetup
        }

        return Self.status(for: identity)
    }

    func deleteEnrollment(for studentKey: String) async throws {
        let identities = try modelContext.fetch(
            FetchDescriptor(
                predicate: #Predicate<EnrolledIdentity> { identity in
                    identity.studentKey == studentKey
                }
            )
        )

        for identity in identities {
            modelContext.delete(identity)
        }

        try modelContext.save()
    }

    func upsertEnrollment(
        for studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        vectorLength: Int,
        elementType: Int,
        modelIdentifier: String
    ) async throws {
        guard studentKey.isEmpty == false else {
            return
        }

        let expectedVectorCount = embeddingCount * vectorLength
        let expectedByteCount = expectedVectorCount * MemoryLayout<Float32>.size
        guard embeddings.count == expectedByteCount else {
            throw FaceEnrollmentStoreError.invalidEmbeddingData
        }

        let existing = try modelContext.fetch(
            FetchDescriptor(
                predicate: #Predicate<EnrolledIdentity> { identity in
                    identity.studentKey == studentKey
                }
            )
        )
        for identity in existing {
            modelContext.delete(identity)
        }

        let identity = EnrolledIdentity(
            studentKey: studentKey,
            displayName: displayName,
            embeddings: embeddings,
            embeddingCount: embeddingCount,
            elementType: elementType,
            vectorLength: vectorLength,
            modelIdentifier: modelIdentifier
        )

        modelContext.insert(identity)
        try modelContext.save()
    }

    private static func status(for identity: EnrolledIdentity) -> FaceEnrollmentStatus {
        guard identity.isDisabled == false else {
            return .disabled
        }

        guard identity.embeddings.isEmpty == false else {
            return .invalid(reason: "No embeddings stored")
        }

        guard identity.embeddingCount >= FaceIDModelContainer.requiredEmbeddingCount else {
            return .invalid(reason: "Not enough embeddings")
        }

        guard identity.vectorLength >= FaceIDModelContainer.requiredVectorLength else {
            return .invalid(reason: "Vector length too short")
        }

        guard identity.modelIdentifier.hasPrefix(FaceIDModelContainer.requiredModelIdentifier) else {
            return .invalid(reason: "Wrong model version")
        }

        let expectedByteCount = identity.embeddingCount * identity.vectorLength * MemoryLayout<Float32>.size
        guard identity.embeddings.count == expectedByteCount else {
            return .invalid(reason: "Corrupt embedding payload")
        }

        return .enrolled(photoCount: identity.embeddingCount, updatedAt: identity.updatedAt)
    }
}

struct FaceEnrollmentStoreUnavailable: FaceEnrollmentStore {
    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus] {
        var statuses: [String: FaceEnrollmentStatus] = [:]
        for studentKey in studentKeys {
            statuses[studentKey] = .unavailable
        }
        return statuses
    }

    func status(for studentKey: String) async throws -> FaceEnrollmentStatus {
        .unavailable
    }

    func deleteEnrollment(for studentKey: String) async throws {
    }

    func upsertEnrollment(
        for studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        vectorLength: Int,
        elementType: Int,
        modelIdentifier: String
    ) async throws {
        throw FaceEnrollmentStoreError.unavailable
    }
}
