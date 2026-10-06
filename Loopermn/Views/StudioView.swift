import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct StudioView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @ObservedObject private var studio = StudioViewModel.shared
    @State private var pickerQuery = ""
    @State private var showLibraryPicker = false

    var body: some View {
        HStack(spacing: 0) {
            libraryRail
            scenePane
        }
        .background(AppTheme.bgBase)
        .onDrop(of: [UTType.fileURL], isTargeted: $studio.isDropTargeted) { providers in
            ingestDroppedFiles(providers)
            return true
        }
        .sheet(isPresented: $showLibraryPicker) {
            StudioLibraryPicker(query: $pickerQuery) { item in
                studio.addLoop(item)
            }
            .environmentObject(viewModel)
        }
    }

    private var libraryRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LIBRARY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Search loops", text: $pickerQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.bgElevated)
            )
            .padding(.horizontal, 12)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(railLoops) { item in
                        StudioLibraryRow(item: item) {
                            studio.addLoop(item)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 260)
        .background(AppTheme.bgBase)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.borderSubtle).frame(width: 1)
        }
    }

    private var scenePane: some View {
        VStack(spacing: 0) {
            sceneHeader
            SpliceDivider()
            if studio.layers.isEmpty {
                emptyScene
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(studio.layers) { layer in
                            StudioLayerRow(layer: layer)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
        }
        .overlay {
            if studio.isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .padding(10)
                    .background(AppTheme.accent.opacity(0.06))
                    .allowsHitTesting(false)
            }
        }
    }

    private var sceneHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STUDIO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textTertiary)
                    .tracking(1.2)
                Text("\(studio.layers.count) layers")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            bpmControl
            keyControl

            Button(action: { studio.togglePlayStop() }) {
                Image(systemName: studio.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.bgDeep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppTheme.accent))
            }
            .buttonStyle(.plain)
            .disabled(studio.layers.isEmpty)
            .help(studio.isPlaying ? "Stop scene" : "Play scene")

            Button(action: { showLibraryPicker = true }) {
                Label("Add from Library", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.bgElevated)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var bpmControl: some View {
        HStack(spacing: 6) {
            Text("BPM")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
            Button { studio.setBPM(studio.bpm - 1) } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            Text("\(studio.bpm)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(minWidth: 36)
            Button { studio.setBPM(studio.bpm + 1) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.bgElevated)
        )
    }

    private var keyControl: some View {
        HStack(spacing: 6) {
            Text("KEY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
            Picker("", selection: Binding(
                get: { studio.key },
                set: { studio.setKey($0) }
            )) {
                ForEach(LoopKey.allCases.filter { $0 != .unknown }) { key in
                    Text(key.rawValue).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.bgElevated)
        )
    }

    private var emptyScene: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text("Drop loops here")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Drag from the library rail, or add a loop\nto sketch a scene. BPM and key stay in sync.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: { showLibraryPicker = true }) {
                Label("Add from Library", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.bgDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule(style: .continuous).fill(AppTheme.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var railLoops: [LoopItem] {
        let query = pickerQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return viewModel.loops }
        return viewModel.loops.filter {
            $0.displayName.lowercased().contains(query)
                || $0.fileName.lowercased().contains(query)
        }
    }

    private func ingestDroppedFiles(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = {
                    if let url = item as? URL { return url }
                    if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                    return nil
                }()
                guard let url else { return }
                DispatchQueue.main.async {
                    studio.addLoops(matching: [url], from: viewModel.loops)
                }
            }
        }
    }
}

struct StudioLibraryRow: View {
    let item: LoopItem
    let onAdd: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("\(item.bpmDisplay) · \(item.keyDisplay)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? AppTheme.bgElevated : AppTheme.bgRaised)
        )
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
    }
}

struct StudioLayerRow: View {
    @ObservedObject private var studio = StudioViewModel.shared
    let layer: StudioLayer

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.color(for: layer.sourceKey))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(layer.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(metaLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(width: 220, alignment: .leading)

            if !layer.isReady {
                ProgressView().controlSize(.small)
                    .frame(width: 120)
            } else {
                Slider(
                    value: Binding(
                        get: { Double(layer.volume) },
                        set: { studio.setVolume(Float($0), for: layer.id) }
                    ),
                    in: 0...1
                )
                .frame(maxWidth: 160)
            }

            layerToggle(
                title: "M",
                active: layer.isMuted,
                activeColor: AppTheme.danger,
                action: { studio.toggleMute(for: layer.id) }
            )
            layerToggle(
                title: "S",
                active: layer.isSoloed,
                activeColor: AppTheme.accent,
                action: { studio.toggleSolo(for: layer.id) }
            )

            Button(role: .destructive) {
                studio.removeLayer(layer.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Remove layer")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.bgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )
        )
        .opacity(layer.isMuted ? 0.55 : 1)
    }

    private var metaLabel: String {
        let bpm = layer.sourceBPM.map { "\($0) → \(studio.bpm) BPM" } ?? "\(studio.bpm) BPM"
        let key: String
        if layer.sourceKey == .unknown {
            key = studio.key.rawValue
        } else {
            key = "\(layer.sourceKey.rawValue) → \(studio.key.rawValue)"
        }
        return "\(bpm)  ·  \(key)"
    }

    private func layerToggle(
        title: String,
        active: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(active ? AppTheme.bgDeep : AppTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(active ? activeColor : AppTheme.bgElevated)
                )
        }
        .buttonStyle(.plain)
    }
}

struct StudioLibraryPicker: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var query: String
    let onPick: (LoopItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add from Library")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(16)

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            List(filtered) { item in
                Button {
                    onPick(item)
                } label: {
                    HStack {
                        Text(item.displayName)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(item.bpmDisplay) · \(item.keyDisplay)")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 520, height: 420)
        .background(AppTheme.bgBase)
    }

    private var filtered: [LoopItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return viewModel.loops }
        return viewModel.loops.filter {
            $0.displayName.lowercased().contains(q) || $0.fileName.lowercased().contains(q)
        }
    }
}
