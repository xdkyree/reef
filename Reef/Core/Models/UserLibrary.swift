import Foundation

// MARK: - UserLibrary

/// A top-level library (e.g. "Movies", "TV Shows", "Home Videos") as
/// returned by the Jellyfin `/Items?IncludeItemTypes=CollectionFolder` endpoint.
public struct UserLibrary: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let collectionType: LibraryType
    public let primaryImageTag: String?

    public init(
        id: String,
        name: String,
        collectionType: LibraryType,
        primaryImageTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.collectionType = collectionType
        self.primaryImageTag = primaryImageTag
    }

    /// Convenience init from a `MediaItem` (CollectionFolder type).
    public init?(mediaItem: MediaItem) {
        guard mediaItem.type == .folder else {
            return nil
        }
        self.id = mediaItem.id
        self.name = mediaItem.name
        self.primaryImageTag = mediaItem.primaryImageTag
        self.collectionType = mediaItem.collectionType ?? .unknown
    }
}

// MARK: - LibraryType

public enum LibraryType: String, Codable, Sendable {
    case movies        = "movies"
    case tvshows       = "tvshows"
    case music         = "music"
    case books         = "books"
    case photos        = "photos"
    case musicvideos   = "musicvideos"
    case homevideos    = "homevideos"
    case mixed         = "mixed"
    case unknown       = ""

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }

    public var topLevelIncludeItemTypes: String {
        switch self {
        case .movies:
            return "Movie"
        case .tvshows:
            return "Series"
        case .mixed, .unknown, .homevideos:
            return "Movie,Series"
        default:
            return "Movie,Series"
        }
    }
}
