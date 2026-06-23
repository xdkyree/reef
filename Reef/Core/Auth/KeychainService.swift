import Foundation
import Security
import os.log

// MARK: - KeychainServiceProtocol

public protocol KeychainServiceProtocol: Sendable {
    func save(_ credentials: StoredCredentials) async throws
    func load() async throws -> StoredCredentials?
    func delete() async throws
}

// MARK: - KeychainError

public enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
    case decodingFailed
    case itemNotFound
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):   return "Keychain save failed (OSStatus \(status))."
        case .loadFailed(let status):   return "Keychain load failed (OSStatus \(status))."
        case .deleteFailed(let status): return "Keychain delete failed (OSStatus \(status))."
        case .encodingFailed:           return "Failed to encode credentials for Keychain."
        case .decodingFailed:           return "Failed to decode credentials from Keychain."
        case .itemNotFound:             return "No stored credentials found."
        }
    }
}

// MARK: - KeychainService

/// A Swift actor wrapping `Security.framework` kSecClassGenericPassword
/// operations. All credential storage and retrieval is funnelled through
/// this type. Never use `UserDefaults` for auth tokens.
public actor KeychainService: KeychainServiceProtocol {

    // MARK: Properties

    private let service: String
    private let account: String
    private let logger = Logger(subsystem: "com.reef.app", category: "KeychainService")

    // MARK: Init

    public init(
        service: String = "com.reef.app",
        account: String = "reef.user-session"
    ) {
        self.service = service
        self.account = account
    }

    // MARK: - Public Interface

    /// Encode and persist `StoredCredentials` to the Keychain.
    /// Overwrites any existing item for the same service/account pair.
    public func save(_ credentials: StoredCredentials) async throws {
        guard let data = try? JSONEncoder().encode(credentials) else {
            throw KeychainError.encodingFailed
        }

        // First attempt an update; fall back to adding a new item.
        let updateQuery = baseQuery()
        let updateAttributes: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item does not exist yet — add it.
            var addQuery = baseQuery() as [CFString: Any]
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            logger.error("Keychain save failed with OSStatus \(status)")
            throw KeychainError.saveFailed(status)
        }
        logger.debug("Credentials saved to Keychain.")
    }

    /// Load and decode `StoredCredentials` from the Keychain.
    /// Returns `nil` if no item exists (first launch).
    public func load() async throws -> StoredCredentials? {
        var query = baseQuery() as [CFString: Any]
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            guard let credentials = try? JSONDecoder().decode(StoredCredentials.self, from: data) else {
                throw KeychainError.decodingFailed
            }
            logger.debug("Credentials loaded from Keychain for user \(credentials.userName).")
            return credentials
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Keychain load failed with OSStatus \(status)")
            throw KeychainError.loadFailed(status)
        }
    }

    /// Remove all stored credentials for this service/account from the Keychain.
    public func delete() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed with OSStatus \(status)")
            throw KeychainError.deleteFailed(status)
        }
        logger.debug("Credentials deleted from Keychain.")
    }

    // MARK: - Private Helpers

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}
