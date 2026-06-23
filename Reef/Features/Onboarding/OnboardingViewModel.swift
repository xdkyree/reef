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
    private let authService: AuthenticationService
    private let onSuccess: (UserSession) -> Void

    // MARK: Init
    init(authService: AuthenticationService, onSuccess: @escaping (UserSession) -> Void) {
        self.authService = authService
        self.onSuccess = onSuccess
    }

    // MARK: - Validation

    var isInputValid: Bool {
        !serverURLText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Connect

    func connect() async {
        guard isInputValid else {
            errorMessage = "Please fill in all fields."
            return
        }

        // Normalise URL — prepend https if no scheme given.
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
            let session = try await authService.login(
                serverURL: url,
                username: username,
                password: password
            )
            onSuccess(session)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
