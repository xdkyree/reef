import SwiftUI

// MARK: - CarouselSectionView
//
// A labelled horizontal scrolling section of `MediaCardView` items.

struct CarouselSectionView: View {

    let title: String
    let items: [MediaItem]
    let serverURL: URL
    var onSelectItem: (MediaItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text(title)
                .font(.reefTitleSecondary)
                .foregroundStyle(Color.reefLabel)
                .padding(.horizontal, Spacing.sectionPadding)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.cardSpacing) {
                    ForEach(items) { item in
                        MediaCardView(
                            item: item,
                            serverURL: serverURL,
                            onTap: { onSelectItem(item) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.sectionPadding)
                .padding(.vertical, Spacing.sm) // Give shadow room to breathe
            }
        }
    }
}
