import Foundation
@testable import Reef

// MARK: - MockKeychainService
//
// In-memory Keychain stub for unit tests. Simulates save/load/delete
// without touching the real macOS/tvOS Keychain.

actor MockKeychainService: KeychainServiceProtocol {

    private var stored: StoredCredentials?
    private(set) var saveCallCount = 0
    private(set) var loadCallCount = 0
    private(set) var deleteCallCount = 0

    /// Pre-seed with credentials to simulate a returning user.
    var preloadedCredentials: StoredCredentials?

    // MARK: Error injection
    var shouldThrowOnSave = false
    var shouldThrowOnLoad = false
    var shouldThrowOnDelete = false

    func save(_ credentials: StoredCredentials) async throws {
        saveCallCount += 1
        if shouldThrowOnSave { throw KeychainError.saveFailed(-25299) }
        stored = credentials
    }

    func load() async throws -> StoredCredentials? {
        loadCallCount += 1
        if shouldThrowOnLoad { throw KeychainError.loadFailed(-25300) }
        return stored ?? preloadedCredentials
    }

    func delete() async throws {
        deleteCallCount += 1
        if shouldThrowOnDelete { throw KeychainError.deleteFailed(-25299) }
        stored = nil
    }
}

// MARK: - MockJellyfinAPIClient

actor MockJellyfinAPIClient: JellyfinAPIClientProtocol {

    // MARK: Return values
    var stubbedAuthResponse: AuthResponse?
    var stubbedUser: JellyfinUser?
    var stubbedAllUsers: [JellyfinUser] = []
    var stubbedContinueWatching: [MediaItem] = []
    var stubbedNextUp: [MediaItem] = []
    var stubbedRecentlyAdded: [MediaItem] = []
    var stubbedLibraryItems: PaginatedResult<MediaItem>?
    var stubbedUserLibraries: [UserLibrary] = []
    var stubbedPlaybackInfo: PlaybackInfo?

    // MARK: Error injection
    var shouldThrowError: Error?

    // MARK: Call tracking
    private(set) var authenticateCallCount = 0
    private(set) var fetchContinueWatchingCallCount = 0
    private(set) var fetchNextUpCallCount = 0
    private(set) var fetchRecentlyAddedCallCount = 0
    private(set) var fetchLibraryItemsCallCount = 0
    private(set) var reportProgressCallCount = 0
    private(set) var reportStoppedCallCount = 0

    // MARK: - Protocol conformance

    func authenticate(serverURL: URL, username: String, password: String) async throws -> AuthResponse {
        authenticateCallCount += 1
        if let error = shouldThrowError { throw error }
        guard let response = stubbedAuthResponse else {
            throw NetworkError.unknown("MockJellyfinAPIClient: stubbedAuthResponse not set")
        }
        return response
    }

    func fetchUser(userID: String, token: String) async throws -> JellyfinUser {
        if let error = shouldThrowError { throw error }
        guard let user = stubbedUser else {
            throw NetworkError.unknown("MockJellyfinAPIClient: stubbedUser not set")
        }
        return user
    }

    func fetchAllUsers(token: String) async throws -> [JellyfinUser] {
        if let error = shouldThrowError { throw error }
        return stubbedAllUsers
    }

    func fetchContinueWatching(userID: String, token: String) async throws -> [MediaItem] {
        fetchContinueWatchingCallCount += 1
        if let error = shouldThrowError { throw error }
        return stubbedContinueWatching
    }

    func fetchNextUp(userID: String, token: String) async throws -> [MediaItem] {
        fetchNextUpCallCount += 1
        if let error = shouldThrowError { throw error }
        return stubbedNextUp
    }

    func fetchRecentlyAdded(
        userID: String,
        libraryID: String?,
        token: String,
        limit: Int
    ) async throws -> [MediaItem] {
        fetchRecentlyAddedCallCount += 1
        if let error = shouldThrowError { throw error }
        return stubbedRecentlyAdded
    }

    func fetchLibraryItems(
        userID: String,
        parentID: String,
        token: String,
        startIndex: Int,
        limit: Int
    ) async throws -> PaginatedResult<MediaItem> {
        fetchLibraryItemsCallCount += 1
        if let error = shouldThrowError { throw error }
        return stubbedLibraryItems ?? PaginatedResult(items: [], totalCount: 0, startIndex: 0)
    }

    func fetchUserLibraries(userID: String, token: String) async throws -> [UserLibrary] {
        if let error = shouldThrowError { throw error }
        return stubbedUserLibraries
    }

    func fetchPlaybackInfo(
        itemID: String,
        userID: String,
        token: String,
        deviceProfile: DeviceProfile
    ) async throws -> PlaybackInfo {
        if let error = shouldThrowError { throw error }
        guard let info = stubbedPlaybackInfo else {
            throw NetworkError.unknown("MockJellyfinAPIClient: stubbedPlaybackInfo not set")
        }
        return info
    }

    func reportPlaybackStarted(sessionID: String, itemID: String, token: String) async throws {
        if let error = shouldThrowError { throw error }
    }

    func reportPlaybackProgress(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        isPaused: Bool,
        token: String
    ) async throws {
        reportProgressCallCount += 1
        if let error = shouldThrowError { throw error }
    }

    func reportPlaybackStopped(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        token: String
    ) async throws {
        reportStoppedCallCount += 1
        if let error = shouldThrowError { throw error }
    }
}
