import SwiftUI
import AppKit

struct LoopCardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let item: LoopItem

    @State private var waveformImage: Image?
    @State private var samples: [Float] = []
    @State private var isHovering = false

    private var isHighlighted: Bool {
        viewModel.highlightedLoopID == item.id
    }

    private var isPlaying: Bool {
        viewModel.currentPlayerItem?.id == item.id
    }

    private var player: PlayerViewModel { PlayerViewModel.shared }

    private var progress: Double {
        guard isPlaying, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    private var keyColor: Color { AppTheme.color(for: item.key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.bgDeep)

                if !samples.isEmpty {
                    KeyWaveformView(
                        samples: samples,
                        key: item.key,
                        progress: progress,
                        showProgress: isPlaying
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                } else if let waveformImage {
                    waveformImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 72)
                        .clipped()
                } else {
                    WaveformPlaceholderView()
                        .frame(height: 72)
                        .padding(.horizontal, 10)
                }

                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.currentPlayerItem = item
                        player.play(item)
                    }) {
                        Image(systemName: isPlaying && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 34))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, keyColor)
                            .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering || isPlaying ? 1 : 0)
                    .scaleEffect(isHovering || isPlaying ? 1 : 0.9)
                }
                .padding(.trailing, 10)

                if item.isFavorite {
                    VStack {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(6)
                                .background(Circle().fill(AppTheme.bgDeep.opacity(0.75)))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }

                // Key color accent bar
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [keyColor.opacity(0.0), keyColor.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 3)
                }
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isPlaying ? keyColor.opacity(0.45) : AppTheme.borderSubtle, lineWidth: 1)
            )
            .padding(10)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    MetaChip(text: item.bpm != nil ? "\(item.bpm!) BPM" : "— BPM", emphasized: true)
                    keyMetaChip
                    MetaChip(text: item.format.rawValue)
                }

                HStack(spacing: 8) {
                    Text(item.formattedDuration)
                    Text("·").foregroundStyle(AppTheme.textMuted)
                    Text(item.formattedFileSize)
                    Spacer()
                    if item.rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1..<6, id: \.self) { star in
                                Image(systemName: star <= item.rating ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(star <= item.rating ? keyColor : AppTheme.textMuted)
                            }
                        }
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(3), id: \.id) { tag in
                            Text(tag.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.bgElevated))
                        }
                        if item.tags.count > 3 {
                            Text("+\(item.tags.count - 3)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(SpliceCardBackground(isHighlighted: isHighlighted, isHovered: isHovering))
        .scaleEffect(isHighlighted ? 1.02 : (isHovering ? 1.01 : 1))
        .animation(.easeOut(duration: 0.18), value: isHighlighted)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear { generateWaveformPreview() }
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
        .dawFileDrag(url: item.url, cornerRadius: AppTheme.cornerMd)
    }

    private var keyMetaChip: some View {
        Text(item.keyDisplay)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(keyColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(keyColor.opacity(0.15))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(keyColor.opacity(0.35), lineWidth: 1)
            )
    }

    private func generateWaveformPreview() {
        let url = item.url
        Task.detached(priority: .utility) {
            let s = WaveformGenerator.samples(from: url, targetWidth: 96) ?? []
            await MainActor.run { samples = s }
        }
    }
}

struct WaveformPlaceholderView: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<48, id: \.self) { i in
                    let h = abs(sin(Double(i) * 0.45)) * 0.7 + 0.15
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppTheme.waveFill.opacity(0.35))
                        .frame(height: geo.size.height * h)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
