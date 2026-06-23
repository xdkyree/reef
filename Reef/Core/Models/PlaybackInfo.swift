import Foundation

// MARK: - PlaybackInfo

/// Response from POST /Items/{itemId}/PlaybackInfo.
/// Contains the list of media sources with direct-play or transcode URLs.
public struct PlaybackInfo: Decodable, Sendable {
    public let mediaSources: [MediaSource]
    public let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources  = "MediaSources"
        case playSessionId = "PlaySessionId"
    }

    /// Returns the best media source to use — prefers direct play,
    /// falls back to the first available transcode source.
    public var preferredSource: MediaSource? {
        mediaSources.first { $0.supportsDirectPlay } ?? mediaSources.first
    }
}

// MARK: - MediaSource

/// A single playback source for a media item, containing URLs and codec metadata.
public struct MediaSource: Decodable, Sendable, Identifiable {
    public let id: String?
    public let name: String?
    public let container: String?               // "mkv", "mp4", "avi" …
    public let size: Int64?
    public let path: String?
    public let supportsDirectPlay: Bool
    public let supportsDirectStream: Bool
    public let supportsTranscoding: Bool
    public let transcodingUrl: String?
    public let directStreamUrl: String?
    public let videoCodec: String?              // "h264", "hevc", "av1" …
    public let audioCodec: String?              // "aac", "ac3", "truehd" …
    public let videoStreams: [MediaStream]
    public let audioStreams: [MediaStream]
    public let subtitleStreams: [MediaStream]
    public let defaultVideoStreamIndex: Int?
    public let defaultAudioStreamIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case size = "Size"
        case path = "Path"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case transcodingUrl = "TranscodingUrl"
        case directStreamUrl = "DirectStreamUrl"
        case videoCodec = "VideoType"
        case audioCodec = "DefaultAudioStream"
        case videoStreams = "MediaStreams"
        case defaultVideoStreamIndex = "DefaultVideoStreamIndex"
        case defaultAudioStreamIndex = "DefaultAudioStreamIndex"
    }

    /// Decode the media source; extract video/audio/subtitle streams from the shared array.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        self.container = try container.decodeIfPresent(String.self, forKey: .container)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        supportsDirectPlay = try container.decodeIfPresent(Bool.self, forKey: .supportsDirectPlay) ?? false
        supportsDirectStream = try container.decodeIfPresent(Bool.self, forKey: .supportsDirectStream) ?? false
        supportsTranscoding = try container.decodeIfPresent(Bool.self, forKey: .supportsTranscoding) ?? false
        transcodingUrl = try container.decodeIfPresent(String.self, forKey: .transcodingUrl)
        directStreamUrl = try container.decodeIfPresent(String.self, forKey: .directStreamUrl)
        defaultVideoStreamIndex = try container.decodeIfPresent(Int.self, forKey: .defaultVideoStreamIndex)
        defaultAudioStreamIndex = try container.decodeIfPresent(Int.self, forKey: .defaultAudioStreamIndex)

        let allStreams = try container.decodeIfPresent([MediaStream].self, forKey: .videoStreams) ?? []
        videoStreams = allStreams.filter { $0.type == .video }
        audioStreams = allStreams.filter { $0.type == .audio }
        subtitleStreams = allStreams.filter { $0.type == .subtitle }

        videoCodec = videoStreams.first?.codec
        audioCodec = audioStreams.first?.codec
    }
}

// MARK: - DeviceProfile

/// Sent to POST /Items/{itemId}/PlaybackInfo to declare Reef's native
/// codec capabilities. This forces the Jellyfin server to return a
/// Direct Play URL instead of a transcode URL for all supported content.
public struct DeviceProfile: Encodable, Sendable {

    public struct DirectPlayProfile: Encodable, Sendable {
        public let container: String
        public let type: String
        public let videoCodec: String?
        public let audioCodec: String?
    }

    public struct SubtitleProfile: Encodable, Sendable {
        public let format: String
        public let method: String   // "External", "Embed"
    }

    public let directPlayProfiles: [DirectPlayProfile]
    public let subtitleProfiles: [SubtitleProfile]

    /// Reef's full device profile — declares support for all natively playable
    /// containers and codecs so the server defaults to Direct Play.
    public static let reef = Self(
        directPlayProfiles: [
            // AVPlayer-native containers
            .init(container: "mp4,m4v,mov",
                  type: "Video",
                  videoCodec: "h264,mpeg4,hevc",
                  audioCodec: "aac,mp3,ac3,eac3,flac,alac"),
            // VLC-playable containers
            .init(container: "mkv,avi,ts,m2ts,flv,webm",
                  type: "Video",
                  videoCodec: "h264,hevc,vp8,vp9,av1,mpeg2video,vc1",
                  audioCodec: "aac,mp3,ac3,eac3,dts,truehd,flac,opus,vorbis"),
            // Audio-only
            .init(container: "mp3,aac,flac,alac,m4a,ogg,opus",
                  type: "Audio",
                  videoCodec: nil,
                  audioCodec: nil)
        ],
        subtitleProfiles: [
            .init(format: "srt", method: "External"),
            .init(format: "vtt", method: "External"),
            .init(format: "ass", method: "Embed"),
            .init(format: "ssa", method: "Embed"),
            .init(format: "subrip", method: "Embed")
        ]
    )
}
