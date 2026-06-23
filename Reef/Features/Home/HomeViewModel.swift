import SwiftUI

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var continueWatching: [MediaItem] = []
    @Published private(set) var nextUp: [MediaItem] = []
    @Published private(set) var recentlyAddedMovies: [MediaItem] = []
    @Published private(set) var recentlyAddedShows: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: Dependencies
    private let api: JellyfinAPIClientProtocol

    // MARK: Init
    init(api: JellyfinAPIClientProtocol) {
        self.api = api
    }

    // MARK: - Load Dashboard

    /// Loads all four carousel sections in parallel using async let.
    func loadDashboard(userID: String, token: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let cw  = api.fetchContinueWatching(userID: userID, token: token)
            async let nu  = api.fetchNextUp(userID: userID, token: token)
            async let ram = api.fetchRecentlyAdded(userID: userID, libraryID: nil, token: token, limit: 20)
            async let ras = api.fetchRecentlyAdded(userID: userID, libraryID: nil, token: token, limit: 20)

            let (cwResult, nuResult, ramResult, rasResult) = try await (cw, nu, ram, ras)

            continueWatching      = cwResult
            nextUp                = nuResult
            // Split by media type — movies vs. shows.
            recentlyAddedMovies   = ramResult.filter { $0.type == .movie }
            recentlyAddedShows    = rasResult.filter { $0.type == .series || $0.type == .episode }
        } catch {
            self.error = error
        }
    }

    // MARK: - Refresh

    func refresh(userID: String, token: String) async {
        await loadDashboard(userID: userID, token: token)
    }
}
