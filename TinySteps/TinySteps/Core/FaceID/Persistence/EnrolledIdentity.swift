import Foundation
import SwiftData

// MARK: - Privacy invariants (face-tagging)
//
// 1. `embeddings` is `Data` stored locally only. Not exported or sent over the network.
// 2. SwiftData container uses file protection with local store only.
// 3. No CloudKit for this entity (`cloudKitDatabase: .none` at container config).
// 4. No logging of raw embeddings in any string representation.
// 5. No analytics in this subsystem.
// 6. Photos for enrolment are not persisted here.

@Model
final class EnrolledIdentity {
    var id: UUID
    var studentKey: String
    var displayName: String
    var embeddings: Data
    var embeddingCount: Int
    var elementType: Int
    var vectorLength: Int
    var modelIdentifier: String
    var isDisabled: Bool
    var correctionCount: Int
    var updatedAt: Date

    init(
        studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        elementType: Int,
        vectorLength: Int,
        modelIdentifier: String,
        isDisabled: Bool = false,
        correctionCount: Int = 0
    ) {
        self.id = UUID()
        self.studentKey = studentKey
        self.displayName = displayName
        self.embeddings = embeddings
        self.embeddingCount = embeddingCount
        self.elementType = elementType
        self.vectorLength = vectorLength
        self.modelIdentifier = modelIdentifier
        self.isDisabled = isDisabled
        self.correctionCount = correctionCount
        self.updatedAt = .now
    }
}

extension EnrolledIdentity: CustomStringConvertible {
    var description: String {
        "EnrolledIdentity(studentKey: \(studentKey), displayName: \(displayName), "
            + "vectorLength: \(vectorLength), embeddingCount: \(embeddingCount), "
            + "updatedAt: \(updatedAt))"
    }
}

