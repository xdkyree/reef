import Foundation

// MARK: - Endpoints
//
// Centralises all Jellyfin REST API path construction.
// Each static func/property returns a raw path string; the base URL is
// prepended by `JellyfinAPIClient`.
//
// Jellyfin REST API reference: https://api.jellyfin.org (v10.8+)

public enum Endpoints {

    // MARK: Auth
    /// POST  — Authenticate a user by username and password.
    public static let authenticateByName = "/Users/AuthenticateByName"

    // MARK: Users
    /// GET  — Retrieve all users visible to the current session.
    public static let users = "/Users"

    /// GET  — Retrieve the profile of a specific user.
    public static func user(id: String) -> String {
        "/Users/\(id)"
    }

    // MARK: Items
    /// GET  — Fetch items in a user's library (supports pagination).
    public static func items(userID: String) -> String {
        "/Users/\(userID)/Items"
    }

    // MARK: Resume / Continue Watching
    /// GET  — Items that are in-progress for the user.
    public static func resumeItems(userID: String) -> String {
        "/Users/\(userID)/Items/Resume"
    }

    // MARK: Next Up
    /// GET  — Next-up episodes for the user.
    public static func nextUp(userID: String) -> String {
        "/Shows/NextUp"
    }

    // MARK: Playback
    /// POST  — Get playback info (direct stream URLs, codec info) for an item.
    public static func playbackInfo(itemID: String) -> String {
        "/Items/\(itemID)/PlaybackInfo"
    }

    /// POST  — Report playback started.
    public static let playbackStart = "/Sessions/Playing"

    /// POST  — Report in-progress playback position.
    public static let playbackProgress = "/Sessions/Playing/Progress"

    /// DELETE  — Report playback stopped.
    public static let playbackStopped = "/Sessions/Playing/Stopped"

    // MARK: Images
    /// GET  — Primary image for an item (thumbnail, poster).
    public static func primaryImage(itemID: String) -> String {
        "/Items/\(itemID)/Images/Primary"
    }

    /// GET  — Backdrop image for an item (wide art used in Detail).
    public static func backdropImage(itemID: String, index: Int = 0) -> String {
        "/Items/\(itemID)/Images/Backdrop/\(index)"
    }

    // MARK: Minimum supported server version
    /// Reef requires Jellyfin REST API v10.8 or later.
    /// The handshake in `AuthenticationService` validates this.
    public static let minimumServerVersion = "10.8.0"
}
