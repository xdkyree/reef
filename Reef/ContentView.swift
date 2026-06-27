import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isRestoringSession {
                ProgressView("Loading Reef")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.currentSession != nil {
                AppTabShell()
            } else {
                OnboardingView()
            }
        }
        .task {
            await appState.restoreSession()
        }
    }
}

private struct AppTabShell: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(api: appState.apiClient)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                LibrariesView(api: appState.apiClient)
            }
            .tabItem {
                Label("Libraries", systemImage: "film.stack")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isWorking = false

    var body: some View {
        List {
            Section("Server") {
                LabeledContent("Address", value: appState.currentSession?.serverURL.absoluteString ?? "Not connected")
                LabeledContent("Username", value: appState.currentSession?.userName ?? "Unknown")
            }

            Section("Session") {
                Button("Forget Saved Session", role: .destructive) {
                    Task {
                        isWorking = true
                        await appState.clearSession()
                        isWorking = false
                    }
                }
                .disabled(isWorking)

                Button("Change Server") {
                    Task {
                        isWorking = true
                        await appState.clearSession()
                        isWorking = false
                    }
                }
                .disabled(isWorking)

                Button("Sign Out", role: .destructive) {
                    Task {
                        isWorking = true
                        await appState.clearSession()
                        isWorking = false
                    }
                }
                .disabled(isWorking)
            }
        }
        .navigationTitle("Settings")
    }
}
