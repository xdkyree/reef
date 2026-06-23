import Foundation

// MARK: - NetworkError
//
// Typed errors surfaced by `JellyfinAPIClient`. All network call sites
// throw one of these cases; callers never receive raw `URLError` or
// `DecodingError` values directly.

public enum NetworkError: Error, Equatable {

    // MARK: Transport

    /// The server returned an HTTP status code outside the 200–299 range.
    case unexpectedStatusCode(Int)

    /// The device has no network connectivity (URLError.notConnectedToInternet).
    case noConnectivity

    /// The request timed out.
    case timeout

    // MARK: Data

    /// The response body could not be decoded into the expected type.
    case decodingFailed(String)

    /// The server returned an empty response body when content was expected.
    case emptyResponse

    // MARK: Auth

    /// The auth token is missing or expired; triggers a logout flow.
    case unauthorized

    // MARK: Server

    /// A Jellyfin-specific error message returned in the response body.
    case serverError(String)

    /// Catch-all for unexpected failures; wraps the underlying description.
    case unknown(String)
}

// MARK: - NetworkError + LocalizedError

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedStatusCode(let code):
            return "Server returned status \(code)."
        case .noConnectivity:
            return "No network connection. Check your Wi-Fi or Ethernet."
        case .timeout:
            return "The request timed out. Your server may be unreachable."
        case .decodingFailed(let detail):
            return "Unexpected server response: \(detail)"
        case .emptyResponse:
            return "The server returned an empty response."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .serverError(let message):
            return message
        case .unknown(let detail):
            return "An unexpected error occurred: \(detail)"
        }
    }
}
