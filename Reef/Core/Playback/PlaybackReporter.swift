import Foundation
import os.log

// MARK: - PlaybackReporter
//
// Reports playback position to the Jellyfin server every 10 seconds during
// active playback. Fires a stopped event when playback ends or the user exits.
//
// Full implementation: Task 17 (M3).

actor PlaybackReporter {

    // MARK: Properties

    private let apiClient: JellyfinAPIClientProtocol
    private let logger = Logger(subsystem: "com.reef.app", category: "PlaybackReporter")

    private var reportingTask: Task<Void, Never>?
    private var currentSession: ReportingSession?

    static let reportingInterval: TimeInterval = 10.0

    // MARK: Init

    init(apiClient: JellyfinAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Interface

    /// Begin periodic progress reporting for the given item/session.
    /// - Parameters:
    ///   - sessionID: The Jellyfin play session ID from `PlaybackInfo`.
    ///   - itemID: The media item ID.
    ///   - token: The auth token.
    ///   - positionProvider: An async closure returning the current position in ticks.
    ///   - isPausedProvider: An async closure returning whether playback is paused.
    func start(
        sessionID: String,
        itemID: String,
        token: String,
        positionProvider: @escaping @Sendable () async -> Int64,
        isPausedProvider: @escaping @Sendable () async -> Bool
    ) async {
        // Cancel any previous session.
        reportingTask?.cancel()

        currentSession = ReportingSession(
            sessionID: sessionID,
            itemID: itemID,
            token: token
        )

        // Report playback started.
        do {
            try await apiClient.reportPlaybackStarted(sessionID: sessionID, itemID: itemID, token: token)
        } catch {
            logger.warning("Failed to report playback start: \(error)")
        }

        // Begin periodic progress loop.
        reportingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.reportingInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let isPaused = await isPausedProvider()
                guard !isPaused else { continue } // Skip reporting while paused.

                let position = await positionProvider()
                do {
                    try await apiClient.reportPlaybackProgress(
                        sessionID: sessionID,
                        itemID: itemID,
                        positionTicks: position,
                        isPaused: false,
                        token: token
                    )
                    logger.debug("Progress reported: \(position) ticks")
                } catch {
                    // Never interrupt playback for a reporting failure.
                    logger.warning("Progress report failed (non-fatal): \(error)")
                }
            }
        }

        logger.info("PlaybackReporter started for item \(itemID).")
    }

    /// Stop reporting and send a stopped event to the server.
    func stop(positionTicks: Int64) async {
        reportingTask?.cancel()
        reportingTask = nil

        guard let session = currentSession else {
            return
        }
        currentSession = nil

        do {
            try await apiClient.reportPlaybackStopped(
                sessionID: session.sessionID,
                itemID: session.itemID,
                positionTicks: positionTicks,
                token: session.token
            )
            logger.info("Playback stopped reported at position \(positionTicks).")
        } catch {
            logger.warning("Failed to report playback stop: \(error)")
        }
    }

    // MARK: - Private

    private struct ReportingSession {
        let sessionID: String
        let itemID: String
        let token: String
    }
}
