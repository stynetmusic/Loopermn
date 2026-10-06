import SwiftUI
import AppKit

/// Splice-style dense list row for the sample library.
struct LoopListRowView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let item: LoopItem

    @State private var samples: [Float] = []
    @State private var isHovering = false

    private var isHighlighted: Bool {
        viewModel.highlightedLoopID == item.id
    }

    private var isActive: Bool {
        viewModel.currentPlayerItem?.id == item.id
    }

    private var player: PlayerViewModel { PlayerViewModel.shared }

    private var progress: Double {
        guard isActive, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    var body: some View {
        HStack(spacing: 14) {
            // Play
            Button(action: {
                viewModel.currentPlayerItem = item
                player.play(item)
            }) {
                Image(systemName: isActive && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? AppTheme.bgDeep : AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isActive ? AppTheme.color(for: item.key) : AppTheme.bgElevated)
                    )
            }
            .buttonStyle(.plain)

            // Title + format
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(item.format.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(width: 180, alignment: .leading)

            // Waveform (key-colored, progress when active)
            Group {
                if samples.isEmpty {
                    WaveformPlaceholderView()
                } else {
                    KeyWaveformView(
                        samples: samples,
                        key: item.key,
                        progress: progress,
                        showProgress: isActive
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.bgDeep)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
            )

            MetaChip(text: item.bpm != nil ? "\(item.bpm!)" : "—", emphasized: true)
                .frame(width: 56)

            MetaChip(text: item.keyDisplay)
                .frame(width: 44)

            Text(item.formattedDuration)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 48, alignment: .trailing)

            Button(action: { viewModel.toggleFavorite(for: item) }) {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.isFavorite ? AppTheme.accent : AppTheme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isHighlighted
                        ? AppTheme.accentSoft
                        : (isHovering || isActive ? AppTheme.bgElevated : AppTheme.bgRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isHighlighted
                                ? AppTheme.accent.opacity(0.55)
                                : (isActive ? AppTheme.color(for: item.key).opacity(0.35) : AppTheme.borderSubtle),
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                )
        )
        .onHover { isHovering = $0 }
        .onAppear { loadSamples() }
        .onTapGesture {
            viewModel.currentPlayerItem = item
        }
        .contextMenu {
            Button(action: { viewModel.toggleFavorite(for: item) }) {
                Label(
                    item.isFavorite ? "Remove from favorites" : "Add to favorites",
                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                )
            }
            Divider()
            Button(action: {
                StudioViewModel.shared.addLoop(item)
                viewModel.currentMode = .studio
            }) {
                Label("Add to Studio", systemImage: "plus.rectangle.on.folder")
            }
            Divider()
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([item.url as NSURL])
            }) {
                Label("Copy path for DAW", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: { viewModel.deleteItem(item) }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .dawFileDrag(url: item.url, cornerRadius: 12)
    }

    private func loadSamples() {
        Task.detached(priority: .utility) {
            let s = WaveformGenerator.samples(from: item.url, targetWidth: 120) ?? []
            await MainActor.run { samples = s }
        }
    }
}
