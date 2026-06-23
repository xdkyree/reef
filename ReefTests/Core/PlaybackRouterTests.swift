import XCTest
@testable import Reef

// MARK: - PlaybackRouterTests
//
// Covers ≥ 10 codec combinations to verify the engine selection matrix.

final class PlaybackRouterTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal `MediaSource` for routing tests.
    private func makeSource(
        container: String,
        videoCodec: String,
        audioCodec: String,
        subtitleCodec: String? = nil
    ) -> MediaSource {
        // Build from JSON to satisfy Decodable init
        var json = """
        {
          "Container": "\(container)",
          "SupportsDirectPlay": true,
          "SupportsDirectStream": true,
          "SupportsTranscoding": false,
          "MediaStreams": [
            { "Type": "Video", "Codec": "\(videoCodec)", "Index": 0,
              "IsDefault": true, "IsForced": false },
            { "Type": "Audio", "Codec": "\(audioCodec)", "Index": 1,
              "IsDefault": true, "IsForced": false }
        """
        if let sub = subtitleCodec {
            json += """
            ,{ "Type": "Subtitle", "Codec": "\(sub)", "Index": 2,
               "IsDefault": false, "IsForced": false }
            """
        }
        json += "]}"
        guard let source = try? JSONDecoder.jellyfinDecoder.decode(MediaSource.self, from: Data(json.utf8)) else {
            XCTFail("Failed to decode MediaSource fixture")
            return makeSource(container: "mp4", videoCodec: "h264", audioCodec: "aac") // unreachable
        }
        return source
    }

    // MARK: - AVPlayer Cases (should resolve to .avPlayer)

    func test_mp4_h264_aac_resolvesToAVPlayer() {
        let source = makeSource(container: "mp4", videoCodec: "h264", audioCodec: "aac")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .avPlayer)
    }

    func test_m4v_h264_ac3_resolvesToAVPlayer() {
        let source = makeSource(container: "m4v", videoCodec: "h264", audioCodec: "ac3")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .avPlayer)
    }

    func test_mov_mpeg4_mp3_resolvesToAVPlayer() {
        let source = makeSource(container: "mov", videoCodec: "mpeg4", audioCodec: "mp3")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .avPlayer)
    }

    func test_mp4_hevc_aac_resolvesToAVPlayer() {
        // HEVC in MP4 is hardware-decoded on Apple TV 4K.
        let source = makeSource(container: "mp4", videoCodec: "hevc", audioCodec: "aac")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .avPlayer)
    }

    func test_mp4_hevc_eac3_resolvesToAVPlayer() {
        let source = makeSource(container: "mp4", videoCodec: "hevc", audioCodec: "eac3")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .avPlayer)
    }

    // MARK: - VLC Cases — Container forces VLC

    func test_mkv_h264_aac_resolvesToVLC() {
        // MKV container forces VLC even with otherwise-native codecs.
        let source = makeSource(container: "mkv", videoCodec: "h264", audioCodec: "aac")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    func test_avi_h264_aac_resolvesToVLC() {
        let source = makeSource(container: "avi", videoCodec: "h264", audioCodec: "aac")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    // MARK: - VLC Cases — Audio codec forces VLC

    func test_mp4_hevc_truehd_resolvesToVLC() {
        // TrueHD audio requires VLC bitstream passthrough, even in MP4.
        let source = makeSource(container: "mp4", videoCodec: "hevc", audioCodec: "truehd")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    func test_mkv_hevc_dtshd_resolvesToVLC() {
        let source = makeSource(container: "mkv", videoCodec: "hevc", audioCodec: "dts-hd")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    func test_mkv_hevc_dtsma_resolvesToVLC() {
        let source = makeSource(container: "mkv", videoCodec: "hevc", audioCodec: "dts-ma")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    // MARK: - VLC Cases — Video codec forces VLC

    func test_mp4_av1_aac_resolvesToVLC() {
        // AV1 has no tvOS hardware decoder yet.
        let source = makeSource(container: "mp4", videoCodec: "av1", audioCodec: "aac")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    func test_webm_vp9_opus_resolvesToVLC() {
        let source = makeSource(container: "webm", videoCodec: "vp9", audioCodec: "opus")
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    // MARK: - VLC Cases — Subtitle codec forces VLC

    func test_mp4_h264_aac_assSubtitle_resolvesToVLC() {
        // ASS subtitle requires VLC renderer to avoid server-side render transcode.
        let source = makeSource(
            container: "mp4",
            videoCodec: "h264",
            audioCodec: "aac",
            subtitleCodec: "ass"
        )
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }

    func test_mkv_hevc_truehd_ssaSubtitle_resolvesToVLC() {
        let source = makeSource(
            container: "mkv",
            videoCodec: "hevc",
            audioCodec: "truehd",
            subtitleCodec: "ssa"
        )
        XCTAssertEqual(PlaybackRouter.resolve(for: source), .vlc)
    }
}
