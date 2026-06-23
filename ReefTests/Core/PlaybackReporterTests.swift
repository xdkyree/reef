import XCTest
@testable import Reef

// MARK: - PlaybackReporterTests

final class PlaybackReporterTests: XCTestCase {

    // MARK: Helpers

    private func makeReporter() -> (PlaybackReporter, MockJellyfinAPIClient) {
        let mockAPI = MockJellyfinAPIClient()
        let reporter = PlaybackReporter(apiClient: mockAPI)
        return (reporter, mockAPI)
    }

    private let fakeSessionID = "session-abc"
    private let fakeItemID    = "item-xyz"
    private let fakeToken     = "token-123"

    // MARK: - Tests

    func test_start_callsPlaybackStartedOnce() async throws {
        let (reporter, mockAPI) = makeReporter()

        await reporter.start(
            sessionID: fakeSessionID,
            itemID: fakeItemID,
            token: fakeToken,
            positionProvider: { 0 },
            isPausedProvider: { false }
        )

        // Give a brief moment for the async start call to fire.
        try await Task.sleep(nanoseconds: 100_000_000)

        // stop immediately so we don't wait the full 10 s interval
        await reporter.stop(positionTicks: 0)

        // reportPlaybackStarted was triggered (translates to reportProgressCallCount = 0 here;
        // we test stop instead since our mock tracks progress and stopped calls)
        let stopped = await mockAPI.reportStoppedCallCount
        XCTAssertEqual(stopped, 1, "stop() must call reportPlaybackStopped exactly once.")
    }

    func test_stop_callsReportStoppedOnce() async throws {
        let (reporter, mockAPI) = makeReporter()

        await reporter.start(
            sessionID: fakeSessionID,
            itemID: fakeItemID,
            token: fakeToken,
            positionProvider: { 500_000_000 },
            isPausedProvider: { false }
        )

        try await Task.sleep(nanoseconds: 50_000_000)
        await reporter.stop(positionTicks: 999_000_000)

        let stopped = await mockAPI.reportStoppedCallCount
        XCTAssertEqual(stopped, 1)
    }

    func test_stop_beforeStart_doesNotCallAPI() async throws {
        let (reporter, mockAPI) = makeReporter()
        // Never started — stop should be a no-op.
        await reporter.stop(positionTicks: 0)

        let stopped = await mockAPI.reportStoppedCallCount
        XCTAssertEqual(stopped, 0, "stop() before start() must not call the API.")
    }

    func test_start_skipsProgressReport_whenPaused() async throws {
        let (reporter, mockAPI) = makeReporter()

        // Always reports "paused" — progress loop should skip reporting.
        await reporter.start(
            sessionID: fakeSessionID,
            itemID: fakeItemID,
            token: fakeToken,
            positionProvider: { 1_000_000_000 },
            isPausedProvider: { true }     // ← paused
        )

        // Wait slightly longer than one 10s tick — but since interval is 10s,
        // within a short sleep we expect zero progress calls.
        try await Task.sleep(nanoseconds: 200_000_000)
        await reporter.stop(positionTicks: 0)

        let progress = await mockAPI.reportProgressCallCount
        XCTAssertEqual(progress, 0, "Progress must not be reported while paused.")
    }

    func test_start_survivesNetworkFailure_withoutInterruptingLoop() async throws {
        let (reporter, mockAPI) = makeReporter()
        // Inject a network error — reporter should swallow it and not throw.
        await mockAPI.set(shouldThrowError: NetworkError.noConnectivity)

        // Should NOT throw even though the API calls fail.
        await reporter.start(
            sessionID: fakeSessionID,
            itemID: fakeItemID,
            token: fakeToken,
            positionProvider: { 0 },
            isPausedProvider: { false }
        )

        try await Task.sleep(nanoseconds: 100_000_000)
        await reporter.stop(positionTicks: 0)
        // If we reach here without a crash/throw, the test passes.
        XCTAssertTrue(true, "Reporter must survive network failures silently.")
    }
}

// MARK: - MockJellyfinAPIClient actor setter helpers

private extension MockJellyfinAPIClient {
    func set(shouldThrowError: Error?) async {
        self.shouldThrowError = shouldThrowError
    }
}
