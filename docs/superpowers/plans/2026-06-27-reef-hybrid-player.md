# Reef Hybrid Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the dual-engine Hybrid Player architecture, providing native Apple controls via `AVPlayerViewController` and a custom liquid glass replica for `MobileVLCKit`.

**Architecture:** We will replace the standard SwiftUI `VideoPlayer` and placeholders with specialized UI representables. `AVPlayerViewController` will wrap the native UIKit player for maximum compatibility. A custom SwiftUI overlay (`VLCLiquidGlassControls`) using `.regularMaterial` will provide playback controls for the VLC engine.

**Tech Stack:** Swift 5.10, SwiftUI, UIKit (UIViewControllerRepresentable), AVKit, MobileVLCKit

## Global Constraints

- Target OS: tvOS 17.0 minimum
- No force-unwraps (`!`) in production code
- `async/await` everywhere
- SwiftUI Views: Not unit tested — Simulator verification
- Run `swiftlint lint --strict` before every commit
- Update `SPEC.md` when any architectural decision changes

---

### Task 1: Implement AVPlayerViewControllerRepresentable

**Files:**
- Create: `Reef/Features/Player/NativeAVPlayerView.swift`

**Interfaces:**
- Consumes: `AVPlayer` from `AVPlayerEngine`
- Produces: A SwiftUI View wrapping `AVPlayerViewController`

- [ ] **Step 1: Write the implementation**

```swift
// Reef/Features/Player/NativeAVPlayerView.swift
import SwiftUI
import AVKit

struct NativeAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
```

- [ ] **Step 2: Verify in Simulator / Compile Check**

Run: `xcodebuild -workspace Reef.xcworkspace -scheme Reef -sdk appletvsimulator -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" build`
Expected: Compile succeeds.

- [ ] **Step 3: Commit**

```bash
git add Reef/Features/Player/NativeAVPlayerView.swift
git commit -m "feat: add NativeAVPlayerView wrapping AVPlayerViewController"
```

### Task 2: Implement VLCPlayerView Representable

**Files:**
- Create: `Reef/Features/Player/VLCVideoSurface.swift`

**Interfaces:**
- Consumes: `VLCMediaPlayer` from `VLCPlayerEngine`
- Produces: A SwiftUI View wrapping a `UIView` that VLC can render into.

- [ ] **Step 1: Write the implementation**

```swift
// Reef/Features/Player/VLCVideoSurface.swift
import SwiftUI
import MobileVLCKit

struct VLCVideoSurface: UIViewRepresentable {
    let mediaPlayer: VLCMediaPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        mediaPlayer.drawable = view
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Render target doesn't change after creation
    }
}
```

- [ ] **Step 2: Verify Compilation**

Run: `xcodebuild -workspace Reef.xcworkspace -scheme Reef -sdk appletvsimulator -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" build`
Expected: Compile succeeds.

- [ ] **Step 3: Commit**

```bash
git add Reef/Features/Player/VLCVideoSurface.swift
git commit -m "feat: add VLCVideoSurface for MobileVLCKit rendering"
```

### Task 3: Build VLCLiquidGlassControls

**Files:**
- Create: `Reef/Features/Player/VLCLiquidGlassControls.swift`

**Interfaces:**
- Consumes: `PlayerViewModel` for state
- Produces: A SwiftUI overlay view replicating Apple's native controls

- [ ] **Step 1: Write the implementation**

```swift
// Reef/Features/Player/VLCLiquidGlassControls.swift
import SwiftUI

struct VLCLiquidGlassControls: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom transport bar mimicking tvOS native controls
            HStack(spacing: 40) {
                Button(action: { Task { await viewModel.stop(); onDismiss() } }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                }
                .buttonStyle(.plain) // Uses default tvOS focus effect
                
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.state == .playing ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
            .padding(.bottom, 60)
        }
        .opacity(viewModel.showControls ? 1 : 0)
        .animation(.default, value: viewModel.showControls)
        .onTapGesture {
            viewModel.showControlsBriefly()
        }
    }
}
```

- [ ] **Step 2: Verify Compilation**

Run: `xcodebuild -workspace Reef.xcworkspace -scheme Reef -sdk appletvsimulator -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" build`
Expected: Compile succeeds.

- [ ] **Step 3: Commit**

```bash
git add Reef/Features/Player/VLCLiquidGlassControls.swift
git commit -m "feat: add VLCLiquidGlassControls mimicking native UI"
```

### Task 4: Integrate Hybrid Engines into VideoPlayerView

**Files:**
- Modify: `Reef/Features/Player/VideoPlayerView.swift`
- Delete: `Reef/Features/Player/PlayerControlsView.swift` (obsolete custom controls)

**Interfaces:**
- Consumes: `NativeAVPlayerView`, `VLCVideoSurface`, `VLCLiquidGlassControls`
- Produces: The final dynamic routing player view.

- [ ] **Step 1: Modify VideoPlayerView**

```swift
// Reef/Features/Player/VideoPlayerView.swift
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let item: MediaItem
    let source: MediaSource
    let sessionID: String
    let token: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlayerViewModel

    init(url: URL, item: MediaItem, source: MediaSource, sessionID: String, token: String, api: JellyfinAPIClientProtocol) {
        self.url = url
        self.item = item
        self.source = source
        self.sessionID = sessionID
        self.token = token
        _viewModel = StateObject(wrappedValue: PlayerViewModel(item: item, source: source, api: api))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch PlaybackRouter.resolve(for: source) {
            case .avPlayer:
                if let avEngine = viewModel.avPlayerEngine {
                    NativeAVPlayerView(player: avEngine.player)
                        .ignoresSafeArea()
                }
            case .vlc:
                if let vlcEngine = viewModel.vlcPlayerEngine {
                    ZStack {
                        VLCVideoSurface(mediaPlayer: vlcEngine.player)
                            .ignoresSafeArea()
                        
                        VLCLiquidGlassControls(viewModel: viewModel, onDismiss: {
                            Task {
                                await viewModel.stop()
                                dismiss()
                            }
                        })
                    }
                } else {
                    ProgressView().tint(Color.reefAccent)
                }
            }
        }
        .task {
            await viewModel.startPlayback(url: url, sessionID: sessionID, token: token)
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
    }
}
```

- [ ] **Step 2: Delete PlayerControlsView**

Run: `rm Reef/Features/Player/PlayerControlsView.swift`

- [ ] **Step 3: Verify Compilation and Linting**

Run: 
`xcodebuild -workspace Reef.xcworkspace -scheme Reef -sdk appletvsimulator -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" build`
`swiftlint lint --strict`
Expected: Compile succeeds, zero lint errors.

- [ ] **Step 4: Commit**

```bash
git rm Reef/Features/Player/PlayerControlsView.swift
git add Reef/Features/Player/VideoPlayerView.swift
git commit -m "refactor: integrate Hybrid Player architecture into VideoPlayerView"
```
