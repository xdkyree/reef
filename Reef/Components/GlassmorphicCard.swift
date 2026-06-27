import SwiftUI

// MARK: - GlassmorphicCard
//
// A reusable card container with tvOS glassmorphism:
// - .ultraThinMaterial background
// - reef.glassBorder 1 pt stroke
// - subtle shadow
//
// Usage:
//   GlassmorphicCard {
//       Text("Content")
//   }

struct GlassmorphicCard<Content: View>: View {

    @ViewBuilder let content: () -> Content
    var cornerRadius: CGFloat = Spacing.cardCornerRadius
    var padding: CGFloat = Spacing.cardPadding

    init(
        cornerRadius: CGFloat = Spacing.cardCornerRadius,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.reefGlassFill)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.reefGlassBorder, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.18),
                radius: Animations.cardShadowRadius,
                y: 4
            )
    }
}

// MARK: - Preview

#Preview {
    GlassmorphicCard {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Oppenheimer")
                .font(.reefTitle)
                .foregroundStyle(Color.reefLabel)
            Text("2023 · R · 3h 0m")
                .font(.reefSubtitle)
                .foregroundStyle(Color.reefLabelSecondary)
        }
    }
    .padding(Spacing.xl)
    .background(Color.reefBackground)
}
