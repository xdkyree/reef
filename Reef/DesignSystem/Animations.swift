import SwiftUI

// MARK: - Reef Animation Tokens
//
// All animation constants are defined here. Use these instead of
// hardcoded `.spring()` or `.easeOut(duration:)` values anywhere
// in the codebase.
//
// Usage:
//   withAnimation(Animations.focusTransition) { isFocused = true }

public enum Animations {

    // MARK: Focus Engine Animations

    /// Scale factor applied to a card or button when it gains tvOS focus.
    public static let focusScale: CGFloat = 1.07

    /// Subtler scale for nested focusable elements inside a focused card.
    public static let focusScaleSubtle: CGFloat = 1.03

    /// Spring animation used when a card gains or loses focus.
    /// Matches the Apple TV native feel: responsive but not bouncy.
    public static let focusTransition: Animation = .spring(
        response: 0.30,
        dampingFraction: 0.70,
        blendDuration: 0.10
    )

    /// Faster spring for the sheen overlay appearing on focus.
    public static let sheenAppear: Animation = .spring(
        response: 0.22,
        dampingFraction: 0.75,
        blendDuration: 0.05
    )

    // MARK: Elevation / Shadow

    /// Shadow radius on an unfocused card.
    public static let cardShadowRadius: CGFloat = 8
    /// Shadow radius on a focused card (elevated appearance).
    public static let cardShadowRadiusFocused: CGFloat = 20
    /// Shadow Y-offset on a focused card.
    public static let cardShadowYFocused: CGFloat = 10
    /// Shadow opacity on a focused card.
    public static let cardShadowOpacityFocused: Double = 0.50

    // MARK: Screen Transitions

    /// Standard push/pop navigation transition duration.
    public static let navigationDuration: Double = 0.30

    /// Fade used when a backdrop image swaps (e.g. Detail view background).
    public static let backdropFade: Animation = .easeInOut(duration: 0.35)

    /// Controls fade-in for the player controls overlay.
    public static let controlsAppear: Animation = .easeOut(duration: 0.20)
    /// Controls fade-out after inactivity timeout.
    public static let controlsDisappear: Animation = .easeIn(duration: 0.25)

    // MARK: Shimmer (loading placeholders)

    /// Duration of one shimmer pulse cycle.
    public static let shimmerDuration: Double = 1.4

    /// Animation for the shimmer gradient sweep.
    public static var shimmer: Animation {
        .linear(duration: shimmerDuration)
        .repeatForever(autoreverses: false)
    }
}
