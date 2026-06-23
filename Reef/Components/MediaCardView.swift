import SwiftUI

// MARK: - MediaCardView
//
// Reusable card for a single `MediaItem` used in Home carousels and Library grid.
// Applies focus scale + glassmorphic sheen on tvOS Focus Engine selection.

struct MediaCardView: View {

    let item: MediaItem
    let serverURL: URL
    var onTap: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            cardContent
                .frame(width: Spacing.mediaCardWidth, height: Spacing.mediaCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
                .overlay(sheenOverlay)
                .overlay(metadataOverlay, alignment: .bottom)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.reefAccent.opacity(0.6) : Color.reefGlassBorder,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(
                    color: isFocused
                        ? Color.reefAccent.opacity(Animations.cardShadowOpacityFocused)
                        : Color.black.opacity(0.25),
                    radius: isFocused ? Animations.cardShadowRadiusFocused : Animations.cardShadowRadius,
                    y: isFocused ? Animations.cardShadowYFocused : 4
                )
                .scaleEffect(isFocused ? Animations.focusScale : 1.0)
                .animation(Animations.focusTransition, value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
    }

    // MARK: - Sub-views

    private var cardContent: some View {
        AsyncImageView(
            url: primaryImageURL,
            contentMode: .fill,
            cornerRadius: 0
        )
        .background(Color.reefSurface)
    }

    @ViewBuilder
    private var sheenOverlay: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.reefSheenHighlight, Color.reefSheenFade],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.35)
                    )
                )
                .transition(.opacity)
                .animation(Animations.sheenAppear, value: isFocused)
        }
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // Watch progress bar (only shown when resumable)
            if let progress = item.watchProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.reefGlassFill)
                            .frame(height: 3)
                        Rectangle()
                            .fill(Color.reefAccent)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Title + year
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.displayTitle)
                    .font(.reefCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.reefLabel)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    if let year = item.productionYear {
                        Text(String(year))
                            .font(.reefCaption)
                            .foregroundStyle(Color.reefLabelSecondary)
                    }
                    if let rating = item.officialRating {
                        Text(rating)
                            .font(.reefCaption)
                            .foregroundStyle(Color.reefLabelTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.reefGlassFill)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.80)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - URL Construction

    private var primaryImageURL: URL? {
        guard item.primaryImageTag != nil else { return nil }
        return serverURL
            .appendingPathComponent(Endpoints.primaryImage(itemID: item.id))
            .appending(queryItems: [
                URLQueryItem(name: "tag", value: item.primaryImageTag),
                URLQueryItem(name: "quality", value: "90"),
                URLQueryItem(name: "maxWidth", value: "280")
            ])
    }
}
