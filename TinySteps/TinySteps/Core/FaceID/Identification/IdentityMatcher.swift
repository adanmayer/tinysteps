import Foundation

struct IdentityMatcher {
    enum Match {
        case matched(studentKey: String, displayName: String, distanceSquared: Float)
        case unknown(distanceSquared: Float?)
    }

    func bestMatch(
        for embedding: FaceEmbedding,
        in snapshots: [FaceEnrollmentSnapshot],
        threshold: Float
    ) -> Match {
        var bestDistance: Float = Float.greatestFiniteMagnitude
        var bestStudent: (String, String)?

        for snapshot in snapshots {
            guard snapshot.modelIdentifier.hasPrefix(FaceIDModelContainer.requiredModelIdentifier) else {
                continue
            }
            guard snapshot.elementType == FaceIDModelContainer.requiredElementType else {
                continue
            }
            guard snapshot.vectorLength == embedding.vectorLength else {
                continue
            }
            guard snapshot.embeddingCount > 0 else {
                continue
            }

            let localDistance = minimumDistance(
                query: embedding.vector,
                snapshot: snapshot
            )

            if localDistance < bestDistance {
                bestDistance = localDistance
                bestStudent = (snapshot.studentKey, snapshot.displayName)
            }
        }

        guard let found = bestStudent else {
            return .unknown(distanceSquared: nil)
        }
        guard bestDistance <= threshold else {
            return .unknown(distanceSquared: bestDistance)
        }
        return .matched(studentKey: found.0, displayName: found.1, distanceSquared: bestDistance)
    }

    private func minimumDistance(query: [Float], snapshot: FaceEnrollmentSnapshot) -> Float {
        let expectedBytes = snapshot.vectorLength * snapshot.embeddingCount * MemoryLayout<Float>.size
        guard snapshot.embeddings.count == expectedBytes else {
            return Float.greatestFiniteMagnitude
        }

        var baseOffset = 0
        var minDistance = Float.greatestFiniteMagnitude

        while baseOffset + snapshot.vectorLength * MemoryLayout<Float>.size <= snapshot.embeddings.count {
            var candidateDistance: Float = 0
            let spanStart = baseOffset
            let spanEnd = baseOffset + snapshot.vectorLength * MemoryLayout<Float>.size
            let rowData = snapshot.embeddings.subdata(in: spanStart..<spanEnd)
            var vector: [Float] = []
            vector.reserveCapacity(snapshot.vectorLength)

            for offset in stride(from: 0, to: rowData.count, by: MemoryLayout<Float>.size) {
                let value = rowData.withUnsafeBytes { bytes -> Float in
                    bytes.load(fromByteOffset: offset, as: Float.self)
                }
                vector.append(value)
            }

            if vector.count != snapshot.vectorLength {
                baseOffset += snapshot.vectorLength * MemoryLayout<Float>.size
                continue
            }

            for idx in 0..<snapshot.vectorLength {
                let delta = query[idx] - vector[idx]
                candidateDistance += delta * delta
            }
            if candidateDistance < minDistance {
                minDistance = candidateDistance
            }
            baseOffset += snapshot.vectorLength * MemoryLayout<Float>.size
        }

        return minDistance
    }
}
