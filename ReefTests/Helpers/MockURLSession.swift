import Foundation
@testable import Reef

// MARK: - MockURLSession
//
// Replaces real network calls in unit tests. Configure `stubbedData` and
// `stubbedResponse` before calling any `JellyfinAPIClient` method under test.
//
// Usage:
//   let mock = MockURLSession()
//   mock.stubbedData = try JSONEncoder().encode(fixture)
//   mock.stubbedStatusCode = 200
//   let client = JellyfinAPIClient(baseURL: url, session: mock.urlSession)

final class MockURLSession: @unchecked Sendable {

    var stubbedData: Data = Data()
    var stubbedStatusCode: Int = 200
    var stubbedError: Error?
    var lastRequest: URLRequest?

    /// A `URLSession` subclass that intercepts `data(for:)` calls.
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }()

    func setStub(json: some Encodable, statusCode: Int = 200) throws {
        stubbedData = try JSONEncoder.jellyfinEncoder.encode(json)
        stubbedStatusCode = statusCode
    }

    func setStub(jsonString: String, statusCode: Int = 200) {
        stubbedData = Data(jsonString.utf8)
        stubbedStatusCode = statusCode
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {

    // Shared stub state — set before each test.
    static var stubbedData: Data = Data()
    static var stubbedStatusCode: Int = 200
    static var stubbedError: Error?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request

        if let error = Self.stubbedError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: Self.stubbedStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.stubbedData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
