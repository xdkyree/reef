import Foundation

// MARK: - AudioTrack
//
// A parsed audio stream exposed to the player UI.
// Mapped from `MediaStream` where `type == .audio`.

public struct AudioTrack: Identifiable, Sendable {
    /// The stream index within the media source (used to switch tracks in the player).
    public let id: Int             // = MediaStream.index
    public let language: String?
    public let displayTitle: String
    public let codec: String?      // "aac", "ac3", "eac3", "truehd", "dts", "dts-hd" …
    public let channelLayout: String?
    public let channels: Int?
    public let sampleRate: Int?
    public let bitrate: Int?
    public let isDefault: Bool

    public init(
        id: Int,
        language: String?,
        displayTitle: String,
        codec: String?,
        channelLayout: String?,
        channels: Int?,
        sampleRate: Int?,
        bitrate: Int?,
        isDefault: Bool
    ) {
        self.id = id
        self.language = language
        self.displayTitle = displayTitle
        self.codec = codec
        self.channelLayout = channelLayout
        self.channels = channels
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.isDefault = isDefault
    }

    /// Convenience init from a `MediaStream`.
    public init?(stream: MediaStream) {
        guard stream.type == .audio else {
            return nil
        }
        id            = stream.index
        language      = stream.language
        displayTitle  = stream.displayTitle ?? stream.language ?? "Track \(stream.index)"
        codec         = stream.codec
        channelLayout = stream.channelLayout
        channels      = stream.channels
        sampleRate    = stream.sampleRate
        bitrate       = stream.bitrate
        isDefault     = stream.isDefault
    }

    /// `true` when this track requires VLC for lossless / bitstream passthrough.
    /// AVPlayer can handle AC3/EAC3; TrueHD and DTS-HD variants need VLC.
    public var requiresVLCForPassthrough: Bool {
        guard let codec = codec?.lowercased() else {
            return false
        }
        let vlcOnlyCodecs = ["truehd", "dts-hd", "dts-ma", "dts:x", "mlp"]
        return vlcOnlyCodecs.contains(where: { codec.contains($0) })
    }

    /// A short, human-readable channel description (e.g. "7.1 TrueHD").
    public var shortDescription: String {
        var parts: [String] = []
        if let layout = channelLayout?.uppercased() { parts.append(layout) }
        if let codec = codec?.uppercased() { parts.append(codec) }
        return parts.isEmpty ? displayTitle : parts.joined(separator: " ")
    }
}
