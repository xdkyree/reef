import SwiftUI

// MARK: - Reef Colour Tokens
//
// All colours are declared as static properties on `Color` extensions.
// Never hardcode hex values anywhere else in the codebase — always reference
// one of these semantic tokens.
//
// Naming convention: reef.<role>[.<emphasis>]

public extension Color {

    // MARK: Backgrounds
    /// The app's primary background — deep, near-black navy.
    static let reefBackground = Color(hue: 0.625, saturation: 0.22, brightness: 0.10)

    /// Elevated surface for cards, sheets, and overlays.
    static let reefSurface = Color(hue: 0.625, saturation: 0.20, brightness: 0.15)

    /// Further-elevated surface — used for focused card highlight.
    static let reefSurfaceElevated = Color(hue: 0.625, saturation: 0.18, brightness: 0.22)

    // MARK: Accent
    /// Primary accent — a vibrant aqua/teal used for selected states and CTAs.
    static let reefAccent = Color(hue: 0.535, saturation: 0.85, brightness: 0.95)

    /// Content rendered on top of `reefAccent` backgrounds.
    static let reefOnAccent = Color.white

    // MARK: Labels
    /// Primary text label — near-white for maximum legibility.
    static let reefLabel = Color(white: 0.95)

    /// Secondary / supporting text — reduced opacity for hierarchy.
    static let reefLabelSecondary = Color(white: 0.65)

    /// Tertiary text — captions, timestamps, metadata chips.
    static let reefLabelTertiary = Color(white: 0.45)

    // MARK: Glassmorphism
    /// Semi-transparent fill applied behind glass panels.
    /// Pairs with `.ultraThinMaterial` for the glassmorphic layered effect.
    static let reefGlassFill = Color.white.opacity(0.08)

    /// 1 pt border drawn around glass surfaces.
    static let reefGlassBorder = Color.white.opacity(0.14)

    /// Top-edge sheen gradient start — the bright edge of a focused card.
    static let reefSheenHighlight = Color.white.opacity(0.28)

    /// Top-edge sheen gradient end — fades to transparent.
    static let reefSheenFade = Color.white.opacity(0.00)

    // MARK: Semantic states
    /// Destructive / error state.
    static let reefDestructive = Color(hue: 0.01, saturation: 0.78, brightness: 0.92)

    /// Success / confirmed state.
    static let reefSuccess = Color(hue: 0.37, saturation: 0.72, brightness: 0.80)

    /// Warning / caution state.
    static let reefWarning = Color(hue: 0.11, saturation: 0.90, brightness: 0.95)

    // MARK: Dividers
    /// Hairline separator between sections.
    static let reefDivider = Color.white.opacity(0.10)
}
