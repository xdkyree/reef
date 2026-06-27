import SwiftUI

@main
struct ReefApp: App {
    private let apiClient: JellyfinAPIClient
    private let keychain: KeychainService
    private let authService: AuthenticationService
    private let imageCache: ImageCache

    init() {
        let placeholderURL = URL(string: "http://localhost:8096")!
        let api = JellyfinAPIClient(baseURL: placeholderURL)
        let kc = KeychainService()
        let auth = AuthenticationService(apiClient: api, keychain: kc)
        let cache = ImageCache()

        self.apiClient = api
        self.keychain = kc
        self.authService = auth
        self.imageCache = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState(authService: authService, apiClient: apiClient))
                .environment(\.imageCache, imageCache)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var currentSession: UserSession?
    @Published private(set) var isRestoringSession = true

    private let authService: AuthenticationService
    private(set) var apiClient: JellyfinAPIClient

    init(authService: AuthenticationService, apiClient: JellyfinAPIClient) {
        self.authService = authService
        self.apiClient = apiClient
    }

    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            guard let session = try await authService.restoreSession() else {
                currentSession = nil
                return
            }

            await apiClient.updateBaseURL(session.serverURL)
            _ = try await apiClient.fetchUser(userID: session.userID, token: session.accessToken)
            currentSession = session
        } catch {
            do {
                try await authService.logout()
            } catch {
            }
            currentSession = nil
        }
    }

    func login(serverURL: URL, username: String, password: String) async throws -> UserSession {
        try await authService.login(serverURL: serverURL, username: username, password: password)
    }

    func setSession(_ session: UserSession) {
        currentSession = session
        Task {
            await apiClient.updateBaseURL(session.serverURL)
        }
    }

    func clearSession() async {
        do {
            try await authService.logout()
        } catch {
        }
        currentSession = nil
    }
}

private enum ImageCacheKey: EnvironmentKey {
    static let defaultValue = ImageCache()
}

extension EnvironmentValues {
    var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
