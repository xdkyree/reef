import SwiftUI

// MARK: - Reef Typography Tokens
//
// All type styles reference the tvOS system font (SF Pro Display / SF Pro Text)
// scaled appropriately for 10-foot viewing distances.
//
// Usage:
//   Text("Continue Watching")
//       .font(.reefTitle)

public extension Font {

    // MARK: Display
    /// Hero text — large dashboard section headings.
    static let reefDisplayTitle: Font = .system(size: 52, weight: .bold, design: .default)

    // MARK: Titles
    /// Primary screen title (e.g. movie title on Detail view).
    static let reefTitle: Font = .system(size: 38, weight: .bold, design: .default)

    /// Secondary title — carousel section headers.
    static let reefTitleSecondary: Font = .system(size: 28, weight: .semibold, design: .default)

    /// Tertiary title — grid section labels.
    static let reefTitleTertiary: Font = .system(size: 22, weight: .medium, design: .default)

    // MARK: Body
    /// Standard body copy — synopsis text, descriptions.
    static let reefBody: Font = .system(size: 20, weight: .regular, design: .default)

    /// Emphasised body — inline labels, short metadata values.
    static let reefBodyEmphasized: Font = .system(size: 20, weight: .semibold, design: .default)

    // MARK: Subtitle / Supporting
    /// Subtitle — year, rating badge, genre chips.
    static let reefSubtitle: Font = .system(size: 17, weight: .regular, design: .default)

    /// Caption — timestamps, secondary metadata.
    static let reefCaption: Font = .system(size: 14, weight: .regular, design: .default)

    /// Monospaced caption — runtime display (e.g. "1:58:42").
    static let reefCaptionMono: Font = .system(size: 14, weight: .regular, design: .monospaced)
}
