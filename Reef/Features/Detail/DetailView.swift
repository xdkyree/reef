import SwiftUI

// MARK: - DetailView
//
// Immersive full-screen detail for a single media item.
// Features: blurred backdrop, metadata panel, Play/Trailer/More buttons.

struct DetailView: View {

    let item: MediaItem
    private let api: JellyfinAPIClientProtocol
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.dismiss) private var dismiss

    @FocusState private var defaultFocus: Bool

    init(item: MediaItem, api: JellyfinAPIClientProtocol) {
        self.item = item
        self.api = api
        _viewModel = StateObject(wrappedValue: DetailViewModel(
            item: item,
            api: api
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop
            BlurredBackdropView(url: backdropURL)

            // Metadata panel
            HStack(alignment: .bottom, spacing: Spacing.xxl) {
                metadataPanel
                    .frame(maxWidth: 700)
                Spacer()
            }
            .padding(.horizontal, Spacing.sectionPadding)
            .padding(.bottom, Spacing.xxl)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $viewModel.shouldStartPlayer) {
            if let info = viewModel.playbackInfo,
               let source = info.preferredSource,
               let urlString = source.directStreamUrl,
               let url = URL(string: urlString),
               let session = appState.currentSession {
                VideoPlayerView(
                    url: url,
                    item: item,
                    source: source,
                    sessionID: info.playSessionId ?? "",
                    token: session.accessToken,
                    api: api
                )
            }
        }
        .confirmationDialog(
            "Resume Playback",
            isPresented: $viewModel.showResumePrompt,
            titleVisibility: .visible
        ) {
            Button("Resume from \(item.userData?.playbackPositionTicks.formattedAsTime ?? "")") {
                Task {
                    guard let session = appState.currentSession else { return }
                    await viewModel.startPlayback(userID: session.userID, token: session.accessToken)
                }
            }
            Button("Start Over") {
                Task {
                    guard let session = appState.currentSession else { return }
                    await viewModel.startPlayback(userID: session.userID, token: session.accessToken)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Metadata Panel

    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Title
            Text(item.name)
                .font(.reefDisplayTitle)
                .foregroundStyle(Color.reefLabel)
                .lineLimit(3)

            // Meta chips
            HStack(spacing: Spacing.md) {
                if let year = item.productionYear {
                    metaChip(String(year))
                }
                if let rating = item.officialRating {
                    metaChip(rating)
                }
                if let duration = item.durationFormatted {
                    metaChip(duration)
                }
                if let score = item.communityRating {
                    metaChip("★ \(String(format: "%.1f", score))")
                }
            }

            // Synopsis
            if let overview = item.overview {
                Text(overview)
                    .font(.reefBody)
                    .foregroundStyle(Color.reefLabelSecondary)
                    .lineLimit(4)
            }

            // Action buttons
            HStack(spacing: Spacing.lg) {
                FocusScaleButton(action: {
                    Task {
                        guard let session = appState.currentSession else { return }
                        await viewModel.play(userID: session.userID, token: session.accessToken)
                    }
                }) {
                    Label(item.isResumable ? "Resume" : "Play", systemImage: "play.fill")
                        .font(.reefBodyEmphasized)
                        .foregroundStyle(Color.reefOnAccent)
                }
                .prefersDefaultFocus(in: defaultFocus == false ? .init() : .init())

                if viewModel.hasTrailer {
                    FocusScaleButton(action: {}) {
                        Label("Trailer", systemImage: "film")
                            .font(.reefBody)
                            .foregroundStyle(Color.reefLabel)
                    }
                }
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.reefCaption)
                    .foregroundStyle(Color.reefDestructive)
            }
        }
    }

    // MARK: - Helpers

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.reefCaption)
            .foregroundStyle(Color.reefLabel)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.reefGlassFill)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.reefGlassBorder, lineWidth: 1)
            )
    }

    private var backdropURL: URL? {
        guard let session = appState.currentSession,
              let tag = item.backdropImageTags?.first else { return nil }
        return session.serverURL
            .appendingPathComponent(Endpoints.backdropImage(itemID: item.id))
            .appending(queryItems: [
                URLQueryItem(name: "tag", value: tag),
                URLQueryItem(name: "quality", value: "80")
            ])
    }
}

// MARK: - Int64 ticks → time string

private extension Int64 {
    var formattedAsTime: String {
        let totalSeconds = Int(self / 10_000_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
