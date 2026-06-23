import SwiftUI

// MARK: - LibraryView
//
// Paginated lazy grid for a single Jellyfin library.

struct LibraryView: View {

    let library: UserLibrary
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: LibraryViewModel
    @State private var selectedItem: MediaItem?

    private let columns = [
        GridItem(.adaptive(minimum: Spacing.mediaCardWidth, maximum: 340), spacing: Spacing.gridSpacing)
    ]

    init(library: UserLibrary, api: JellyfinAPIClientProtocol) {
        self.library = library
        _viewModel = StateObject(wrappedValue: LibraryViewModel(
            api: api,
            libraryID: library.id
        ))
    }

    var body: some View {
        ZStack {
            Color.reefBackground.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.items.isEmpty {
                emptyView
            } else {
                gridContent
            }
        }
        .sheet(item: $selectedItem) { item in
            DetailView(item: item)
        }
        .task {
            guard let session = appState.currentSession else {
                return
            }
            await viewModel.loadFirstPage(userID: session.userID, token: session.accessToken)
        }
    }

    // MARK: - Grid

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.gridSpacing) {
                ForEach(viewModel.items) { item in
                    if let session = appState.currentSession {
                        MediaCardView(
                            item: item,
                            serverURL: session.serverURL,
                            onTap: { selectedItem = item }
                        )
                        .onAppear {
                            Task {
                                guard let session = appState.currentSession else {
                                    return
                                }
                                await viewModel.loadNextPageIfNeeded(
                                    userID: session.userID,
                                    token: session.accessToken,
                                    currentItem: item
                                )
                            }
                        }
                    }
                }

                // Pagination footer
                if viewModel.isLoadingNextPage {
                    ProgressView()
                        .tint(Color.reefAccent)
                        .frame(height: 80)
                        .gridCellColumns(columns.count)
                }
            }
            .padding(.horizontal, Spacing.sectionPadding)
            .padding(.vertical, Spacing.lg)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        ProgressView()
            .tint(Color.reefAccent)
            .scaleEffect(1.5)
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundStyle(Color.reefLabelTertiary)
            Text("No items in \(library.name)")
                .font(.reefTitle)
                .foregroundStyle(Color.reefLabelSecondary)
        }
    }
}
