import AVFoundation
import AVKit
import Combine
import UIKit
import os.log

// MARK: - PlayerUIView
//
// UIView subclass that hosts an `AVPlayerLayer` as its backing layer.
// This is the correct way to embed AVPlayer video output in a UIKit/SwiftUI view.

final class PlayerUIView: UIView {

    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer } // swiftlint:disable:this force_cast

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspect
    }
}

// MARK: - AVPlayerEngine
//
// `PlaybackEngine` conformance backed by `AVPlayer`.
// Handles: MP4, M4V, MOV with H.264, HEVC (hardware), AAC, AC3, EAC3, Dolby Atmos.
//
// Full implementation polish: Task 15 (M3).

@MainActor
public final class AVPlayerEngine: PlaybackEngine {

    // MARK: PlaybackEngine — State

    @Published private(set) public var state: PlaybackState = .idle
    public var statePublisher: AnyPublisher<PlaybackState, Never> {
        $state.eraseToAnyPublisher()
    }
    public var currentTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isNaN ? 0 : seconds
    }
    public var duration: TimeInterval {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isNaN ? 0 : seconds
    }

    // MARK: - Video Output

    private let playerContainerView = PlayerUIView()
    public var videoOutputView: UIView { playerContainerView }

    // MARK: - Internal AVPlayer (exposed for VideoPlayer wrapper)

    public let player = AVPlayer()

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var timeObserverToken: Any?
    private let logger = Logger(subsystem: "com.reef.app", category: "AVPlayerEngine")

    // MARK: Init

    public init() {
        playerContainerView.playerLayer.player = player
        setupPlayerObservation()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - PlaybackEngine Protocol

    public func load(url: URL) async throws {
        state = .loading
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Configure audio session for pass-through decoding.
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .moviePlayback,
            options: []
        )
        try AVAudioSession.sharedInstance().setActive(true)
        logger.info("AVPlayerEngine loaded: \(url.absoluteString)")
    }

    public func play() {
        player.play()
        state = .playing
    }

    public func pause() {
        player.pause()
        state = .paused
    }

    public func seek(to time: TimeInterval) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .idle
    }

    public func setSubtitleTrack(_ track: SubtitleTrack?) async {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if let track {
            let option = group.options.first {
                $0.displayName == track.displayTitle ||
                ($0.locale?.languageCode == track.language)
            }
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    public func setAudioTrack(_ track: AudioTrack) async {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        let option = group.options.first {
            $0.displayName == track.displayTitle ||
            ($0.locale?.languageCode == track.language)
        }
        item.select(option, in: group)
    }

    // MARK: - Private

    private func setupPlayerObservation() {
        // Observe AVPlayerItem status
        player.publisher(for: \.currentItem?.status)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.state = .readyToPlay
                case .failed:
                    let msg = self.player.currentItem?.error?.localizedDescription ?? "Unknown error"
                    self.state = .failed(msg)
                    self.logger.error("AVPlayer failed: \(msg)")
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe end-of-playback notification
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in self?.state = .ended }
            .store(in: &cancellables)

        // Periodic time observer for currentTime updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            // currentTime is a computed property — no action needed here.
            // Subscribers observe it via @Published state changes.
            _ = self?.currentTime
        }
    }
}
