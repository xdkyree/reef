import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: HomeViewModel

    init(api: JellyfinAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(api: api))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                ProgressView("Loading Home")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.sections.isEmpty {
                errorState(error)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        header
                        ForEach(viewModel.sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.title3.weight(.semibold))

                                ScrollView(.horizontal) {
                                    LazyHStack(spacing: 20) {
                                        ForEach(section.items) { item in
                                            NavigationLink {
                                                DetailView(item: item, api: appState.apiClient)
                                            } label: {
                                                MediaCardView(
                                                    item: item,
                                                    serverURL: appState.currentSession?.serverURL
                                                )
                                            }
                                            .buttonStyle(.card)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
        .navigationTitle("Home")
        .task {
            guard let session = appState.currentSession else {
                return
            }
            await viewModel.loadDashboard(userID: session.userID, token: session.accessToken)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good \(timeOfDayGreeting())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(appState.currentSession?.userName ?? "Reef")
                .font(.largeTitle.bold())
        }
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 24) {
            Text("Could not load your library.")
                .font(.title2.weight(.semibold))
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Button("Retry") {
                    Task {
                        guard let session = appState.currentSession else {
                            return
                        }
                        await viewModel.refresh(userID: session.userID, token: session.accessToken)
                    }
                }

                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.clearSession()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        default:
            return "evening"
        }
    }
}
