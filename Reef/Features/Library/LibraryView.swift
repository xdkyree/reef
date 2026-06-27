import SwiftUI

struct LibrariesView: View {
    @EnvironmentObject private var appState: AppState
    private let api: JellyfinAPIClientProtocol

    @State private var libraries: [UserLibrary] = []
    @State private var isLoading = false
    @State private var error: Error?

    init(api: JellyfinAPIClientProtocol) {
        self.api = api
    }

    var body: some View {
        Group {
            if isLoading && libraries.isEmpty {
                ProgressView("Loading Libraries")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, libraries.isEmpty {
                VStack(spacing: 20) {
                    Text("Could not load libraries.")
                        .font(.title2.weight(.semibold))
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadLibraries() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List(filteredLibraries) { library in
                    NavigationLink {
                        LibraryView(library: library, api: api)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(library.name)
                            Text(library.collectionType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Libraries")
        .task {
            await loadLibraries()
        }
    }

    private var filteredLibraries: [UserLibrary] {
        libraries.filter {
            [.movies, .tvshows, .mixed, .unknown, .homevideos].contains($0.collectionType)
        }
    }

    private func loadLibraries() async {
        guard let session = appState.currentSession else {
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            libraries = try await api.fetchUserLibraries(
                userID: session.userID,
                token: session.accessToken
            )
        } catch {
            self.error = error
        }
    }
}

struct LibraryView: View {
    let library: UserLibrary

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: LibraryViewModel

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 28)]

    init(library: UserLibrary, api: JellyfinAPIClientProtocol) {
        self.library = library
        _viewModel = StateObject(
            wrappedValue: LibraryViewModel(
                api: api,
                libraryID: library.id,
                libraryType: library.collectionType
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("Loading \(library.name)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                VStack(spacing: 20) {
                    Text("Could not load \(library.name).")
                        .font(.title2.weight(.semibold))
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadFirstPage() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "film")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                DetailView(item: item, api: appState.apiClient)
                            } label: {
                                MediaCardView(
                                    item: item,
                                    serverURL: appState.currentSession?.serverURL
                                )
                            }
                            .buttonStyle(.card)
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
                    .padding(40)
                }
            }
        }
        .navigationTitle(library.name)
        .task {
            await loadFirstPage()
        }
    }

    private func loadFirstPage() async {
        guard let session = appState.currentSession else {
            return
        }
        await viewModel.loadFirstPage(userID: session.userID, token: session.accessToken)
    }
}

private extension LibraryType {
    var displayName: String {
        switch self {
        case .movies:
            return "Movies"
        case .tvshows:
            return "TV Shows"
        case .mixed:
            return "Mixed"
        case .homevideos:
            return "Home Videos"
        default:
            return "Library"
        }
    }
}
