import Foundation
import os.log

// MARK: - JellyfinAPIClientProtocol
//
// Exposes the full interface so tests can inject `MockJellyfinAPIClient`
// without any real network calls.

public protocol JellyfinAPIClientProtocol: Sendable {

    // Auth
    func authenticate(
        serverURL: URL,
        username: String,
        password: String
    ) async throws -> AuthResponse

    func fetchUser(userID: String, token: String) async throws -> JellyfinUser

    func fetchAllUsers(token: String) async throws -> [JellyfinUser]

    // Dashboard feeds
    func fetchContinueWatching(userID: String, token: String) async throws -> [MediaItem]
    func fetchNextUp(userID: String, token: String) async throws -> [MediaItem]
    func fetchRecentlyAdded(
        userID: String,
        libraryID: String?,
        token: String,
        limit: Int
    ) async throws -> [MediaItem]

    // Library
    func fetchLibraryItems(
        userID: String,
        parentID: String,
        libraryType: LibraryType,
        token: String,
        startIndex: Int,
        limit: Int
    ) async throws -> PaginatedResult<MediaItem>

    func fetchUserLibraries(userID: String, token: String) async throws -> [UserLibrary]

    // Playback
    func fetchPlaybackInfo(
        itemID: String,
        userID: String,
        token: String,
        deviceProfile: DeviceProfile
    ) async throws -> PlaybackInfo

    // Progress reporting
    func reportPlaybackStarted(sessionID: String, itemID: String, token: String) async throws
    func reportPlaybackProgress(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        isPaused: Bool,
        token: String
    ) async throws
    func reportPlaybackStopped(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        token: String
    ) async throws
}

// MARK: - JellyfinAPIClient

/// The single actor responsible for all HTTP communication with the
/// Jellyfin server. Never call `URLSession` directly from any ViewModel
/// or Feature code — always go through this actor.
public actor JellyfinAPIClient: JellyfinAPIClientProtocol {

    // MARK: Properties

    private var baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.reef.app", category: "JellyfinAPIClient")

    // MARK: Device identity (sent in every Authorization header)
    private static let deviceName = "Reef"
    private static let deviceID: String = {
        // Stable per-install identifier stored in UserDefaults is acceptable
        // for the non-sensitive device ID field (not auth credentials).
        if let stored = UserDefaults.standard.string(forKey: "reef.deviceID") {
            return stored
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "reef.deviceID")
        return newID
    }()
    private static let clientVersion = "1.0.0"

    // MARK: Init

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Update the base URL (called when the user changes the server address).
    public func updateBaseURL(_ url: URL) {
        baseURL = url
    }

    // MARK: - Auth

    public func authenticate(
        serverURL: URL,
        username: String,
        password: String
    ) async throws -> AuthResponse {
        // The auth endpoint accepts a JSON body with Username + Pw.
        let body = AuthenticateByNameRequest(username: username, pw: password)
        var request = try buildRequest(
            path: Endpoints.authenticateByName,
            method: .post,
            baseURL: serverURL,
            body: body,
            token: nil          // No token on initial auth
        )
        // Jellyfin requires the X-Emby-Authorization header even before login.
        request.setValue(embyAuthorizationHeader(token: nil), forHTTPHeaderField: "X-Emby-Authorization")
        return try await perform(request, decoding: AuthResponse.self)
    }

    public func fetchUser(userID: String, token: String) async throws -> JellyfinUser {
        let request = try buildRequest(
            path: Endpoints.user(id: userID),
            method: .get,
            token: token
        )
        return try await perform(request, decoding: JellyfinUser.self)
    }

    public func fetchAllUsers(token: String) async throws -> [JellyfinUser] {
        let request = try buildRequest(
            path: Endpoints.users,
            method: .get,
            token: token
        )
        return try await perform(request, decoding: [JellyfinUser].self)
    }

    // MARK: - Dashboard Feeds

    public func fetchContinueWatching(
        userID: String,
        token: String
    ) async throws -> [MediaItem] {
        var request = try buildRequest(
            path: Endpoints.resumeItems(userID: userID),
            method: .get,
            token: token
        )
        request.url = request.url?.appending(queryItems: [
            URLQueryItem(name: "Limit", value: "20"),
            URLQueryItem(name: "Fields", value: "Overview,RunTimeTicks,UserData,PrimaryImageAspectRatio"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Episode")
        ])
        return try await perform(request, decoding: JellyfinItemsResponse.self).items
    }

    public func fetchNextUp(userID: String, token: String) async throws -> [MediaItem] {
        var request = try buildRequest(
            path: Endpoints.nextUp(userID: userID),
            method: .get,
            token: token
        )
        request.url = request.url?.appending(queryItems: [
            URLQueryItem(name: "UserId", value: userID),
            URLQueryItem(name: "Limit", value: "20"),
            URLQueryItem(name: "Fields", value: "Overview,RunTimeTicks,UserData,PrimaryImageAspectRatio"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb")
        ])
        return try await perform(request, decoding: JellyfinItemsResponse.self).items
    }

    public func fetchRecentlyAdded(
        userID: String,
        libraryID: String? = nil,
        token: String,
        limit: Int = 20
    ) async throws -> [MediaItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "Fields", value: "Overview,RunTimeTicks,UserData,PrimaryImageAspectRatio"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
            URLQueryItem(name: "IsPlayed", value: "false"),
            URLQueryItem(name: "SortBy", value: "DateCreated"),
            URLQueryItem(name: "SortOrder", value: "Descending")
        ]
        if let libraryID {
            queryItems.append(URLQueryItem(name: "ParentId", value: libraryID))
        }
        var request = try buildRequest(
            path: Endpoints.items(userID: userID),
            method: .get,
            token: token
        )
        request.url = request.url?.appending(queryItems: queryItems)
        return try await perform(request, decoding: JellyfinItemsResponse.self).items
    }

    // MARK: - Library

    public func fetchUserLibraries(userID: String, token: String) async throws -> [UserLibrary] {
        var request = try buildRequest(
            path: Endpoints.items(userID: userID),
            method: .get,
            token: token
        )
        request.url = request.url?.appending(queryItems: [
            URLQueryItem(name: "IncludeItemTypes", value: "CollectionFolder"),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,CollectionType")
        ])
        let response = try await perform(request, decoding: JellyfinItemsResponse.self)
        logger.debug("Loaded \(response.items.count) libraries for user \(userID)")
        return response.items.compactMap { UserLibrary(mediaItem: $0) }
    }

    public func fetchLibraryItems(
        userID: String,
        parentID: String,
        libraryType: LibraryType,
        token: String,
        startIndex: Int = 0,
        limit: Int = 50
    ) async throws -> PaginatedResult<MediaItem> {
        var request = try buildRequest(
            path: Endpoints.items(userID: userID),
            method: .get,
            token: token
        )
        request.url = request.url?.appending(queryItems: [
            URLQueryItem(name: "ParentId", value: parentID),
            URLQueryItem(name: "StartIndex", value: "\(startIndex)"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "IncludeItemTypes", value: libraryType.topLevelIncludeItemTypes),
            URLQueryItem(
                name: "Fields",
                value: "Overview,RunTimeTicks,UserData,PrimaryImageAspectRatio," +
                    "ProductionYear,OfficialRating,CommunityRating," +
                    "BackdropImageTags,PrimaryImageTag,CollectionType"
            ),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop")
        ])
        let response = try await perform(request, decoding: JellyfinItemsResponse.self)
        let libraryKind = libraryType.rawValue
        logger.debug("Loaded \(response.items.count) items for library \(parentID)")
        logger.debug("Library type \(libraryKind), start \(startIndex), total \(response.totalRecordCount)")
        return PaginatedResult(
            items: response.items.filter { $0.type != .episode },
            totalCount: response.totalRecordCount,
            startIndex: startIndex
        )
    }

    // MARK: - Playback

    public func fetchPlaybackInfo(
        itemID: String,
        userID: String,
        token: String,
        deviceProfile: DeviceProfile = .reef
    ) async throws -> PlaybackInfo {
        let body = PlaybackInfoRequest(userID: userID, deviceProfile: deviceProfile)
        let request = try buildRequest(
            path: Endpoints.playbackInfo(itemID: itemID),
            method: .post,
            body: body,
            token: token
        )
        return try await perform(request, decoding: PlaybackInfo.self)
    }

    // MARK: - Progress Reporting

    public func reportPlaybackStarted(
        sessionID: String,
        itemID: String,
        token: String
    ) async throws {
        let body = PlaybackStartInfo(itemID: itemID, sessionID: sessionID)
        let request = try buildRequest(
            path: Endpoints.playbackStart,
            method: .post,
            body: body,
            token: token
        )
        try await performVoid(request)
    }

    public func reportPlaybackProgress(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        isPaused: Bool,
        token: String
    ) async throws {
        let body = PlaybackProgressInfo(
            itemID: itemID,
            sessionID: sessionID,
            positionTicks: positionTicks,
            isPaused: isPaused
        )
        let request = try buildRequest(
            path: Endpoints.playbackProgress,
            method: .post,
            body: body,
            token: token
        )
        try await performVoid(request)
    }

    public func reportPlaybackStopped(
        sessionID: String,
        itemID: String,
        positionTicks: Int64,
        token: String
    ) async throws {
        let body = PlaybackStopInfo(
            itemID: itemID,
            sessionID: sessionID,
            positionTicks: positionTicks
        )
        let request = try buildRequest(
            path: Endpoints.playbackStopped,
            method: .delete,
            body: body,
            token: token
        )
        try await performVoid(request)
    }

    // MARK: - Private Helpers

    private func buildRequest<B: Encodable>(
        path: String,
        method: HTTPMethod,
        baseURL: URL? = nil,
        body: B? = nil,
        token: String?
    ) throws -> URLRequest {
        let base = baseURL ?? self.baseURL
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw NetworkError.unknown("Could not construct URL for path: \(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(embyAuthorizationHeader(token: token), forHTTPHeaderField: "X-Emby-Authorization")
        if let body {
            request.httpBody = try JSONEncoder.jellyfinEncoder.encode(body)
        }
        return request
    }

    // Overload for requests with no body (GET, DELETE without body).
    private func buildRequest(
        path: String,
        method: HTTPMethod,
        baseURL: URL? = nil,
        token: String?
    ) throws -> URLRequest {
        try buildRequest(path: path, method: method, baseURL: baseURL, body: Optional<String>.none, token: token)
    }

    private func embyAuthorizationHeader(token: String?) -> String {
        var parts = [
            "MediaBrowser Client=\"\(Self.deviceName)\"",
            "Device=\"\(Self.deviceName)\"",
            "DeviceId=\"\(Self.deviceID)\"",
            "Version=\"\(Self.clientVersion)\""
        ]
        if let token {
            parts.append("Token=\"\(token)\"")
        }
        return parts.joined(separator: ", ")
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        decoding type: T.Type
    ) async throws -> T {
        logger.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            do {
                let decoded = try JSONDecoder.jellyfinDecoder.decode(type, from: data)
                logger.debug("← 200 \(String(describing: T.self))")
                return decoded
            } catch let decodingError as DecodingError {
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let keys = object.keys.sorted().joined(separator: ", ")
                    logger.error("Auth decode received top-level keys: \(keys, privacy: .public)")
                }
                logger.error("""
                    Decode error for \(String(describing: T.self), privacy: .public): \
                    \(Self.describe(decodingError), privacy: .public)
                    """)
                throw NetworkError.decodingFailed(Self.describe(decodingError))
            } catch {
                logger.error("Decode error: \(error)")
                throw NetworkError.decodingFailed(error.localizedDescription)
            }
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            let requestURL = request.url?.absoluteString ?? ""
            logger.error("""
                URLSession failed with code \(urlError.code.rawValue, privacy: .public) \
                for \(requestURL, privacy: .public)
                """)
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        logger.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            let requestURL = request.url?.absoluteString ?? ""
            logger.error("""
                URLSession failed with code \(urlError.code.rawValue, privacy: .public) \
                for \(requestURL, privacy: .public)
                """)
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Non-HTTP response received.")
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        default:
            // Try to parse a Jellyfin error message from the body.
            if let message = try? JSONDecoder.jellyfinDecoder
                .decode(JellyfinErrorResponse.self, from: data).message {
                throw NetworkError.serverError(message)
            }
            throw NetworkError.unexpectedStatusCode(http.statusCode)
        }
    }

    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnectivity
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .cannotReachServer
        case .timedOut:
            return .timeout
        case .appTransportSecurityRequiresSecureConnection:
            return .cannotReachServer
        default:
            return .unknown(error.localizedDescription)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing key \(key.stringValue) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Corrupted data at \(codingPath(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else { return "<root>" }
        return path.map(\.stringValue).joined(separator: ".")
    }
}

// MARK: - JSONDecoder / JSONEncoder extensions

extension JSONDecoder {
    /// Shared decoder configured for Jellyfin's date format conventions.
    static let jellyfinDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Jellyfin returns ISO-8601 with fractional seconds.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(string)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    /// Shared encoder for request bodies sent to Jellyfin.
    static let jellyfinEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToUpperCamelCase
        return encoder
    }()
}

// MARK: - Internal request/response stubs used by the client

// These are thin wrappers matching the Jellyfin API schema.
// Full Codable models live in Core/Models/.

struct AuthenticateByNameRequest: Encodable {
    let username: String
    let pw: String
}

struct JellyfinItemsResponse: Decodable {
    let items: [MediaItem]
    let totalRecordCount: Int
    let startIndex: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}

struct JellyfinErrorResponse: Decodable {
    let message: String?

    enum CodingKeys: String, CodingKey {
        case message = "Message"
    }
}

struct PlaybackInfoRequest: Encodable {
    let userID: String
    let deviceProfile: DeviceProfile
}

struct PlaybackStartInfo: Encodable {
    let itemID: String
    let sessionID: String
    let canSeek: Bool = true
    let playMethod: String = "DirectPlay"
}

struct PlaybackProgressInfo: Encodable {
    let itemID: String
    let sessionID: String
    let positionTicks: Int64
    let isPaused: Bool
    let playMethod: String = "DirectPlay"
}

struct PlaybackStopInfo: Encodable {
    let itemID: String
    let sessionID: String
    let positionTicks: Int64
}

// MARK: - JellyfinUser (lightweight — full profile fetched on demand)

public struct JellyfinUser: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let primaryImageTag: String?
    public let serverId: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case primaryImageTag = "PrimaryImageTag"
        case serverId = "ServerId"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.primaryImageTag = try container.decodeIfPresent(String.self, forKey: .primaryImageTag)
        self.serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
    }
}

// MARK: - PaginatedResult

public struct PaginatedResult<T: Sendable>: Sendable {
    public let items: [T]
    public let totalCount: Int
    public let startIndex: Int

    public var hasMore: Bool { startIndex + items.count < totalCount }
}

private extension JSONEncoder.KeyEncodingStrategy {
    /// Converts camelCase Swift properties ("itemId") to PascalCase ("ItemId").
    static var convertToUpperCamelCase: JSONEncoder.KeyEncodingStrategy {
        .custom { codingKeys in
            guard let key = codingKeys.last else {
                fatalError("CodingKey path is unexpectedly empty")
            }
            let str = key.stringValue
            let first = str.prefix(1).uppercased()
            let rest = str.dropFirst()
            guard let result = AnyCodingKey(stringValue: first + rest) else {
                fatalError("AnyCodingKey init failed for key: \(str)")
            }
            return result
        }
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}
