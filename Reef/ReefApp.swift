import SwiftUI

// MARK: - ReefApp
//
// Application entry point. Assembles the dependency container and injects
// all actors into the SwiftUI environment before any view is rendered.

@main
struct ReefApp: App {

    // MARK: Dependency Container
    // One instance of each actor — shared across the entire app lifetime.
    private let apiClient: JellyfinAPIClient
    private let keychain: KeychainService
    private let authService: AuthenticationService
    private let imageCache: ImageCache

    init() {
        // Bootstrap with a placeholder URL; the real URL is set after login.
        let placeholderURL = URL(string: "http://localhost:8096")!
        let api = JellyfinAPIClient(baseURL: placeholderURL)
        let kc  = KeychainService()
        let auth = AuthenticationService(apiClient: api, keychain: kc)
        let cache = ImageCache()

        self.apiClient   = api
        self.keychain    = kc
        self.authService = auth
        self.imageCache  = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState(authService: authService, apiClient: apiClient))
                .environment(\.imageCache, imageCache)
        }
    }
}

// MARK: - AppState
//
// Bridges the async actor world into the SwiftUI @Published world.
// All ViewModels observe this object for session changes.

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var currentSession: UserSession?
    @Published private(set) var isRestoringSession = true

    private let authService: AuthenticationService
    private(set) var apiClient: JellyfinAPIClient

    init(authService: AuthenticationService, apiClient: JellyfinAPIClient) {
        self.authService = authService
        self.apiClient   = apiClient
    }

    /// Called once on app launch; restores a persisted session if available.
    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }
        do {
            currentSession = try await authService.restoreSession()
        } catch {
            // No stored session — user will see Onboarding.
            currentSession = nil
        }
    }

    /// Called by `OnboardingView` to attempt login and update the session on success.
    func login(serverURL: URL, username: String, password: String) async throws -> UserSession {
        let session = try await authService.login(
            serverURL: serverURL,
            username: username,
            password: password
        )
        return session
    }

    /// Called by `OnboardingViewModel` after successful login.
    func setSession(_ session: UserSession) {
        currentSession = session
        // Update the API client with the confirmed server URL.
        Task { await apiClient.updateBaseURL(session.serverURL) }
    }

    /// Called by the profile/logout action.
    func clearSession() async {
        do { try await authService.logout() } catch { /* log */ }
        currentSession = nil
    }
}

// MARK: - ImageCache Environment Key

private enum ImageCacheKey: EnvironmentKey {
    static let defaultValue = ImageCache()
}

extension EnvironmentValues {
    var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
