import Foundation

// MARK: - PlaybackRouter
//
// Stateless router that analyses a `MediaSource` and returns the correct
// `EngineType`. This logic is 100% unit-testable with no UI dependencies.
//
// Decision matrix:
//
// Container           VideoCodec          AudioCodec             Engine
// ──────────────────────────────────────────────────────────────────────
// mp4, m4v, mov       h264, mpeg4         aac, mp3, ac3, eac3    AVPlayer
// mp4, m4v, mov       hevc                aac, mp3, ac3, eac3    AVPlayer  (tvOS 11+ HEVC)
// any                 any                 truehd, dts-hd, dts-ma VLC       (audio forces VLC)
// mkv, avi, ts, webm  any                 any                    VLC       (container forces VLC)
// any                 av1, vp8, vp9       any                    VLC       (codec forces VLC)
// (fallback)          —                   —                      VLC       (conservative default)

public enum PlaybackRouter {

    // MARK: - Public Interface

    /// Returns the `EngineType` best suited to play `source`.
    public static func resolve(for source: MediaSource) -> EngineType {
        let container = source.container?.lowercased() ?? ""
        let videoCodec = source.videoCodec?.lowercased() ?? ""
        let audioCodec = source.audioStreams.first?.codec?.lowercased() ?? ""

        // 1. Audio codec can force VLC regardless of container/video.
        if requiresVLCForAudio(codec: audioCodec) {
            return .vlc
        }

        // 2. Container forces VLC.
        if requiresVLCForContainer(container: container) {
            return .vlc
        }

        // 3. Video codec forces VLC.
        if requiresVLCForVideo(codec: videoCodec) {
            return .vlc
        }

        // 4. Subtitle streams can force VLC (ASS/SSA need VLC renderer).
        if source.subtitleStreams.contains(where: { requiresVLCForSubtitle(codec: $0.codec) }) {
            return .vlc
        }

        // 5. Native Apple containers + codecs → AVPlayer.
        if isAVPlayerNativeContainer(container) && isAVPlayerNativeVideo(videoCodec) {
            return .avPlayer
        }

        // Default to VLC (conservative).
        return .vlc
    }

    // MARK: - Private Decision Helpers

    /// Audio codecs requiring VLC for lossless bitstream passthrough.
    private static let vlcOnlyAudioCodecs: Set<String> = [
        "truehd", "mlp",
        "dts-hd", "dts-ma",
        "dts:x",
        "dtshd"
    ]

    /// Containers natively decoded by AVPlayer/AVKit on tvOS.
    private static let avPlayerNativeContainers: Set<String> = [
        "mp4", "m4v", "mov"
    ]

    /// Video codecs natively decoded by tvOS hardware.
    private static let avPlayerNativeVideoCodecs: Set<String> = [
        "h264", "avc", "avc1",
        "mpeg4", "mp4v",
        "hevc", "h265", "hvc1"
    ]

    /// Video codecs that require VLC software decode.
    private static let vlcOnlyVideoCodecs: Set<String> = [
        "av1",
        "vp8",
        "vp9",
        "vc1",
        "mpeg2video", "mpeg2"
    ]

    private static func requiresVLCForAudio(codec: String) -> Bool {
        vlcOnlyAudioCodecs.contains(where: { codec.contains($0) })
    }

    private static func requiresVLCForContainer(container: String) -> Bool {
        let parts = container.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.isEmpty {
            return false
        }
        return parts.allSatisfy { !avPlayerNativeContainers.contains($0) }
    }

    private static func requiresVLCForVideo(codec: String) -> Bool {
        vlcOnlyVideoCodecs.contains(where: { codec == $0 })
    }

    private static func requiresVLCForSubtitle(codec: String?) -> Bool {
        guard let codec = codec?.lowercased() else {
            return false
        }
        return codec == "ass" || codec == "ssa"
    }

    private static func isAVPlayerNativeContainer(_ container: String) -> Bool {
        let parts = container.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.contains(where: { avPlayerNativeContainers.contains($0) })
    }

    private static func isAVPlayerNativeVideo(_ codec: String) -> Bool {
        avPlayerNativeVideoCodecs.contains(where: { codec == $0 })
    }
}
