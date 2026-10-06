import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var player = PlayerViewModel.shared

    var playerItem: LoopItem

    @State private var scrubSamples: [Float] = []

    private var keyColor: Color { AppTheme.color(for: playerItem.key) }

    private var isThisTrack: Bool {
        player.playerItem?.id == playerItem.id
    }

    var body: some View {
        VStack(spacing: 0) {
            SpliceDivider()

            HStack(spacing: 16) {
                // Transport
                HStack(spacing: 10) {
                    Button(action: {
                        if let idx = viewModel.filteredLoops.firstIndex(where: { $0.id == playerItem.id }) {
                            player.playPrevious(from: viewModel.filteredLoops, currentIndex: idx)
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if isThisTrack {
                            player.togglePlayPause()
                        } else {
                            player.play(playerItem)
                        }
                    }) {
                        Image(systemName: player.isPlaying && isThisTrack ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.bgDeep)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(keyColor))
                            .shadow(color: keyColor.opacity(0.4), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let idx = viewModel.filteredLoops.firstIndex(where: { $0.id == playerItem.id }) {
                            player.playNext(from: viewModel.filteredLoops, currentIndex: idx)
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                // Meta
                VStack(alignment: .leading, spacing: 3) {
                    Text(playerItem.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(playerItem.bpmDisplay)
                        Text("·")
                        Text(playerItem.keyDisplay)
                            .foregroundStyle(keyColor)
                        Text("·")
                        Text(playerItem.format.rawValue)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(width: 200, alignment: .leading)

                // Animated scrubber
                VStack(spacing: 4) {
                    AnimatedWaveformScrubber(
                        samples: scrubSamples.isEmpty ? placeholderSamples : scrubSamples,
                        progress: player.progress,
                        color: keyColor,
                        isPlaying: player.isPlaying && isThisTrack,
                        onSeek: { ratio in
                            let t = ratio * max(player.duration, 0.001)
                            player.seek(to: t)
                        }
                    )
                    .frame(height: 36)

                    HStack {
                        Text(player.formattedCurrentTime)
                        Spacer()
                        Text(player.formattedDuration)
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: 480)

                Spacer(minLength: 8)

                Button(action: { player.toggleLoop() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(player.isLooping ? keyColor : AppTheme.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(player.isLooping ? keyColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Loop")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minHeight: AppTheme.playerHeight)
        .background(AppTheme.bgRaised.opacity(0.98))
        .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
        .onAppear {
            player.playerItem = playerItem
            player.duration = playerItem.duration
            loadScrubSamples()
        }
        .onChange(of: playerItem.id) { _, _ in
            player.playerItem = playerItem
            player.duration = playerItem.duration
            player.currentTime = 0
            loadScrubSamples()
        }
    }

    private var placeholderSamples: [Float] {
        (0..<64).map { i in Float(abs(sin(Double(i) * 0.4)) * 0.6 + 0.15) }
    }

    private func loadScrubSamples() {
        let url = playerItem.url
        Task.detached(priority: .utility) {
            let s = WaveformGenerator.samples(from: url, targetWidth: 96) ?? []
            await MainActor.run { scrubSamples = s }
        }
    }
}

extension PlayerViewModel {
    static let shared = PlayerViewModel()
}
