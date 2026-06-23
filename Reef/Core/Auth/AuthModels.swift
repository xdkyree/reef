import Foundation

// MARK: - AuthModels
//
// Value types representing authentication state. These are the only
// auth-related types that cross the Core/Features boundary.

// MARK: AuthResponse

/// Decoded response from POST /Users/AuthenticateByName.
public struct AuthResponse: Decodable, Sendable {
    public let accessToken: String
    public let serverId: String
    public let user: JellyfinUser
    public let sessionInfo: SessionInfo?

    enum CodingKeys: String, CodingKey {
        case accessToken   = "AccessToken"
        case serverId      = "ServerId"
        case user          = "User"
        case sessionInfo   = "SessionInfo"
    }
}

// MARK: SessionInfo

public struct SessionInfo: Decodable, Sendable {
    public let id: String?
    public let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id       = "Id"
        case deviceId = "DeviceId"
    }
}

// MARK: UserSession

/// Represents an active, authenticated Reef session.
/// Stored in memory by `AuthenticationService`; the `accessToken` is
/// persisted separately in Keychain. This struct itself is never written
/// to disk or `UserDefaults`.
public struct UserSession: Equatable, Sendable {
    public let userID: String
    public let userName: String
    public let accessToken: String
    public let serverId: String
    public let serverURL: URL

    public init(
        userID: String,
        userName: String,
        accessToken: String,
        serverId: String,
        serverURL: URL
    ) {
        self.userID = userID
        self.userName = userName
        self.accessToken = accessToken
        self.serverId = serverId
        self.serverURL = serverURL
    }
}

// MARK: StoredCredentials
//
// Lightweight bundle written to Keychain so the app can restore
// a session after relaunch without asking for the password again.

public struct StoredCredentials: Codable, Sendable {
    public let userID: String
    public let userName: String
    public let accessToken: String
    public let serverId: String
    public let serverURL: URL
}
