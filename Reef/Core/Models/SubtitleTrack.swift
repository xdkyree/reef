import Foundation

// MARK: - SubtitleTrack
//
// A parsed subtitle stream exposed to the player UI.
// Mapped from `MediaStream` where `type == .subtitle`.

public struct SubtitleTrack: Identifiable, Sendable {
    /// The stream index within the media source (used to switch tracks in the player).
    public let id: Int             // = MediaStream.index
    public let language: String?
    public let displayTitle: String
    public let isDefault: Bool
    public let isForced: Bool
    public let format: String?     // "ass", "srt", "vtt", "subrip" …
    public let isExternal: Bool    // false = embedded in container

    public init(
        id: Int,
        language: String?,
        displayTitle: String,
        isDefault: Bool,
        isForced: Bool,
        format: String?,
        isExternal: Bool
    ) {
        self.id = id
        self.language = language
        self.displayTitle = displayTitle
        self.isDefault = isDefault
        self.isForced = isForced
        self.format = format
        self.isExternal = isExternal
    }

    /// Convenience init from a `MediaStream`.
    public init?(stream: MediaStream) {
        guard stream.type == .subtitle else { return nil }
        id           = stream.index
        language     = stream.language
        displayTitle = stream.displayTitle ?? stream.language ?? "Track \(stream.index)"
        isDefault    = stream.isDefault
        isForced     = stream.isForced
        format       = stream.codec
        isExternal   = false // Jellyfin marks external via a different field; defaulting to false for now.
    }

    /// Whether this track needs local VLC rendering (ASS/SSA) vs can be handled by AVPlayer (VTT/SRT).
    public var requiresVLCRendering: Bool {
        guard let fmt = format?.lowercased() else { return false }
        return fmt == "ass" || fmt == "ssa"
    }
}
