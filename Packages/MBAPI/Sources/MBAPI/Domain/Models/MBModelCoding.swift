import Foundation

enum MBModelCoding {
    static func decodeStringID<C: CodingKey>(
        from container: KeyedDecodingContainer<C>,
        forKey key: C
    ) throws -> String {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? container.decode(Int.self, forKey: key) {
            return String(intValue)
        }

        if let int64Value = try? container.decode(Int64.self, forKey: key) {
            return String(int64Value)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected a string or integer identifier."
        )
    }

    static func decodeOptionalStringID<C: CodingKey>(
        from container: KeyedDecodingContainer<C>,
        forKey key: C
    ) throws -> String? {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? container.decode(Int.self, forKey: key) {
            return String(intValue)
        }

        if let int64Value = try? container.decode(Int64.self, forKey: key) {
            return String(int64Value)
        }

        if container.contains(key), try container.decodeNil(forKey: key) {
            return nil
        }

        return nil
    }
}
