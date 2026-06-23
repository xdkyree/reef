import SwiftUI
import AVKit

// MARK: - VideoPlayerView
//
// Full-screen player that selects the correct engine via `PlaybackRouter`
// and embeds it in a SwiftUI-compatible view.
//
// Full implementation: Task 19 (M3).

struct VideoPlayerView: View {

    let url: URL
    let item: MediaItem
    let source: MediaSource
    let sessionID: String
    let token: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlayerViewModel

    init(
        url: URL,
        item: MediaItem,
        source: MediaSource,
        sessionID: String,
        token: String,
        api: JellyfinAPIClientProtocol
    ) {
        self.url = url
        self.item = item
        self.source = source
        self.sessionID = sessionID
        self.token = token
        _viewModel = StateObject(wrappedValue: PlayerViewModel(
            item: item,
            source: source,
            api: api
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Engine selection
            switch PlaybackRouter.resolve(for: source) {
            case .avPlayer:
                avPlayerContent
            case .vlc:
                // VLC view embedded via UIViewRepresentable (Task 16/19)
                vlcPlaceholder
            }

            PlayerControlsView(viewModel: viewModel, onDismiss: {
                Task {
                    await viewModel.stop()
                    dismiss()
                }
            })
        }
        .task {
            await viewModel.startPlayback(url: url, sessionID: sessionID, token: token)
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
    }

    // MARK: - AVPlayer Content

    private var avPlayerContent: some View {
        VideoPlayer(player: viewModel.avPlayerEngine?.player)
            .ignoresSafeArea()
    }

    // MARK: - VLC Placeholder (until Task 16)

    private var vlcPlaceholder: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .tint(Color.reefAccent)
            Text("Loading VLC engine…")
                .font(.reefBody)
                .foregroundStyle(Color.reefLabelSecondary)
        }
    }
}
