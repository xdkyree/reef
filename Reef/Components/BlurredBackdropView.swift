import SwiftUI

// MARK: - BlurredBackdropView
//
// Full-bleed blurred background using the item's backdrop art.
// Used in DetailView and optionally behind carousel sections.

struct BlurredBackdropView: View {

    let url: URL?
    var blurRadius: CGFloat = 60
    var dimAmount: Double = 0.55

    @State private var isLoaded = false

    var body: some View {
        ZStack {
            Color.reefBackground

            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: blurRadius, opaque: true)
                            .opacity(isLoaded ? 1 : 0)
                            .onAppear {
                                withAnimation(Animations.backdropFade) {
                                    isLoaded = true
                                }
                            }
                    }
                }
            }

            // Dimming overlay to keep text legible.
            Color.black.opacity(dimAmount)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        BlurredBackdropView(url: URL(string: "https://picsum.photos/1920/1080"))
        Text("Backdrop Preview")
            .font(.reefTitle)
            .foregroundStyle(Color.reefLabel)
    }
}
