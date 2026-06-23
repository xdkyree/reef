import SwiftUI

// MARK: - HomeView
//
// Dashboard with four horizontal carousels:
// "Continue Watching", "Next Up", "Recently Added Movies", "Recently Added Shows".

struct HomeView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: HomeViewModel

    @State private var selectedItem: MediaItem?

    init(api: JellyfinAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(api: api))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.reefBackground.ignoresSafeArea()

            if viewModel.isLoading && viewModel.continueWatching.isEmpty {
                loadingView
            } else {
                contentView
            }
        }
        .sheet(item: $selectedItem) { item in
            if let session = appState.currentSession {
                DetailView(item: item, api: appState.apiClient)
                    .environmentObject(appState)
            }
        }
        .task {
            guard let session = appState.currentSession else {
                return
            }
            await viewModel.loadDashboard(userID: session.userID, token: session.accessToken)
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Spacing.carouselRowGap) {
                headerView
                    .padding(.horizontal, Spacing.sectionPadding)
                    .padding(.top, Spacing.xxl)

                if !viewModel.continueWatching.isEmpty {
                    carousel("Continue Watching", items: viewModel.continueWatching)
                }
                if !viewModel.nextUp.isEmpty {
                    carousel("Next Up", items: viewModel.nextUp)
                }
                if !viewModel.recentlyAddedMovies.isEmpty {
                    carousel("Recently Added Movies", items: viewModel.recentlyAddedMovies)
                }
                if !viewModel.recentlyAddedShows.isEmpty {
                    carousel("Recently Added Shows", items: viewModel.recentlyAddedShows)
                }

                if let error = viewModel.error {
                    errorView(error)
                        .padding(.horizontal, Spacing.sectionPadding)
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    @ViewBuilder
    private func carousel(_ title: String, items: [MediaItem]) -> some View {
        CarouselSectionView(
            title: title,
            items: items,
            serverURL: appState.currentSession?.serverURL ?? URL(string: "http://localhost")!,
            onSelectItem: { selectedItem = $0 }
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Good \(timeOfDayGreeting())")
                    .font(.reefCaption)
                    .foregroundStyle(Color.reefLabelSecondary)
                Text(appState.currentSession?.userName ?? "Reef")
                    .font(.reefTitle)
                    .foregroundStyle(Color.reefLabel)
            }
            Spacer()
            Text("reef")
                .font(.reefTitleSecondary)
                .italic()
                .foregroundStyle(Color.reefAccent)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .tint(Color.reefAccent)
                .scaleEffect(1.5)
            Text("Loading your library…")
                .font(.reefSubtitle)
                .foregroundStyle(Color.reefLabelSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ error: Error) -> some View {
        GlassmorphicCard {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.reefWarning)
                Text(error.localizedDescription)
                    .font(.reefBody)
                    .foregroundStyle(Color.reefLabel)
                    .multilineTextAlignment(.center)
                FocusScaleButton(
                    action: {
                        Task {
                            guard let session = appState.currentSession else {
                                return
                            }
                            await viewModel.refresh(userID: session.userID, token: session.accessToken)
                        }
                    },
                    label: {
                        Text("Retry")
                            .font(.reefBodyEmphasized)
                            .foregroundStyle(Color.reefOnAccent)
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}
