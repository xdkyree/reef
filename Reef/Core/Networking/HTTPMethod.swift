import Foundation

// MARK: - HTTPMethod

/// Strongly-typed HTTP method to avoid stringly-typed request building.
public enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case delete = "DELETE"
    case put    = "PUT"
    case patch  = "PATCH"
}
