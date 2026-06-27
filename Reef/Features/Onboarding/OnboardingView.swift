import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OnboardingFormView(
            connectAction: { serverURL, username, password in
                try await appState.login(
                    serverURL: serverURL,
                    username: username,
                    password: password
                )
            },
            onSuccess: { session in
                appState.setSession(session)
            }
        )
    }
}

private struct OnboardingFormView: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(
        connectAction: @escaping @Sendable (URL, String, String) async throws -> UserSession,
        onSuccess: @escaping (UserSession) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                connectAction: connectAction,
                onSuccess: onSuccess
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("http://jellyfin.lan", text: $viewModel.serverURLText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(viewModel.isConnecting)

                    Text(
                        "Use your Jellyfin address exactly as it works in your browser, " +
                        "for example `http://jellyfin.lan`."
                    )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Account") {
                    TextField("Username", text: $viewModel.username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(viewModel.isConnecting)

                    SecureField("Password", text: $viewModel.password)
                        .disabled(viewModel.isConnecting)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.connect()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isConnecting {
                                ProgressView()
                            } else {
                                Text("Connect")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isConnecting)
                }
            }
            .navigationTitle("Connect to Jellyfin")
            .alert(
                "Connection Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
