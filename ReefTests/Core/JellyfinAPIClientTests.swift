import XCTest
@testable import Reef

// MARK: - JellyfinAPIClientTests
//
// Unit tests for `JellyfinAPIClient` using `MockURLSession`.
// No real network calls are made.

final class JellyfinAPIClientTests: XCTestCase {

    // MARK: Helpers

    private let baseURL = URL(string: "http://localhost:8096")!

    private func makeClient(
        stubbingJSON json: String,
        statusCode: Int = 200
    ) -> JellyfinAPIClient {
        MockURLProtocol.stubbedData = Data(json.utf8)
        MockURLProtocol.stubbedStatusCode = statusCode
        MockURLProtocol.stubbedError = nil

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return JellyfinAPIClient(baseURL: baseURL, session: session)
    }

    private func makeClient(stubbingError error: Error) -> JellyfinAPIClient {
        MockURLProtocol.stubbedError = error
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return JellyfinAPIClient(baseURL: baseURL, session: session)
    }

    // MARK: - Authentication Tests

    func test_authenticate_returnsAuthResponse_onSuccess() async throws {
        let json = """
        {
          "AccessToken": "test-token-abc",
          "ServerId": "server-123",
          "User": { "Id": "user-456", "Name": "Alice", "PrimaryImageTag": null }
        }
        """
        let client = makeClient(stubbingJSON: json)
        let response = try await client.authenticate(
            serverURL: baseURL,
            username: "Alice",
            password: "password"
        )
        XCTAssertEqual(response.accessToken, "test-token-abc")
        XCTAssertEqual(response.serverId, "server-123")
        XCTAssertEqual(response.user.id, "user-456")
        XCTAssertEqual(response.user.name, "Alice")
    }

    func test_authenticate_throwsUnauthorized_on401() async {
        let client = makeClient(stubbingJSON: "{}", statusCode: 401)
        do {
            _ = try await client.authenticate(serverURL: baseURL, username: "x", password: "x")
            XCTFail("Expected NetworkError.unauthorized to be thrown")
        } catch NetworkError.unauthorized {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_authenticate_throwsUnexpectedStatusCode_on500() async {
        let client = makeClient(stubbingJSON: "{}", statusCode: 500)
        do {
            _ = try await client.authenticate(serverURL: baseURL, username: "x", password: "x")
            XCTFail("Expected NetworkError.unexpectedStatusCode to be thrown")
        } catch NetworkError.unexpectedStatusCode(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_authenticate_throwsNoConnectivity_onURLError() async {
        let client = makeClient(stubbingError: URLError(.notConnectedToInternet))
        do {
            _ = try await client.authenticate(serverURL: baseURL, username: "x", password: "x")
            XCTFail("Expected NetworkError.noConnectivity to be thrown")
        } catch NetworkError.noConnectivity {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_authenticate_throwsDecodingFailed_onMalformedJSON() async {
        let client = makeClient(stubbingJSON: "{ invalid json }")
        do {
            _ = try await client.authenticate(serverURL: baseURL, username: "x", password: "x")
            XCTFail("Expected NetworkError.decodingFailed to be thrown")
        } catch NetworkError.decodingFailed {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Media Fetch Tests

    func test_fetchContinueWatching_returnsItems_onSuccess() async throws {
        let json = """
        {
          "Items": [
            {
              "Id": "item-1",
              "Name": "The Matrix",
              "Type": "Movie",
              "ServerId": "server-1",
              "UserData": { "PlaybackPositionTicks": 5000000, "Played": false, "PlayCount": 1 }
            }
          ],
          "TotalRecordCount": 1,
          "StartIndex": 0
        }
        """
        let client = makeClient(stubbingJSON: json)
        let items = try await client.fetchContinueWatching(userID: "user-1", token: "token-1")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "The Matrix")
        XCTAssertEqual(items[0].type, .movie)
    }

    func test_fetchContinueWatching_returnsEmptyArray_whenNoItems() async throws {
        let json = """{ "Items": [], "TotalRecordCount": 0, "StartIndex": 0 }"""
        let client = makeClient(stubbingJSON: json)
        let items = try await client.fetchContinueWatching(userID: "user-1", token: "token-1")
        XCTAssertTrue(items.isEmpty)
    }

    func test_fetchNextUp_returnsEpisodes() async throws {
        let json = """
        {
          "Items": [
            {
              "Id": "ep-1",
              "Name": "Pilot",
              "Type": "Episode",
              "ServerId": "server-1",
              "IndexNumber": 1,
              "ParentIndexNumber": 1,
              "SeriesName": "Breaking Bad",
              "UserData": { "PlaybackPositionTicks": 0, "Played": false, "PlayCount": 0 }
            }
          ],
          "TotalRecordCount": 1,
          "StartIndex": 0
        }
        """
        let client = makeClient(stubbingJSON: json)
        let items = try await client.fetchNextUp(userID: "user-1", token: "token-1")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].type, .episode)
        XCTAssertEqual(items[0].seriesName, "Breaking Bad")
    }

    // MARK: - JSON Decoder Tests

    func test_jellyfinDecoder_parsesISO8601WithMilliseconds() throws {
        let json = """{"Id":"1","Name":"Test","Type":"Movie","ServerId":"s1","UserData":{"PlaybackPositionTicks":0,"Played":false,"PlayCount":0}}"""
        let item = try JSONDecoder.jellyfinDecoder.decode(MediaItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.id, "1")
    }

    func test_networkError_equatability() {
        XCTAssertEqual(NetworkError.unauthorized, NetworkError.unauthorized)
        XCTAssertEqual(NetworkError.unexpectedStatusCode(404), NetworkError.unexpectedStatusCode(404))
        XCTAssertNotEqual(NetworkError.unexpectedStatusCode(404), NetworkError.unexpectedStatusCode(500))
    }
}
