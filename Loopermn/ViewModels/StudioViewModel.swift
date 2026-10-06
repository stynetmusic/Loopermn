import Foundation
import Combine
import AppKit

final class StudioViewModel: ObservableObject {
    static let shared = StudioViewModel()

    @Published var bpm: Int = 120
    @Published var key: LoopKey = .c
    @Published var layers: [StudioLayer] = []
    @Published var isPlaying: Bool = false
    @Published var statusMessage: String?
    @Published var isDropTargeted: Bool = false

    private let engine = StudioEngine()

    var canAddMore: Bool { layers.count < StudioLimits.maxLayers }

    func addLoop(_ item: LoopItem, seedSceneFromLoop: Bool = true) {
        guard canAddMore else {
            statusMessage = "Maximum \(StudioLimits.maxLayers) layers"
            return
        }
        guard FileManager.default.fileExists(atPath: item.url.path) else {
            statusMessage = "File missing: \(item.fileName)"
            return
        }

        if layers.isEmpty, seedSceneFromLoop {
            if let loopBPM = item.bpm, loopBPM > 0 {
                bpm = min(StudioLimits.maxBPM, max(StudioLimits.minBPM, loopBPM))
            }
            if item.key != .unknown {
                key = item.key
            }
        }

        let layer = StudioLayer(from: item)
        layers.append(layer)
        let layerID = layer.id
        let url = item.url
        let targetBPM = bpm
        let targetKey = key
        let initialVolume = effectiveVolume(for: layer)
        let params = layer.timePitch(targetBPM: targetBPM, targetKey: targetKey)

        Task {
            do {
                let buffer = try await engine.decodeBuffer(url: url)
                try engine.attachLayer(
                    id: layerID,
                    buffer: buffer,
                    rate: params.rate,
                    pitchCents: params.pitchCents,
                    volume: initialVolume
                )
                await MainActor.run {
                    if let index = layers.firstIndex(where: { $0.id == layerID }) {
                        layers[index].isReady = true
                    }
                    if isPlaying {
                        restartPlayback()
                    }
                }
            } catch {
                await MainActor.run {
                    layers.removeAll { $0.id == layerID }
                    statusMessage = "Could not load “\(item.displayName)”"
                }
            }
        }
    }

    func addLoops(matching urls: [URL], from library: [LoopItem]) {
        for url in urls {
            let standardized = url.standardizedFileURL
            if let item = library.first(where: { $0.url.standardizedFileURL == standardized }) {
                addLoop(item)
            } else if FileManager.default.fileExists(atPath: url.path) {
                addExternalFile(url)
            }
        }
    }

    func removeLayer(_ id: UUID) {
        engine.removeLayer(id)
        layers.removeAll { $0.id == id }
        applyMix()
        if layers.isEmpty {
            stop()
        } else if isPlaying {
            restartPlayback()
        }
    }

    func setVolume(_ volume: Float, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].volume = min(1, max(0, volume))
        applyMix()
    }

    func toggleMute(for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].isMuted.toggle()
        applyMix()
    }

    func toggleSolo(for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].isSoloed.toggle()
        applyMix()
    }

    func setBPM(_ value: Int) {
        bpm = min(StudioLimits.maxBPM, max(StudioLimits.minBPM, value))
        retuneAll()
    }

    func setKey(_ value: LoopKey) {
        key = value
        retuneAll()
    }

    func play() {
        guard layers.contains(where: \.isReady) else { return }
        PlayerViewModel.shared.pause()
        restartPlayback()
    }

    func stop() {
        engine.stopAll()
        isPlaying = false
    }

    func togglePlayStop() {
        if isPlaying { stop() } else { play() }
    }

    func stopIfPlaying() {
        if isPlaying { stop() }
    }

    func clearScene() {
        stop()
        engine.removeAllLayers()
        layers = []
    }

    private func retuneAll() {
        for layer in layers {
            let params = layer.timePitch(targetBPM: bpm, targetKey: key)
            engine.updateLayer(
                id: layer.id,
                rate: params.rate,
                pitchCents: params.pitchCents,
                volume: effectiveVolume(for: layer)
            )
        }
    }

    private func applyMix() {
        for layer in layers {
            engine.setVolume(id: layer.id, volume: effectiveVolume(for: layer))
        }
    }

    private func effectiveVolume(for layer: StudioLayer) -> Float {
        let anySolo = layers.contains(where: \.isSoloed)
        if anySolo && !layer.isSoloed { return 0 }
        if layer.isMuted { return 0 }
        return layer.volume
    }

    private func restartPlayback() {
        do {
            try engine.playAllSynced()
            isPlaying = true
        } catch {
            isPlaying = false
            statusMessage = "Studio engine failed to start"
        }
    }

    private func addExternalFile(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let item = LoopItem(
            url: url,
            fileName: url.lastPathComponent,
            displayName: name.replacingOccurrences(of: "_", with: " "),
            format: LoopFormat(from: url),
            fileSize: 0,
            duration: 0,
            sampleRate: 44_100,
            channels: 2,
            bpm: nil,
            key: .unknown,
            dateAdded: Date()
        )
        addLoop(item, seedSceneFromLoop: layers.isEmpty)
    }
}
