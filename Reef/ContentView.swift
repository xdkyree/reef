import SwiftUI

// MARK: - ContentView
//
// Root navigation coordinator. Decides whether to show Onboarding or Home
// based on the active session in `AppState`.

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isRestoringSession {
                launchScreen
            } else if appState.currentSession != nil {
                HomeView(api: appState.apiClient)
            } else {
                OnboardingView()
            }
        }
        .task {
            await appState.restoreSession()
        }
    }

    // MARK: - Launch Screen

    private var launchScreen: some View {
        ZStack {
            Color.reefBackground.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                // App wordmark placeholder — replace with asset when branding is finalized.
                Text("reef")
                    .font(.reefDisplayTitle)
                    .foregroundStyle(Color.reefAccent)
                    .italic()
                ProgressView()
                    .tint(Color.reefLabelSecondary)
            }
        }
    }
}
