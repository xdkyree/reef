# Spec: Reef Production Readiness & Polish
**Date:** 2026-06-27
**Topic:** App Hardening, Hybrid Player Architecture, and UX Enhancements

## 1. Objective
To transition the Reef tvOS app from an MVP state to a polished, production-ready release. This involves finalizing the dual-engine player architecture, hardening the app against crashes and silent failures, adding premium UI/UX metadata features, and fulfilling App Store requirements.

## 2. Architecture: The Hybrid Player
Reef will implement a dual-engine player to provide the best native experience while avoiding server-side transcoding.

- **AVPlayer Engine:** For natively supported formats (MP4, etc.), use `AVPlayerViewController` wrapped in `UIViewControllerRepresentable`. This provides Apple's genuine liquid glass controls, Siri Remote scrubbing, and Top Shelf metadata for free.
- **VLC Engine:** For MKV/HEVC formats, use `MobileVLCKit` wrapped in a `UIViewRepresentable` to replace the current `vlcPlaceholder` infinite loader.
- **Custom VLC Overlay (`VLCLiquidGlassControls`):** A custom SwiftUI overlay built exclusively for the VLC engine. It will utilize tvOS `.regularMaterial` blur and SF Symbols to meticulously replicate the native AVPlayer controls, ensuring a consistent user experience.

## 3. Hardening & Stability
- **Robust Error Handling:** Replace silent network and playback failures with native tvOS Alerts containing a "Retry" and "Cancel" action.
- **Memory Optimization:** Update the `ImageCache` actor to aggressively evict cached images upon receiving memory warnings, preventing crashes during rapid Library scrolling.
- **Authentication Resilience:** Implement a session observer that monitors the Jellyfin token. If the token expires or is rejected, gracefully dismiss the user to the Onboarding view instead of hanging.

## 4. UI/UX Enhancements (Rich Metadata)
- **Immersive Backdrops:** Implement a system where focusing on a media item on the Home or Library screens crossfades the app's background to a blurred, full-screen version of the item's backdrop image.
- **Ratings Badges:** Pull community ratings (Rotten Tomatoes / IMDb) and content ratings (e.g., PG-13, TV-MA) from the Jellyfin API and display them as polished badges on the `DetailView` and `GlassmorphicCard`s.
- **Cast & Crew Carousels:** Add a horizontally scrolling carousel on the `DetailView` featuring actor headshots and character names.
- **Logo Art:** Utilize transparent logo art from Jellyfin (when available) in place of plain text titles on the `DetailView`.
- **Seamless Loading:** Apply `.crossFade` transitions to all `AsyncImageView`s to prevent images from abruptly popping into view.
- **Focus Engine Polish:** Ensure `FocusScaleButton` and `GlassmorphicCard` apply the native tvOS 3D parallax and sheen effects during Siri Remote interactions.

## 5. Production & Release Readiness
- **App Icons & Top Shelf:** Add properly layered tvOS parallax App Icons and a static Top Shelf image to the asset catalog.
- **Production Logging:** Replace all `print()` statements with `os.Logger` configured for production to prevent performance degradation and console clutter.
- **Localization Scaffolding:** Extract all hardcoded strings into `Localizable.strings` to ensure the app is ready for future localization and meets App Store standards.
