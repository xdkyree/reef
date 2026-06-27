import SwiftUI

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: Published state
    @Published var serverURLText: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didConnect = false

    // MARK: Dependencies
    private let connectAction: @Sendable (URL, String, String) async throws -> UserSession
    private let onSuccess: (UserSession) -> Void

    // MARK: Init
    init(
        connectAction: @escaping @Sendable (URL, String, String) async throws -> UserSession,
        onSuccess: @escaping (UserSession) -> Void
    ) {
        self.connectAction = connectAction
        self.onSuccess = onSuccess
    }

    convenience init(
        authService: any AuthenticationServiceProtocol,
        onSuccess: @escaping (UserSession) -> Void
    ) {
        self.init(
            connectAction: { serverURL, username, password in
                try await authService.login(
                    serverURL: serverURL,
                    username: username,
                    password: password
                )
            },
            onSuccess: onSuccess
        )
    }

    // MARK: - Validation

    var isInputValid: Bool {
        !serverURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Connect

    func connect() async {
        guard isInputValid else {
            errorMessage = "Please fill in all fields."
            return
        }

        // Normalise URL — prepend https if no scheme given.
        var urlString = serverURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "The server URL is invalid."
            return
        }

        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        do {
            let session = try await connectAction(
                url,
                username.trimmingCharacters(in: .whitespacesAndNewlines),
                password
            )
            didConnect = true
            onSuccess(session)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
