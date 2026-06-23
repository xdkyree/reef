import Foundation
import os.log

// MARK: - MetadataCache
//
// Lightweight JSON cache for recently fetched metadata arrays.
// Serves the last Home dashboard result immediately on next launch before
// the live network response arrives (stale-while-revalidate pattern).
//
// Full implementation in Task 21 (M4).

actor MetadataCache {

    // MARK: Properties

    private let diskURL: URL
    private let logger = Logger(subsystem: "com.reef.app", category: "MetadataCache")

    // MARK: Init

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskURL = caches.appendingPathComponent("reef.metadata", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    // MARK: - Public Interface

    /// Persist an array of `MediaItem` to disk under the given key.
    func save<T: Encodable & Sendable>(_ value: T, forKey key: String) {
        let fileURL = diskURL.appendingPathComponent("\(key).json")
        do {
            let data = try JSONEncoder.jellyfinEncoder.encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("MetadataCache save failed for key '\(key)': \(error)")
        }
    }

    /// Load a cached array for the given key, or return `nil` if absent/stale.
    func load<T: Decodable & Sendable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = diskURL.appendingPathComponent("\(key).json")
        guard
            let data = try? Data(contentsOf: fileURL),
            let value = try? JSONDecoder.jellyfinDecoder.decode(type, from: data)
        else { return nil }
        return value
    }

    /// Remove the cached value for the given key.
    func invalidate(key: String) {
        let fileURL = diskURL.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
