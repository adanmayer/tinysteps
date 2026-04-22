import Foundation

actor MBStandardsCache {
    private var entries: [MBStandardsCacheKey: MBStandardsCacheEntry] = [:]

    func cachedResult(for key: MBStandardsCacheKey) -> MBStandardsLoadResult? {
        entries[key]?.result
    }

    func store(_ result: MBStandardsLoadResult, for key: MBStandardsCacheKey) {
        entries[key] = MBStandardsCacheEntry(
            key: key,
            result: result,
            loadedAt: result.loadedAt
        )
    }

    func clear() {
        entries.removeAll()
    }
}

