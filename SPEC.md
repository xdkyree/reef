# Spec: Reef — Native tvOS Jellyfin Client

> **Status:** Phase 1 — Specification (awaiting human approval before implementation begins)
> **Last Updated:** 2026-06-22
> **Milestone Tracking:** See [MILESTONES.md](./MILESTONES.md) once approved.

---

## Assumptions (Verify Before Approving)

The following were not fully specified in the problem statement. I am proceeding with the assumptions below — **correct any that are wrong before approving this spec**.

| # | Assumption | Impact if Wrong |
|---|---|---|
| A1 | **MobileVLCKit** is the chosen advanced engine (not IJKPlayer) — it has a maintained binary XCFramework distribution and proven tvOS 17 support. | Dependency graph changes entirely. |
| A2 | **CocoaPods** is the dependency manager (MobileVLCKit has no official SPM distribution). A thin `Package.swift` is used for first-party modules only. | Build system scaffolding changes. |
| A3 | **Single active server** for MVP — one server URL + one set of credentials stored in Keychain at a time. Multi-server is post-MVP. | Auth architecture may need redesign. |
| A4 | The app targets **App Store distribution** (not sideload/AltStore). Entitlements must be App Store-compatible. | Entitlement choices differ. |
| A5 | **No companion iOS/watchOS app** in this repo. tvOS target only. | Project structure simplifies. |
| A6 | **No third-party analytics or crash reporting** (no Firebase) in MVP — only `os_log`. | No extra dependencies. |
| A7 | **English only** for MVP — `Localizable.strings` scaffolding exists but only `en` is populated. | Localization arch still required. |
| A8 | Jellyfin **REST API v10.8+** is the minimum server version. Older servers are rejected at handshake. | API endpoint set may change. |
| A9 | The milestone structure maps to **git branches** — each milestone is merged to `main` via PR after human verification. | Git workflow changes. |
| A10 | **GitHub Actions** is the CI provider. Each push builds the Xcode scheme in simulator mode. | CI configuration changes. |

→ **Correct any wrong assumptions before this spec is approved.**

---

## Objective

### What We're Building
Reef is a **native tvOS 17+ Jellyfin media client** built entirely in SwiftUI with a dual-engine playback architecture. It eliminates the need for server-side transcoding by declaring full native codec support at the API level and falling back gracefully only when strictly necessary.

### Who Is the User
A technically literate home media enthusiast who self-hosts Jellyfin, owns an Apple TV 4K, has a curated library of mixed-format media (MKV, HEVC, TrueHD, DTS-HD), and has been frustrated by existing clients that trigger unnecessary transcoding, stutter under high-bitrate content, or look visually dated.

### Why It Matters

| Problem | Reef's Solution |
|---|---|
| Other clients trigger transcoding for MKV/HEVC | Dual-engine: VLCKit plays natively; no transcode needed |
| Infuse requires expensive subscription | Free, open-source, zero paywall |
| Jellyfin official tvOS app has dated UI | Native SwiftUI glassmorphic design with Focus Engine |
| Audio desync on complex audio tracks | VLCKit low-level renderer handles TrueHD/DTS-HD |
| Resume position lost between sessions | Periodic progress reporting every 10 s to Jellyfin API |

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Language | Swift | 5.10+ |
| UI Framework | SwiftUI + TVUIKit focus primitives | tvOS 17 SDK |
| Target OS | tvOS | 17.0 minimum |
| Primary Player | AVPlayer / AVKit | tvOS 17 SDK |
| Advanced Player | MobileVLCKit | 3.x (XCFramework binary) |
| Dependency Manager | CocoaPods (MobileVLCKit) + SPM (first-party) | CocoaPods 1.15+ |
| Networking | URLSession + async/await | stdlib |
| Keychain | Security.framework wrapped in `KeychainService` actor | stdlib |
| Image Caching | Custom `ImageCache` actor (NSCache + disk tier) | custom |
| Logging | `os.Logger` | stdlib |
| CI | GitHub Actions | — |
| Minimum Xcode | Xcode 16.0 | — |

---

## Commands

```bash
# Clone and bootstrap
git clone https://github.com/<org>/reef.git && cd reef
pod install

# Open workspace (ALWAYS use .xcworkspace, never .xcodeproj)
open Reef.xcworkspace

# Build for tvOS Simulator (CI-safe, no signing required)
xcodebuild \
  -workspace Reef.xcworkspace \
  -scheme Reef \
  -sdk appletvsimulator \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  -configuration Debug \
  build

# Run unit tests
xcodebuild \
  -workspace Reef.xcworkspace \
  -scheme ReefTests \
  -sdk appletvsimulator \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  test

# Lint (must pass before any commit)
swiftlint lint --strict

# Auto-fix lint violations
swiftlint lint --fix

# Archive for App Store (requires signing identity)
xcodebuild \
  -workspace Reef.xcworkspace \
  -scheme Reef \
  -sdk appletvos \
  -configuration Release \
  archive \
  -archivePath build/Reef.xcarchive
```

---

## Project Structure

```
reef/
├── SPEC.md                          ← This file (source of truth)
├── MILESTONES.md                    ← Per-milestone task tracking
├── CHANGELOG.md                     ← Human-readable release history
├── Podfile                          ← CocoaPods: MobileVLCKit
├── Podfile.lock
├── Package.swift                    ← SPM: first-party utility modules
├── Reef.xcworkspace/
│
├── Reef/                            ← Main application target
│   ├── ReefApp.swift                ← @main entry point
│   ├── ContentView.swift            ← Root navigation coordinator
│   │
│   ├── Core/                        ← Business logic; zero UIKit/SwiftUI imports
│   │   ├── Networking/
│   │   │   ├── JellyfinAPIClient.swift      ← actor; all HTTP calls
│   │   │   ├── Endpoints.swift              ← URL path constants
│   │   │   ├── HTTPMethod.swift
│   │   │   └── NetworkError.swift
│   │   ├── Auth/
│   │   │   ├── AuthenticationService.swift  ← actor; owns session state
│   │   │   ├── KeychainService.swift        ← actor; Security.framework wrapper
│   │   │   └── AuthModels.swift             ← AuthResponse, UserSession
│   │   ├── Models/
│   │   │   ├── MediaItem.swift
│   │   │   ├── UserLibrary.swift
│   │   │   ├── PlaybackInfo.swift
│   │   │   ├── SubtitleTrack.swift
│   │   │   └── AudioTrack.swift
│   │   ├── Playback/
│   │   │   ├── PlaybackEngine.swift         ← protocol; engine-agnostic interface
│   │   │   ├── AVPlayerEngine.swift         ← AVPlayer conformance
│   │   │   ├── VLCPlayerEngine.swift        ← MobileVLCKit conformance
│   │   │   ├── PlaybackRouter.swift         ← selects engine based on codec
│   │   │   └── PlaybackReporter.swift       ← periodic progress → Jellyfin API
│   │   └── Cache/
│   │       ├── ImageCache.swift             ← actor; NSCache + disk tier
│   │       └── MetadataCache.swift
│   │
│   ├── Features/                    ← One folder per screen/feature
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── HomeViewModel.swift
│   │   │   └── CarouselSectionView.swift
│   │   ├── Library/
│   │   │   ├── LibraryView.swift
│   │   │   └── LibraryViewModel.swift
│   │   ├── Detail/
│   │   │   ├── DetailView.swift
│   │   │   └── DetailViewModel.swift
│   │   └── Player/
│   │       ├── VideoPlayerView.swift        ← UIViewRepresentable / VLC bridge
│   │       ├── PlayerControlsView.swift
│   │       └── PlayerViewModel.swift
│   │
│   ├── Components/                  ← Reusable SwiftUI views
│   │   ├── MediaCardView.swift
│   │   ├── GlassmorphicCard.swift
│   │   ├── FocusScaleButton.swift
│   │   ├── AsyncImageView.swift
│   │   └── BlurredBackdropView.swift
│   │
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   ├── Spacing.swift
│   │   └── Animations.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Localizable.strings
│       └── Info.plist
│
├── ReefTests/
│   ├── Core/
│   │   ├── JellyfinAPIClientTests.swift
│   │   ├── AuthenticationServiceTests.swift
│   │   ├── PlaybackRouterTests.swift
│   │   └── ImageCacheTests.swift
│   └── Helpers/
│       ├── MockURLSession.swift
│       └── MockKeychainService.swift
│
└── .github/
    └── workflows/
        └── ci.yml
```

---

## Code Style

### Golden Rules
- All ViewModels are `@MainActor final class` conforming to `ObservableObject`.
- All networking/auth/cache types are Swift **actors**.
- No force-unwraps (`!`) in production code — SwiftLint enforces this as an error.
- `async/await` everywhere — no completion handlers in new code.
- Dependency injection via `@EnvironmentObject`, never instantiated inside child views.

### Canonical Actor + ViewModel Pattern

```swift
// Core/Networking/JellyfinAPIClient.swift
actor JellyfinAPIClient {
    private let session: URLSession
    private let baseURL: URL

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchMediaItems(libraryID: String, userID: String, token: String) async throws -> [MediaItem] {
        let url = baseURL
            .appendingPathComponent("Users/\(userID)/Items")
            .appending(queryItems: [
                URLQueryItem(name: "ParentId", value: libraryID),
                URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            ])
        var request = URLRequest(url: url)
        request.setValue("MediaBrowser Token=\"\(token)\"", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.unexpectedStatusCode((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder.jellyfinDecoder.decode(JellyfinItemsResponse.self, from: data).items
    }
}

// Features/Home/HomeViewModel.swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var continueWatching: [MediaItem] = []
    @Published private(set) var recentlyAdded: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let api: JellyfinAPIClient

    init(api: JellyfinAPIClient) { self.api = api }

    func loadDashboard(userID: String, token: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let cw = api.fetchContinueWatching(userID: userID, token: token)
            async let ra = api.fetchRecentlyAdded(userID: userID, token: token)
            (continueWatching, recentlyAdded) = try await (cw, ra)
        } catch { self.error = error }
    }
}
```

### Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| SwiftUI View | `PascalCase` + `View` suffix | `MediaCardView` |
| ViewModel | `PascalCase` + `ViewModel` suffix | `HomeViewModel` |
| Actor | `PascalCase` + `Service`/`Client`/`Cache` | `JellyfinAPIClient` |
| Protocol | `PascalCase` (no suffix) | `PlaybackEngine` |
| Enum cases | `lowerCamelCase` | `.directPlay` |
| Constants | `static let` in `enum` namespaces | `Spacing.cardPadding` |

### SwiftLint Rules (`.swiftlint.yml`)
- `force_unwrapping: error`
- `force_cast: error`
- `line_length: warning: 120, error: 160`
- `file_length: warning: 400, error: 600`
- `function_body_length: warning: 50`

---

## Testing Strategy

**Framework:** XCTest (built-in, no third-party test runner for MVP).

| Layer | Test Type | Coverage Target |
|---|---|---|
| `JellyfinAPIClient` | Unit (mock URLSession) | 90%+ |
| `AuthenticationService` | Unit (mock Keychain) | 90%+ |
| `PlaybackRouter` | Unit (codec → engine mapping) | 100% |
| `ImageCache` | Unit (eviction, disk read/write) | 80%+ |
| ViewModels | Unit (mock API actor) | 80%+ |
| SwiftUI Views | Not unit tested — Simulator verification | — |
| VLC bridge | Not unit tested — requires physical device | — |

**Rules:**
- Every actor exposes a protocol (`JellyfinAPIClientProtocol`) so tests inject a `MockJellyfinAPIClient`.
- No real network calls in unit tests — ever.
- Tests must pass on `xcodebuild ... test` without a physical device.

---

## Boundaries

### Always Do
- Run `swiftlint lint --strict` before every commit.
- Write/update unit tests for every new actor, service, or router.
- Report playback progress every 10 s via Jellyfin API.
- Gate all token/credential access behind `KeychainService` — never `UserDefaults`.
- Use semantic design tokens from `DesignSystem/` — never hardcode hex values.
- Update `SPEC.md` when any architectural decision changes.
- Open `Reef.xcworkspace`, never `.xcodeproj`.

### Ask First
- Adding any new CocoaPods or SPM dependency.
- Changing the minimum Jellyfin API version (A8).
- Altering the `PlaybackEngine` protocol interface.
- Adding build configurations or schemes.
- Changing CI workflow.
- Enabling any new App Store entitlement.
- Scoping in multi-server support (post-MVP).

### Never Do
- Force-unwrap (`!`) in production code.
- Store auth tokens in `UserDefaults`.
- Trigger a server transcode when the codec is natively playable.
- Commit `.xcworkspace/xcuserdata/` or personal Xcode state.
- Remove a failing test instead of fixing it.
- Ship with active `DEBUG` preprocessor flags.
- Embed MobileVLCKit source — consume the pre-built XCFramework only.

---

## Success Criteria

### Functional
- [ ] **SC-F1:** User authenticates against a Jellyfin 10.8+ server; token written to Keychain survives app restart.
- [ ] **SC-F2:** Home dashboard renders four carousels with populated data within 2 s on a local network.
- [ ] **SC-F3:** A 4K HDR MKV (HEVC + TrueHD) begins playing via VLCKit within 3 s of tapping Play — zero transcoding on server.
- [ ] **SC-F4:** An MP4/M4V file plays via AVPlayer and bitstreams Dolby Atmos to a compatible receiver.
- [ ] **SC-F5:** Subtitle track switching works without restarting playback; ASS/SSA subtitles render with correct styling.
- [ ] **SC-F6:** Playback position reported every 10 s; stopping sends `/Sessions/Playing/Stopped`; resuming picks up within 5 s of stored position.
- [ ] **SC-F7:** Library grid loads 200+ items without memory warnings on Apple TV 4K (3rd gen, 3 GB RAM).
- [ ] **SC-F8:** Profile switching changes active `UserSession` without re-entering server URL.

### Performance
- [ ] **SC-P1:** App launch → Home dashboard fully rendered: < 3 s on local network.
- [ ] **SC-P2:** Focus card scale + sheen animation: ≤ 16 ms frame time (60 fps min, 120 fps target).
- [ ] **SC-P3:** Image cache hit for a previously seen thumbnail: < 5 ms.
- [ ] **SC-P4:** Memory during rapid Library scroll: < 400 MB peak RSS.

### Quality
- [ ] **SC-Q1:** Zero SwiftLint errors on `--strict` mode.
- [ ] **SC-Q2:** Unit test suite passes 100% on simulator.
- [ ] **SC-Q3:** CI pipeline passes on every `main` branch commit.

---

## Milestones (High-Level)

| Milestone | Scope | Gate Condition |
|---|---|---|
| **M1** | Core Networking & Architecture | `JellyfinAPIClient` actor + models + folder structure + CI | Human reviews files |
| **M2** | Onboarding + Home Screen | Login flow, `HomeViewModel`, carousel UI | Human verifies on Simulator |
| **M3** | Multimedia Playback Engine | `PlaybackEngine` protocol, AVPlayer + VLC bridges, controls, progress reporting | Human tests against real Jellyfin server |
| **M4** | Production Polish & Cache | `ImageCache` hardening, focus transitions, memory profiling | Human profiles with Instruments |

---

## Open Questions

| ID | Question | Blocking Milestone |
|---|---|---|
| OQ-1 | Is **MobileVLCKit** confirmed, or is IJKPlayer preferred? | M1 |
| OQ-2 | Is **CocoaPods** acceptable, or should the VLCKit XCFramework be vendored directly (eliminating CocoaPods)? | M1 |
| OQ-3 | Should the app support **AirPlay 2** output during VLC playback? | M3 |
| OQ-4 | Is a **Jellyfin admin API key** available for development, or will a regular user account be used? | M1 |
| OQ-5 | Should the Detail View display **RT / IMDb scores**? Acceptable to hide badges when absent? | M2 |
| OQ-6 | What is the **App Store Bundle ID / Apple Team ID**? | M1 |
| OQ-7 | Is **Tailscale** support network-level only (user configures separately), or does the app embed the Tailscale SDK? | M1 |
| OQ-8 | Should the Home dashboard support **live TV / IPTV channels**, or is this explicitly post-MVP? | M2 |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-06-22 | Agent (Phase 1) | Initial spec draft — awaiting human approval |
