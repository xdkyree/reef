import CoreFoundation

// MARK: - Reef Spacing Tokens
//
// All layout dimensions are defined here as `CGFloat` constants
// grouped in the `Spacing` namespace enum.
//
// Usage:
//   .padding(.horizontal, Spacing.sectionPadding)

public enum Spacing {

    // MARK: Base scale (4 pt grid)
    /// 4 pt — tightest spacing; icon/badge internal padding.
    public static let xxs: CGFloat = 4
    /// 8 pt — tight spacing; between inline elements.
    public static let xs: CGFloat = 8
    /// 12 pt — small spacing; within card content.
    public static let sm: CGFloat = 12
    /// 20 pt — medium spacing; between related elements.
    public static let md: CGFloat = 20
    /// 32 pt — large spacing; between sections.
    public static let lg: CGFloat = 32
    /// 48 pt — extra-large spacing; page margins.
    public static let xl: CGFloat = 48
    /// 64 pt — 2× large; hero section top padding.
    public static let xxl: CGFloat = 64

    // MARK: Component-specific
    /// Internal horizontal padding inside a media card.
    public static let cardPadding: CGFloat = 16
    /// Horizontal inset of a carousel section from the screen edge.
    public static let sectionPadding: CGFloat = 60   // tvOS safe area convention
    /// Vertical gap between carousel rows on the Home dashboard.
    public static let carouselRowGap: CGFloat = 48
    /// Gap between cards within a horizontal carousel.
    public static let cardSpacing: CGFloat = 24
    /// Gap between cards in the Library grid.
    public static let gridSpacing: CGFloat = 28

    // MARK: Cards
    /// Standard media card width in the Home carousel.
    public static let mediaCardWidth: CGFloat = 280
    /// Standard media card height (poster ratio 2:3 → 280×420, but clipped).
    public static let mediaCardHeight: CGFloat = 380
    /// Media card corner radius.
    public static let cardCornerRadius: CGFloat = 12

    // MARK: Controls
    /// Standard corner radius for buttons and input fields.
    public static let buttonCornerRadius: CGFloat = 10
    /// Height of a primary action button.
    public static let buttonHeight: CGFloat = 66
}
