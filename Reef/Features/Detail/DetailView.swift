import SwiftUI

struct DetailView: View {
    let item: MediaItem
    private let api: JellyfinAPIClientProtocol

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: DetailViewModel

    init(item: MediaItem, api: JellyfinAPIClientProtocol) {
        self.item = item
        self.api = api
        _viewModel = StateObject(wrappedValue: DetailViewModel(item: item, api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 32) {
                    AsyncImageView(url: posterURL, contentMode: .fill, cornerRadius: 18)
                        .frame(width: 360, height: 540)

                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.name)
                            .font(.largeTitle.bold())

                        metadataRow

                        if let overview = item.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        Button(item.isResumable ? "Resume" : "Play") {
                            Task {
                                guard let session = appState.currentSession else {
                                    return
                                }
                                await viewModel.play(
                                    userID: session.userID,
                                    token: session.accessToken
                                )
                            }
                        }
                        .disabled(viewModel.isLoadingPlayback)

                        if viewModel.isLoadingPlayback {
                            ProgressView("Preparing Playback")
                        }

                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(40)
        }
        .navigationTitle(item.name)
        .sheet(isPresented: $viewModel.shouldStartPlayer) {
            if let session = appState.currentSession,
               let source = viewModel.playbackInfo?.preferredSource,
               let url = playbackURL(source: source, serverURL: session.serverURL, token: session.accessToken) {
                VideoPlayerView(
                    url: url,
                    item: item,
                    source: source,
                    sessionID: viewModel.playbackInfo?.playSessionId ?? "",
                    token: session.accessToken,
                    api: api
                )
            } else {
                Text("Playback Unavailable")
                    .font(.title2.weight(.semibold))
                    .padding(40)
            }
        }
        .confirmationDialog(
            "Resume Playback",
            isPresented: $viewModel.showResumePrompt
        ) {
            Button("Resume") {
                Task {
                    guard let session = appState.currentSession else {
                        return
                    }
                    await viewModel.startPlayback(
                        userID: session.userID,
                        token: session.accessToken
                    )
                }
            }

            Button("Start Over") {
                Task {
                    guard let session = appState.currentSession else {
                        return
                    }
                    await viewModel.startPlayback(
                        userID: session.userID,
                        token: session.accessToken
                    )
                }
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let year = item.productionYear {
                Text(String(year))
            }
            if let rating = item.officialRating {
                Text(rating)
            }
            if let duration = item.durationFormatted {
                Text(duration)
            }
            if let score = item.communityRating {
                Text(String(format: "★ %.1f", score))
            }
        }
        .font(.headline)
        .foregroundStyle(.secondary)
    }

    private var posterURL: URL? {
        guard let session = appState.currentSession else {
            return nil
        }

        return session.serverURL
            .appendingPathComponent(Endpoints.primaryImage(itemID: item.id))
            .appending(queryItems: [
                URLQueryItem(name: "tag", value: item.primaryImageTag),
                URLQueryItem(name: "quality", value: "90"),
                URLQueryItem(name: "maxWidth", value: "720")
            ])
    }

    private func playbackURL(source: MediaSource, serverURL: URL, token: String) -> URL? {
        if let path = source.directStreamUrl ?? source.transcodingUrl {
            if let absolute = URL(string: path), absolute.scheme != nil {
                return absolute
            }

            let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let relativeURL = serverURL.appendingPathComponent(trimmedPath)
            return appendPlaybackQueryItems(to: relativeURL, source: source, token: token)
        }

        guard let sourceID = source.id else {
            return nil
        }

        let container = source.container ?? "mp4"
        let synthesized = serverURL.appendingPathComponent("/Videos/\(item.id)/stream.\(container)")
        return appendPlaybackQueryItems(to: synthesized, sourceID: sourceID, token: token)
    }

    private func appendPlaybackQueryItems(to url: URL, source: MediaSource, token: String) -> URL {
        appendPlaybackQueryItems(to: url, sourceID: source.id, token: token)
    }

    private func appendPlaybackQueryItems(to url: URL, sourceID: String?, token: String) -> URL {
        var items = [
            URLQueryItem(name: "api_key", value: token),
            URLQueryItem(name: "static", value: "true")
        ]

        if let sourceID {
            items.append(URLQueryItem(name: "mediaSourceId", value: sourceID))
        }

        return url.appending(queryItems: items)
    }
}
