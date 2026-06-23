import SwiftUI

// MARK: - OnboardingView
//
// The first screen a new user sees. Presents server URL + credential fields
// and navigates to HomeView on successful authentication.
// Uses @State directly — auth is delegated to AppState.

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState

    @State private var serverURLText: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    // MARK: - Validation

    private var isInputValid: Bool {
        !serverURLText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.reefBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.reefAccent.opacity(0.12), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                brandingPanel
                    .frame(maxWidth: .infinity)
                loginPanel
                    .frame(maxWidth: 580)
            }
        }
        .alert(
            "Connection Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Connect Action

    private func connect() async {
        guard isInputValid else {
            errorMessage = "Please fill in all fields."
            return
        }
        var urlString = serverURLText.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        guard let url = URL(string: urlString) else {
            errorMessage = "The server URL is invalid."
            return
        }

        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        do {
            let session = try await appState.login(serverURL: url, username: username, password: password)
            appState.setSession(session)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Branding Panel

    private var brandingPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Spacer()
            Text("reef")
                .font(.system(size: 80, weight: .bold, design: .default))
                .italic()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.reefAccent, Color.reefAccent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Your media.\nNatively direct-played.")
                .font(.reefTitle)
                .foregroundStyle(Color.reefLabel)
            Text("Native tvOS Jellyfin client.\nZero transcoding. Zero compromise.")
                .font(.reefBody)
                .foregroundStyle(Color.reefLabelSecondary)
                .lineSpacing(4)
            Spacer()
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Login Panel

    private var loginPanel: some View {
        GlassmorphicCard(padding: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Connect to Jellyfin")
                    .font(.reefTitleSecondary)
                    .foregroundStyle(Color.reefLabel)

                VStack(spacing: Spacing.md) {
                    labeledField(
                        label: "Server URL",
                        placeholder: "http://192.168.1.100:8096",
                        text: $serverURLText,
                        isSecure: false
                    )
                    labeledField(
                        label: "Username",
                        placeholder: "Enter your username",
                        text: $username,
                        isSecure: false
                    )
                    labeledField(
                        label: "Password",
                        placeholder: "Enter your password",
                        text: $password,
                        isSecure: true
                    )
                }

                connectButton
            }
        }
        .padding(.vertical, Spacing.xxl)
        .padding(.trailing, Spacing.xxl)
    }

    @ViewBuilder
    private func labeledField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.reefCaption)
                .foregroundStyle(Color.reefLabelSecondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.reefBody)
            .foregroundStyle(Color.reefLabel)
            .padding(Spacing.md)
            .background(Color.reefSurface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.buttonCornerRadius, style: .continuous)
                    .strokeBorder(Color.reefGlassBorder, lineWidth: 1)
            )
        }
    }

    private var connectButton: some View {
        FocusScaleButton(action: { Task { await connect() } }) {
            HStack(spacing: Spacing.sm) {
                if isConnecting {
                    ProgressView()
                        .tint(Color.reefOnAccent)
                        .scaleEffect(0.8)
                }
                Text(isConnecting ? "Connecting…" : "Connect")
                    .font(.reefBodyEmphasized)
                    .foregroundStyle(Color.reefOnAccent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
        }
        .disabled(isConnecting || !isInputValid)
        .padding(.top, Spacing.md)
    }
}
