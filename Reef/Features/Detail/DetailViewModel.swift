import SwiftUI

// MARK: - DetailViewModel

@MainActor
final class DetailViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var isLoadingPlayback = false
    @Published private(set) var playbackInfo: PlaybackInfo?
    @Published private(set) var error: Error?
    @Published var showResumePrompt = false
    @Published var shouldStartPlayer = false

    // MARK: The item under display
    let item: MediaItem

    // MARK: Dependencies
    private let api: JellyfinAPIClientProtocol

    // MARK: Init
    init(item: MediaItem, api: JellyfinAPIClientProtocol) {
        self.item = item
        self.api = api
    }

    // MARK: - Computed

    /// Whether the trailer button should be shown.
    /// (Trailer support is post-MVP; always hidden for now.)
    var hasTrailer: Bool { false }

    var hasResumePosition: Bool { item.isResumable }

    // MARK: - Actions

    func play(userID: String, token: String) async {
        if hasResumePosition {
            showResumePrompt = true
        } else {
            await startPlayback(userID: userID, token: token)
        }
    }

    func startPlayback(userID: String, token: String) async {
        isLoadingPlayback = true
        error = nil
        defer { isLoadingPlayback = false }

        do {
            playbackInfo = try await api.fetchPlaybackInfo(
                itemID: item.id,
                userID: userID,
                token: token,
                deviceProfile: .reef
            )
            shouldStartPlayer = true
        } catch {
            self.error = error
        }
    }
}
