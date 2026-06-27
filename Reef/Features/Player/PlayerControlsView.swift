import SwiftUI

// MARK: - PlayerControlsView
//
// Overlay controls for the video player.
// Auto-hides after 5 s of inactivity; reappears on Siri Remote touch.
//
// Full polish pass: Task 19 (M3).

struct PlayerControlsView: View {

    @ObservedObject var viewModel: PlayerViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            // Top bar — title + close
            HStack {
                Text(viewModel.state == .loading ? "Loading…" : "")
                    .font(.reefSubtitle)
                    .foregroundStyle(Color.reefLabelSecondary)
                Spacer()
                FocusScaleButton(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.reefLabel)
                }
            }
            .padding(.horizontal, Spacing.sectionPadding)
            .padding(.top, Spacing.xl)

            Spacer()

            // Bottom bar — seek + play/pause
            VStack(spacing: Spacing.md) {
                // Seek bar
                ProgressView(
                    value: min(viewModel.currentTime, max(viewModel.duration, 1)),
                    total: max(viewModel.duration, 1)
                )
                .progressViewStyle(.linear)
                .tint(Color.reefAccent)
                .padding(.horizontal, Spacing.sectionPadding)

                // Time labels
                HStack {
                    Text(viewModel.currentTime.formattedAsHMS)
                        .font(.reefCaptionMono)
                        .foregroundStyle(Color.reefLabelSecondary)
                    Spacer()
                    Text(viewModel.duration.formattedAsHMS)
                        .font(.reefCaptionMono)
                        .foregroundStyle(Color.reefLabelSecondary)
                }
                .padding(.horizontal, Spacing.sectionPadding)

                // Play/Pause button
                FocusScaleButton(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.reefOnAccent)
                        .frame(width: 60, height: 60)
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(viewModel.showControls ? 1 : 0)
        .animation(
            viewModel.showControls ? Animations.controlsAppear : Animations.controlsDisappear,
            value: viewModel.showControls
        )
        .onTapGesture {
            viewModel.showControlsBriefly()
        }
    }
}

// MARK: - TimeInterval → HH:MM:SS

private extension TimeInterval {
    var formattedAsHMS: String {
        let total = Int(self)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
