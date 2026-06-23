# Reef — Native tvOS Jellyfin Client

A native tvOS 17+ Jellyfin media client built in SwiftUI with a dual-engine
playback architecture, designed for zero server-side transcoding.

## Requirements

| Tool | Minimum Version |
|---|---|
| Xcode | 16.0 |
| CocoaPods | 1.15+ |
| SwiftLint | 0.57+ |
| macOS (build host) | 14.0+ |

## Bootstrap

```bash
# 1. Clone
git clone https://github.com/<org>/reef.git && cd reef

# 2. Install tools (once)
brew install xcodegen swiftlint

# 3. Generate Xcode project
xcodegen generate

# 4. Install CocoaPods dependencies
pod install

# 5. Open workspace (always use .xcworkspace — never .xcodeproj)
open Reef.xcworkspace
```

## Build

```bash
# Build for tvOS Simulator (CI-safe, no signing required)
xcodebuild \
  -workspace Reef.xcworkspace \
  -scheme Reef \
  -sdk appletvsimulator \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  -configuration Debug \
  build
```

## Test

```bash
xcodebuild \
  -workspace Reef.xcworkspace \
  -scheme ReefTests \
  -sdk appletvsimulator \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  test
```

## Lint

```bash
# Must pass before every commit
swiftlint lint --strict

# Auto-fix violations where possible
swiftlint lint --fix
```

## Architecture

See [SPEC.md](./SPEC.md) for the full technical specification.

| Layer | Technology |
|---|---|
| UI | SwiftUI + tvOS Focus Engine |
| Primary Player | AVPlayer / AVKit |
| Advanced Player | MobileVLCKit 3.x |
| Networking | URLSession + async/await |
| Keychain | Security.framework (actor-wrapped) |
| Image Cache | Custom two-tier actor (NSCache + disk) |

## Contributing

- Open `Reef.xcworkspace`, **never** `Reef.xcodeproj`.
- Run `swiftlint lint --strict` before pushing.
- Every actor must expose a `*Protocol` for test injection.
- No force-unwraps (`!`) in production code.
- No auth tokens in `UserDefaults` — Keychain only.
