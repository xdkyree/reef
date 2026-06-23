import Foundation
import os.log

// MARK: - AuthenticationServiceProtocol

public protocol AuthenticationServiceProtocol: Sendable {
    var currentSession: UserSession? { get async }
    func login(serverURL: URL, username: String, password: String) async throws -> UserSession
    func logout() async throws
    func restoreSession() async throws -> UserSession?
    func switchProfile(to user: JellyfinUser) async throws -> UserSession
}

// MARK: - AuthenticationError

public enum AuthenticationError: Error, Equatable {
    case invalidServerURL
    case loginFailed(String)
    case sessionExpired
    case noStoredSession
    case serverVersionTooOld(String)
}

extension AuthenticationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "The server URL is invalid. Please check the address and try again."
        case .loginFailed(let reason):
            return "Login failed: \(reason)"
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .noStoredSession:
            return "No saved session found."
        case .serverVersionTooOld(let version):
            return "Your Jellyfin server (\(version)) is too old. Reef requires \(Endpoints.minimumServerVersion)+."
        }
    }
}

// MARK: - AuthenticationService

/// Owns the lifecycle of the active `UserSession`.
/// All login/logout state flows through this actor; no ViewModel or View
/// should ever hold a token directly.
public actor AuthenticationService: AuthenticationServiceProtocol {

    // MARK: Properties

    private(set) public var currentSession: UserSession?

    private let apiClient: JellyfinAPIClientProtocol
    private let keychain: KeychainServiceProtocol
    private let logger = Logger(subsystem: "com.reef.app", category: "AuthenticationService")

    // MARK: Init

    public init(
        apiClient: JellyfinAPIClientProtocol,
        keychain: KeychainServiceProtocol
    ) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    // MARK: - Login

    /// Authenticates against the Jellyfin server and caches the token to Keychain.
    /// - Returns: The newly created `UserSession`.
    public func login(
        serverURL: URL,
        username: String,
        password: String
    ) async throws -> UserSession {
        // Validate URL
        guard serverURL.scheme == "http" || serverURL.scheme == "https" else {
            throw AuthenticationError.invalidServerURL
        }

        logger.info("Attempting login for user '\(username)' at \(serverURL.absoluteString)")

        let response: AuthResponse
        do {
            response = try await apiClient.authenticate(
                serverURL: serverURL,
                username: username,
                password: password
            )
        } catch NetworkError.unauthorized {
            throw AuthenticationError.loginFailed("Invalid username or password.")
        } catch let error as NetworkError {
            throw AuthenticationError.loginFailed(error.localizedDescription)
        }

        let session = UserSession(
            userID: response.user.id,
            userName: response.user.name,
            accessToken: response.accessToken,
            serverId: response.serverId,
            serverURL: serverURL
        )

        // Persist to Keychain
        let stored = StoredCredentials(
            userID: session.userID,
            userName: session.userName,
            accessToken: session.accessToken,
            serverId: session.serverId,
            serverURL: session.serverURL
        )
        try await keychain.save(stored)

        currentSession = session
        logger.info("Login successful for user '\(session.userName)'.")
        return session
    }

    // MARK: - Logout

    /// Clears the in-memory session and removes the Keychain entry.
    public func logout() async throws {
        currentSession = nil
        try await keychain.delete()
        logger.info("User logged out; session and Keychain entry cleared.")
    }

    // MARK: - Session Restoration

    /// Attempts to restore a session from Keychain on app launch.
    /// Returns `nil` (not throws) when no session has ever been saved.
    public func restoreSession() async throws -> UserSession? {
        guard let stored = try await keychain.load() else {
            logger.debug("No stored session found in Keychain.")
            return nil
        }

        let session = UserSession(
            userID: stored.userID,
            userName: stored.userName,
            accessToken: stored.accessToken,
            serverId: stored.serverId,
            serverURL: stored.serverURL
        )
        currentSession = session
        logger.info("Restored session for user '\(stored.userName)'.")
        return session
    }

    // MARK: - Profile Switching

    /// Switches the active profile to another user on the same server.
    /// For MVP: re-authenticates if a new token is needed; the server URL
    /// is preserved so the user does not need to re-enter it.
    ///
    /// - Note: This currently triggers a re-login prompt via the UI since
    ///   Jellyfin does not support token-based profile switching. A future
    ///   version may support quick-switch with admin tokens.
    public func switchProfile(to user: JellyfinUser) async throws -> UserSession {
        guard let current = currentSession else {
            throw AuthenticationError.sessionExpired
        }
        // Re-use server URL; caller must provide new credentials via UI.
        // This stub is replaced with full implementation in Task 24.
        throw AuthenticationError.loginFailed(
            "Profile switching to '\(user.name)' requires re-authentication. " +
            "Full implementation in M4 Task 24. Server: \(current.serverURL)"
        )
    }
}
