import SwiftUI

// MARK: - FocusScaleButton
//
// A pressable, focusable button that scales up and applies a glassmorphic
// sheen when focused by the tvOS Focus Engine.
//
// Usage:
//   FocusScaleButton(action: { ... }) {
//       Label("Play", systemImage: "play.fill")
//   }

struct FocusScaleButton<Content: View>: View {

    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @FocusState private var isFocused: Bool
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonCornerRadius, style: .continuous))
                .overlay(sheenOverlay)
                .shadow(
                    color: isFocused
                        ? Color.reefAccent.opacity(Animations.cardShadowOpacityFocused)
                        : Color.clear,
                    radius: isFocused ? Animations.cardShadowRadiusFocused : 0,
                    y: isFocused ? Animations.cardShadowYFocused : 0
                )
                .scaleEffect(isFocused ? Animations.focusScale : (isPressed ? 0.96 : 1.0))
                .animation(Animations.focusTransition, value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var buttonBackground: some View {
        if isFocused {
            Color.reefAccent
        } else {
            Color.reefGlassFill
                .background(.ultraThinMaterial)
        }
    }

    private var sheenOverlay: some View {
        RoundedRectangle(cornerRadius: Spacing.buttonCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.reefSheenHighlight, Color.reefSheenFade],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .opacity(isFocused ? 1 : 0)
            .animation(Animations.sheenAppear, value: isFocused)
    }
}

// MARK: - Previews

#Preview {
    HStack(spacing: Spacing.lg) {
        FocusScaleButton(action: {}) {
            Label("Play", systemImage: "play.fill")
                .font(.reefBodyEmphasized)
                .foregroundStyle(Color.reefOnAccent)
        }
        FocusScaleButton(action: {}) {
            Label("Trailer", systemImage: "film")
                .font(.reefBody)
                .foregroundStyle(Color.reefLabel)
        }
    }
    .padding(Spacing.xl)
    .background(Color.reefBackground)
}
