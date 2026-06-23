import Foundation

// MARK: - MediaType

/// The category of a Jellyfin media item.
public enum MediaType: String, Codable, Sendable {
    case movie        = "Movie"
    case series       = "Series"
    case episode      = "Episode"
    case collection   = "BoxSet"
    case folder       = "CollectionFolder"
    case season       = "Season"
    case trailer      = "Trailer"
    case musicVideo   = "MusicVideo"
    case unknown      = ""

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

// MARK: - UserData

/// Per-user playback state for a media item.
public struct UserData: Codable, Sendable {
    /// Resume position in Jellyfin ticks (10,000 ticks = 1 ms).
    public let playbackPositionTicks: Int64
    /// Whether the item has been fully watched.
    public let played: Bool
    /// Playback percentage (0–100), computed server-side.
    public let playedPercentage: Double?
    /// Number of times the item has been played.
    public let playCount: Int

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played                = "Played"
        case playedPercentage      = "PlayedPercentage"
        case playCount             = "PlayCount"
    }

    public init(
        playbackPositionTicks: Int64 = 0,
        played: Bool = false,
        playedPercentage: Double? = nil,
        playCount: Int = 0
    ) {
        self.playbackPositionTicks = playbackPositionTicks
        self.played = played
        self.playedPercentage = playedPercentage
        self.playCount = playCount
    }
}

// MARK: - MediaItem

/// A single item in a Jellyfin library — movie, series, episode, etc.
/// This is the central domain model used across Home, Library, Detail, and Player.
public struct MediaItem: Codable, Identifiable, Sendable {

    // MARK: Core Identity
    public let id: String
    public let name: String
    public let type: MediaType
    public let serverId: String?

    // MARK: Metadata
    public let overview: String?
    public let productionYear: Int?
    public let officialRating: String?          // e.g. "PG-13", "TV-MA"
    public let communityRating: Double?          // 0.0 – 10.0
    public let criticRating: Double?             // Rotten Tomatoes 0–100

    // MARK: Runtime
    /// Duration in Jellyfin ticks (1 tick = 100 nanoseconds; 10,000,000 ticks = 1 second).
    public let runTimeTicks: Int64?

    // MARK: Series context (populated when `type == .episode`)
    public let seriesName: String?
    public let seasonName: String?
    public let indexNumber: Int?                 // Episode number
    public let parentIndexNumber: Int?           // Season number
    public let seriesId: String?

    // MARK: Image tags
    public let primaryImageTag: String?
    public let backdropImageTags: [String]?
    public let thumbImageTag: String?

    // MARK: User-specific state
    public let userData: UserData?

    // MARK: Codec info (populated on library items)
    public let mediaStreams: [MediaStream]?

    // MARK: CodingKeys

    enum CodingKeys: String, CodingKey {
        case id                 = "Id"
        case name               = "Name"
        case type               = "Type"
        case serverId           = "ServerId"
        case overview           = "Overview"
        case productionYear     = "ProductionYear"
        case officialRating     = "OfficialRating"
        case communityRating    = "CommunityRating"
        case criticRating       = "CriticRating"
        case runTimeTicks       = "RunTimeTicks"
        case seriesName         = "SeriesName"
        case seasonName         = "SeasonName"
        case indexNumber        = "IndexNumber"
        case parentIndexNumber  = "ParentIndexNumber"
        case seriesId           = "SeriesId"
        case primaryImageTag    = "PrimaryImageTag"
        case backdropImageTags  = "BackdropImageTags"
        case thumbImageTag      = "ThumbImageTag"
        case userData           = "UserData"
        case mediaStreams = "MediaStreams"
    }

    // MARK: - Computed Properties

    /// Human-readable runtime string (e.g. "2h 18m" for a movie, "42m" for an episode).
    public var durationFormatted: String? {
        guard let ticks = runTimeTicks, ticks > 0 else { return nil }
        let totalSeconds = Int(ticks / 10_000_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Playback progress as a fraction 0.0–1.0 (for the progress bar).
    public var watchProgress: Double? {
        guard
            let ticks = runTimeTicks, ticks > 0,
            let position = userData?.playbackPositionTicks,
            position > 0
        else { return nil }
        return min(Double(position) / Double(ticks), 1.0)
    }

    /// `true` when the item has a saved resume position (> 5 % into runtime).
    public var isResumable: Bool {
        guard
            let ticks = runTimeTicks, ticks > 0,
            let position = userData?.playbackPositionTicks,
            position > 0
        else { return false }
        let progress = Double(position) / Double(ticks)
        return progress > 0.05 && progress < 0.95
    }

    /// Display title incorporating season/episode context for episodes.
    public var displayTitle: String {
        if type == .episode,
           let season = parentIndexNumber,
           let episode = indexNumber {
            return "S\(season):E\(episode) — \(name)"
        }
        return name
    }
}

// MARK: - MediaStream

/// An individual audio, video, or subtitle stream within a media file.
public struct MediaStream: Codable, Sendable {
    public let codec: String?
    public let language: String?
    public let displayTitle: String?
    public let index: Int
    public let type: StreamType
    public let isDefault: Bool
    public let isForced: Bool
    public let channelLayout: String?       // e.g. "5.1", "7.1", "stereo"
    public let channels: Int?
    public let sampleRate: Int?
    public let bitrate: Int?
    public let height: Int?
    public let width: Int?
    public let videoRange: String?          // "HDR", "SDR"

    enum CodingKeys: String, CodingKey {
        case codec          = "Codec"
        case language       = "Language"
        case displayTitle   = "DisplayTitle"
        case index          = "Index"
        case type           = "Type"
        case isDefault      = "IsDefault"
        case isForced       = "IsForced"
        case channelLayout  = "ChannelLayout"
        case channels       = "Channels"
        case sampleRate     = "SampleRate"
        case bitrate        = "BitRate"
        case height         = "Height"
        case width          = "Width"
        case videoRange     = "VideoRange"
    }
}

// MARK: - StreamType

public enum StreamType: String, Codable, Sendable {
    case video    = "Video"
    case audio    = "Audio"
    case subtitle = "Subtitle"
    case embedded = "EmbeddedImage"
    case data     = "Data"
}
