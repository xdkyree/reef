import XCTest
@testable import Reef

// MARK: - AuthenticationServiceTests
//
// Unit tests for `AuthenticationService`.
// All dependencies are mocked — no real network or Keychain access.

final class AuthenticationServiceTests: XCTestCase {

    // MARK: Helpers

    private func makeAuthResponse(token: String = "token-abc") -> AuthResponse {
        AuthResponse(
            accessToken: token,
            serverId: "server-1",
            user: JellyfinUser(id: "user-1", name: "Alice", primaryImageTag: nil),
            sessionInfo: nil
        )
    }

    private func makeStoredCredentials(token: String = "token-abc") -> StoredCredentials {
        StoredCredentials(
            userID: "user-1",
            userName: "Alice",
            accessToken: token,
            serverId: "server-1",
            serverURL: URL(string: "http://localhost:8096")!
        )
    }

    private func makeService(
        apiResponse: AuthResponse? = nil,
        apiError: Error? = nil,
        preloadedCredentials: StoredCredentials? = nil
    ) -> (AuthenticationService, MockJellyfinAPIClient, MockKeychainService) {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()

        Task {
            await mockAPI.set(stubbedAuthResponse: apiResponse)
            await mockAPI.set(shouldThrowError: apiError)
            await mockKeychain.set(preloadedCredentials: preloadedCredentials)
        }

        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)
        return (service, mockAPI, mockKeychain)
    }

    private let serverURL = URL(string: "http://localhost:8096")!

    // MARK: - Login Tests

    func test_login_returnsSession_onSuccess() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockAPI.set(stubbedAuthResponse: makeAuthResponse())
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        let session = try await service.login(
            serverURL: serverURL,
            username: "Alice",
            password: "secret"
        )

        XCTAssertEqual(session.userName, "Alice")
        XCTAssertEqual(session.accessToken, "token-abc")
        XCTAssertEqual(session.serverURL, serverURL)
    }

    func test_login_savesTokenToKeychain_onSuccess() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockAPI.set(stubbedAuthResponse: makeAuthResponse())
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        _ = try await service.login(serverURL: serverURL, username: "Alice", password: "secret")

        let saveCount = await mockKeychain.saveCallCount
        XCTAssertEqual(saveCount, 1, "Keychain save must be called exactly once after login.")
    }

    func test_login_throwsAuthError_onWrongPassword() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockAPI.set(shouldThrowError: NetworkError.unauthorized)
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        do {
            _ = try await service.login(serverURL: serverURL, username: "Alice", password: "wrong")
            XCTFail("Expected AuthenticationError.loginFailed")
        } catch AuthenticationError.loginFailed {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_login_throwsAuthError_onNetworkFailure() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockAPI.set(shouldThrowError: NetworkError.noConnectivity)
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        do {
            _ = try await service.login(serverURL: serverURL, username: "Alice", password: "secret")
            XCTFail("Expected AuthenticationError.loginFailed")
        } catch AuthenticationError.loginFailed {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_login_throwsInvalidServerURL_onHTTPSSchemeCheck() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)
        let badURL = URL(string: "ftp://bad-url.com")!

        do {
            _ = try await service.login(serverURL: badURL, username: "Alice", password: "secret")
            XCTFail("Expected AuthenticationError.invalidServerURL")
        } catch AuthenticationError.invalidServerURL {
            // ✓ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Logout Tests

    func test_logout_clearsSession_andDeletesKeychain() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockAPI.set(stubbedAuthResponse: makeAuthResponse())
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        _ = try await service.login(serverURL: serverURL, username: "Alice", password: "secret")
        try await service.logout()

        let session = await service.currentSession
        XCTAssertNil(session, "Session should be nil after logout.")

        let deleteCount = await mockKeychain.deleteCallCount
        XCTAssertEqual(deleteCount, 1, "Keychain delete should be called once on logout.")
    }

    // MARK: - Session Restoration Tests

    func test_restoreSession_returnsSession_whenCredentialsSaved() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockKeychain.set(preloadedCredentials: makeStoredCredentials())
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        let session = try await service.restoreSession()

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.userName, "Alice")
        XCTAssertEqual(session?.accessToken, "token-abc")
    }

    func test_restoreSession_returnsNil_whenNoCredentialsSaved() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        let session = try await service.restoreSession()

        XCTAssertNil(session, "restoreSession should return nil on first launch.")
    }

    func test_restoreSession_setsCurrentSession() async throws {
        let mockAPI = MockJellyfinAPIClient()
        let mockKeychain = MockKeychainService()
        await mockKeychain.set(preloadedCredentials: makeStoredCredentials())
        let service = AuthenticationService(apiClient: mockAPI, keychain: mockKeychain)

        _ = try await service.restoreSession()
        let current = await service.currentSession
        XCTAssertNotNil(current)
    }
}

// MARK: - MockJellyfinAPIClient convenience setters
// (actor extension to allow setting properties from non-isolated context)

private extension MockJellyfinAPIClient {
    func set(stubbedAuthResponse: AuthResponse?) async {
        self.stubbedAuthResponse = stubbedAuthResponse
    }
    func set(shouldThrowError: Error?) async {
        self.shouldThrowError = shouldThrowError
    }
}

private extension MockKeychainService {
    func set(preloadedCredentials: StoredCredentials?) async {
        self.preloadedCredentials = preloadedCredentials
    }
}

// MARK: - OnboardingViewModelTests

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    func test_connect_showsValidationError_whenFieldsAreMissing() async {
        let viewModel = OnboardingViewModel(
            connectAction: { _, _, _ in
                XCTFail("Connect action should not run for invalid input.")
                throw AuthenticationError.invalidServerURL
            },
            onSuccess: { _ in }
        )

        await viewModel.connect()

        XCTAssertEqual(viewModel.errorMessage, "Please fill in all fields.")
        XCTAssertFalse(viewModel.didConnect)
    }

    func test_connect_normalizesServerURL_beforeLogin() async {
        var capturedURL: URL?
        let viewModel = OnboardingViewModel(
            connectAction: { serverURL, _, _ in
                capturedURL = serverURL
                return UserSession(
                    userID: "user-1",
                    userName: "Alice",
                    accessToken: "token",
                    serverId: "server-1",
                    serverURL: serverURL
                )
            },
            onSuccess: { _ in }
        )
        viewModel.serverURLText = " jellyfin.lan:8096/ "
        viewModel.username = "Alice"
        viewModel.password = "secret"

        await viewModel.connect()

        XCTAssertEqual(capturedURL?.absoluteString, "http://jellyfin.lan:8096")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.didConnect)
    }

    func test_connect_surfacesAuthenticationError_message() async {
        let viewModel = OnboardingViewModel(
            connectAction: { _, _, _ in
                throw AuthenticationError.loginFailed("Invalid username or password.")
            },
            onSuccess: { _ in }
        )
        viewModel.serverURLText = "http://jellyfin.lan:8096"
        viewModel.username = "Alice"
        viewModel.password = "wrong"

        await viewModel.connect()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Login failed: Invalid username or password."
        )
        XCTAssertFalse(viewModel.didConnect)
    }
}
