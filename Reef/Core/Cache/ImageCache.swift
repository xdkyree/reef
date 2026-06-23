import UIKit
import os.log

// MARK: - ImageCache
//
// Two-tier actor cache: NSCache (memory) + disk (FileManager.cachesDirectory).
// All UI image loading goes through `image(for:)` — never hit the network directly.
//
// Full hardening (eviction tuning, memory warning hooks) is done in Task 21 (M4).

public actor ImageCache {

    // MARK: Properties

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let logger = Logger(subsystem: "com.reef.app", category: "ImageCache")

    // MARK: Init

    public init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("reef.imagecache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Allow up to 200 images (~50 MB) in memory before eviction kicks in.
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1_024 * 1_024
    }

    // MARK: - Public Interface

    /// Returns a cached image for the URL, or fetches and caches it.
    public func image(for url: URL) async throws -> UIImage {
        let key = url.absoluteString as NSString
        let diskKey = diskFileName(for: url)

        // 1. Memory hit
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. Disk hit
        let diskPath = diskCacheURL.appendingPathComponent(diskKey)
        if let data = try? Data(contentsOf: diskPath), let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            return img
        }

        // 3. Network fetch
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let img = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        // Store to both tiers
        memoryCache.setObject(img, forKey: key, cost: data.count)
        try? data.write(to: diskPath, options: .atomic)

        logger.debug("Cached image from \(url.absoluteString)")
        return img
    }

    /// Removes all cached images from memory. Disk cache is preserved.
    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
        logger.debug("Memory image cache cleared.")
    }

    /// Removes all cached images from disk. Memory cache is also cleared.
    public func clearDiskCache() throws {
        clearMemoryCache()
        let contents = try FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: nil
        )
        for file in contents {
            try FileManager.default.removeItem(at: file)
        }
        logger.debug("Disk image cache cleared (\(contents.count) files removed).")
    }

    // MARK: - Private

    private func diskFileName(for url: URL) -> String {
        // Simple stable hash of the URL string for the filename.
        let hash = abs(url.absoluteString.hashValue)
        return "\(hash).img"
    }
}

// MARK: - ImageCacheError

public enum ImageCacheError: Error {
    case invalidImageData
}
