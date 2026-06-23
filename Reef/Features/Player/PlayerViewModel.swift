import SwiftUI
import AVFoundation

// MARK: - PlayerViewModel

@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var showControls = true
    @Published var selectedSubtitle: SubtitleTrack?
    @Published var selectedAudio: AudioTrack?

    // MARK: Engines
    private(set) var avPlayerEngine: AVPlayerEngine?
    private(set) var vlcPlayerEngine: VLCPlayerEngine?
    private var activeEngine: (any PlaybackEngine)?

    // MARK: Dependencies
    private let item: MediaItem
    private let source: MediaSource
    private let api: JellyfinAPIClientProtocol
    private lazy var reporter = PlaybackReporter(apiClient: api)

    // MARK: Controls visibility timer
    private var controlsTimer: Task<Void, Never>?

    // MARK: Init
    init(item: MediaItem, source: MediaSource, api: JellyfinAPIClientProtocol) {
        self.item = item
        self.source = source
        self.api = api
    }

    // MARK: - Playback Control

    func startPlayback(url: URL, sessionID: String, token: String) async {
        let engineType = PlaybackRouter.resolve(for: source)
        let engine: any PlaybackEngine

        switch engineType {
        case .avPlayer:
            let avEngine = AVPlayerEngine()
            avPlayerEngine = avEngine
            engine = avEngine
        case .vlc:
            let vlcEngine = VLCPlayerEngine()
            vlcPlayerEngine = vlcEngine
            engine = vlcEngine
        }

        activeEngine = engine

        do {
            try await engine.load(url: url)
            engine.play()

            // Resume position
            if item.isResumable, let ticks = item.userData?.playbackPositionTicks {
                await engine.seek(to: TimeInterval(ticks) / 10_000_000)
            }

            // Begin progress reporting
            await reporter.start(
                sessionID: sessionID,
                itemID: item.id,
                token: token,
                positionProvider: { [weak engine] in
                    await MainActor.run {
                        Int64((engine?.currentTime ?? 0) * 10_000_000)
                    }
                },
                isPausedProvider: { [weak self] in
                    await MainActor.run {
                        self?.state == .paused
                    }
                }
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func togglePlayPause() {
        guard let engine = activeEngine else { return }
        if state == .playing {
            engine.pause()
            state = .paused
        } else {
            engine.play()
            state = .playing
        }
        resetControlsTimer()
    }

    func seek(to time: TimeInterval) async {
        await activeEngine?.seek(to: time)
        resetControlsTimer()
    }

    func stop() async {
        let position = Int64((activeEngine?.currentTime ?? 0) * 10_000_000)
        await reporter.stop(positionTicks: position)
        activeEngine?.stop()
        state = .idle
    }

    // MARK: - Track Selection

    func selectSubtitle(_ track: SubtitleTrack?) async {
        selectedSubtitle = track
        await activeEngine?.setSubtitleTrack(track)
    }

    func selectAudio(_ track: AudioTrack) async {
        selectedAudio = track
        await activeEngine?.setAudioTrack(track)
    }

    // MARK: - Controls Visibility

    func showControlsBriefly() {
        showControls = true
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.cancel()
        controlsTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                showControls = false
            }
        }
    }

    // MARK: - Available Tracks

    var audioTracks: [AudioTrack] {
        source.audioStreams.compactMap { AudioTrack(stream: $0) }
    }

    var subtitleTracks: [SubtitleTrack] {
        source.subtitleStreams.compactMap { SubtitleTrack(stream: $0) }
    }
}
