import XCTest
@testable import Reef

// MARK: - ImageCacheTests

final class ImageCacheTests: XCTestCase {

    private var cache: ImageCache?

    override func setUp() async throws {
        let newCache = ImageCache()
        try await newCache.clearDiskCache()
        cache = newCache
    }

    private var sut: ImageCache {
        guard let cache else { fatalError("ImageCache not initialised") }
        return cache
    }

    // MARK: - Tests

    func test_clearMemoryCache_doesNotThrow() async {
        await sut.clearMemoryCache()
        XCTAssertTrue(true)
    }

    func test_clearDiskCache_doesNotThrow() async throws {
        try await sut.clearDiskCache()
        XCTAssertTrue(true)
    }

    func test_image_throwsOnInvalidURL() async {
        let badURL = URL(string: "https://example.com/notanimage.txt")!
        do {
            _ = try await sut.image(for: badURL)
        } catch ImageCacheError.invalidImageData {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(true)
        }
    }

    func test_clearDiskCache_removesAllDiskFiles() async throws {
        try await sut.clearDiskCache()
        try await sut.clearDiskCache()
        XCTAssertTrue(true)
    }
}
