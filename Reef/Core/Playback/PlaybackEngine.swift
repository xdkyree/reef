import Foundation
import Combine
import UIKit

// MARK: - PlaybackState

/// The lifecycle state of a `PlaybackEngine` instance.
public enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case ended
    case failed(String)
}

// MARK: - PlaybackEngine
//
// Protocol all concrete engines conform to.
// Concrete types: `AVPlayerEngine` (Task 15) and `VLCPlayerEngine` (Task 16).
//
// Rules for implementors:
// - All mutating methods must be callable from a non-isolated context (they post to an internal queue).
// - `state`, `currentTime`, and `duration` are `@Published`-equivalent — observe via `statePublisher`.
// - Never trigger a transcode. If the URL needs transcoding, a different URL must be passed in.

@MainActor
public protocol PlaybackEngine: AnyObject {

    // MARK: State observation
    var state: PlaybackState { get }
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    // MARK: Playback control
    func load(url: URL) async throws
    func play()
    func pause()
    func seek(to time: TimeInterval) async
    func stop()

    // MARK: Track selection
    /// Select a subtitle track by stream index. Pass `nil` to disable subtitles.
    func setSubtitleTrack(_ track: SubtitleTrack?) async
    /// Select an audio track by stream index.
    func setAudioTrack(_ track: AudioTrack) async

    // MARK: View integration
    /// Returns the view that renders the video output, for embedding in SwiftUI via UIViewRepresentable.
    var videoOutputView: UIView { get }
}

// MARK: - EngineType

/// The concrete engine selected by `PlaybackRouter`.
public enum EngineType: Equatable, Sendable {
    /// Native AVPlayer — for MP4/M4V/MOV with H.264/AAC or Dolby Atmos.
    case avPlayer
    /// MobileVLCKit — for MKV, HEVC, TrueHD, DTS-HD, ASS/SSA subtitles.
    case vlc
}
