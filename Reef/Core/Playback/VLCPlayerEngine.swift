import UIKit
import Combine
import os.log

// MARK: - VLCPlayerEngine
//
// `PlaybackEngine` conformance backed by MobileVLCKit's `VLCMediaPlayer`.
// Handles: MKV, AVI, HEVC, TrueHD, DTS-HD Master Audio, ASS/SSA subtitles.
//
// ⚠️  MobileVLCKit is linked via CocoaPods. This file will not compile until
//    `pod install` completes and the workspace is opened.
//
// Full implementation: Task 16 (M3).

#if canImport(TVVLCKit)
import TVVLCKit

@MainActor
public final class VLCPlayerEngine: NSObject, PlaybackEngine {

    // MARK: PlaybackEngine — State

    @Published private(set) public var state: PlaybackState = .idle
    public var statePublisher: AnyPublisher<PlaybackState, Never> {
        $state.eraseToAnyPublisher()
    }
    public var currentTime: TimeInterval {
        TimeInterval(mediaPlayer.time.intValue) / 1000.0
    }
    public var duration: TimeInterval {
        TimeInterval(mediaPlayer.media?.length.intValue ?? 0) / 1000.0
    }
    public var videoOutputView: UIView { drawingView }

    // MARK: Private

    private let mediaPlayer = VLCMediaPlayer()
    private let drawingView = UIView()
    private let logger = Logger(subsystem: "com.reef.app", category: "VLCPlayerEngine")

    // MARK: Init

    public override init() {
        super.init()
        mediaPlayer.delegate = self
        mediaPlayer.drawable = drawingView
    }

    // MARK: - PlaybackEngine Protocol

    public func load(url: URL) async throws {
        state = .loading
        let media = VLCMedia(url: url)
        // Force local ASS/SSA subtitle rendering (no transcode trigger).
        media.addOption("--sub-autodetect-file")
        media.addOption("--sub-filter=libass")
        mediaPlayer.media = media
        logger.info("VLCPlayerEngine loaded: \(url.absoluteString)")
    }

    public func play() {
        mediaPlayer.play()
    }

    public func pause() {
        mediaPlayer.pause()
    }

    public func seek(to time: TimeInterval) async {
        let ms = Int32(time * 1000)
        mediaPlayer.time = VLCTime(int: ms)
    }

    public func stop() {
        mediaPlayer.stop()
        state = .idle
    }

    public func setSubtitleTrack(_ track: SubtitleTrack?) async {
        if let track {
            mediaPlayer.currentVideoSubTitleIndex = Int32(track.id)
        } else {
            // -1 disables all subtitle tracks in VLC.
            mediaPlayer.currentVideoSubTitleIndex = -1
        }
    }

    public func setAudioTrack(_ track: AudioTrack) async {
        mediaPlayer.currentAudioTrackIndex = Int32(track.id)
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerEngine: VLCMediaPlayerDelegate {
    nonisolated public func mediaPlayerStateChanged(_ aNotification: Notification) {
        let vlcState = VLCMediaPlayerState(rawValue: Int(mediaPlayer.state.rawValue))
        Task { @MainActor in
            switch vlcState {
            case .playing:   self.state = .playing
            case .paused:    self.state = .paused
            case .buffering: self.state = .buffering
            case .stopped:   self.state = .idle
            case .error:     self.state = .failed("VLC playback error")
            case .esAdded:   self.state = .readyToPlay
            default:         break
            }
        }
    }

    nonisolated public func mediaPlayerTimeChanged(_ aNotification: Notification) {
        // Time updates are published implicitly via the computed `currentTime` property.
    }
}

#else

// MARK: - Stub when TVVLCKit is not yet linked (pre-pod install)

@MainActor
public final class VLCPlayerEngine: PlaybackEngine {
    @Published private(set) public var state: PlaybackState = .idle
    public var statePublisher: AnyPublisher<PlaybackState, Never> {
        $state.eraseToAnyPublisher()
    }
    public var currentTime: TimeInterval { 0 }
    public var duration: TimeInterval { 0 }
    public var videoOutputView: UIView { UIView() }

    public init() {}

    public func load(url: URL) async throws {
        throw PlaybackError.engineNotAvailable
    }
    public func play() {}
    public func pause() {}
    public func seek(to time: TimeInterval) async {}
    public func stop() {}
    public func setSubtitleTrack(_ track: SubtitleTrack?) async {}
    public func setAudioTrack(_ track: AudioTrack) async {}
}

public enum PlaybackError: Error {
    case engineNotAvailable
}

#endif
