import SwiftUI

// MARK: - AsyncImageView
//
// Downloads and displays an image from a URL with a shimmer placeholder
// while loading and a graceful fallback on failure.
// Reads from `ImageCache` via the SwiftUI Environment.
//
// Full cache wiring: Task 21 (M4). For M2, uses SwiftUI's built-in
// `AsyncImage` with the shimmer placeholder.

struct AsyncImageView: View {

    let url: URL?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = Spacing.cardCornerRadius

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                case .failure:
                    failurePlaceholder
                case .empty:
                    shimmerPlaceholder
                @unknown default:
                    shimmerPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            failurePlaceholder
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // MARK: - Placeholders

    private var shimmerPlaceholder: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.reefSurface)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerOffset * geo.size.width)
                    .onAppear {
                        withAnimation(Animations.shimmer) {
                            shimmerOffset = 1
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var failurePlaceholder: some View {
        ZStack {
            Color.reefSurface
            Image(systemName: "photo.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.reefLabelTertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: Spacing.cardSpacing) {
        AsyncImageView(url: nil)
            .frame(width: Spacing.mediaCardWidth, height: Spacing.mediaCardHeight)
        AsyncImageView(url: URL(string: "https://picsum.photos/280/380"))
            .frame(width: Spacing.mediaCardWidth, height: Spacing.mediaCardHeight)
    }
    .padding(Spacing.xl)
    .background(Color.reefBackground)
}
