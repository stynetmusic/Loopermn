import Foundation
import AVFoundation

/// Multi-track loop engine: one player + TimePitch per layer.
/// Decoded PCM is cached so BPM/key changes only retune live nodes.
final class StudioEngine {

    private struct Track {
        let player: AVAudioPlayerNode
        let timePitch: AVAudioUnitTimePitch
        let mixer: AVAudioMixerNode
        var buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private var tracks: [UUID: Track] = [:]
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]
    private let workingFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    var isRunning: Bool { engine.isRunning }

    deinit {
        stopAll()
        if engine.isRunning { engine.stop() }
    }

    func decodeBuffer(url: URL) async throws -> AVAudioPCMBuffer {
        let key = url.standardizedFileURL.path
        if let cached = bufferCache[key] { return cached }

        let decoded = try await Task.detached(priority: .userInitiated) { [workingFormat] in
            try StudioEngine.decodeFile(url: url, to: workingFormat)
        }.value

        bufferCache[key] = decoded
        return decoded
    }

    func attachLayer(
        id: UUID,
        buffer: AVAudioPCMBuffer,
        rate: Float,
        pitchCents: Float,
        volume: Float
    ) throws {
        removeLayer(id)

        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.overlap = 8
        timePitch.rate = rate
        timePitch.pitch = pitchCents

        let mixer = AVAudioMixerNode()
        mixer.outputVolume = volume

        engine.attach(player)
        engine.attach(timePitch)
        engine.attach(mixer)

        engine.connect(player, to: timePitch, format: workingFormat)
        engine.connect(timePitch, to: mixer, format: workingFormat)
        engine.connect(mixer, to: engine.mainMixerNode, format: workingFormat)

        tracks[id] = Track(player: player, timePitch: timePitch, mixer: mixer, buffer: buffer)

        try startEngineIfNeeded()
    }

    func updateLayer(id: UUID, rate: Float, pitchCents: Float, volume: Float) {
        guard let track = tracks[id] else { return }
        track.timePitch.rate = rate
        track.timePitch.pitch = pitchCents
        track.mixer.outputVolume = volume
    }

    func setVolume(id: UUID, volume: Float) {
        tracks[id]?.mixer.outputVolume = volume
    }

    func removeLayer(_ id: UUID) {
        guard let track = tracks.removeValue(forKey: id) else { return }
        track.player.stop()
        engine.disconnectNodeOutput(track.player)
        engine.disconnectNodeOutput(track.timePitch)
        engine.disconnectNodeOutput(track.mixer)
        engine.detach(track.player)
        engine.detach(track.timePitch)
        engine.detach(track.mixer)
    }

    func playAllSynced() throws {
        try startEngineIfNeeded()

        for track in tracks.values {
            track.player.stop()
            track.player.scheduleBuffer(track.buffer, at: nil, options: [.loops, .interrupts])
        }

        let startTime = synchronizedStartTime()
        for track in tracks.values {
            if let startTime {
                track.player.play(at: startTime)
            } else {
                track.player.play()
            }
        }
    }

    func stopAll() {
        for track in tracks.values {
            track.player.stop()
        }
    }

    func removeAllLayers() {
        stopAll()
        for id in tracks.keys {
            removeLayer(id)
        }
    }

    private func startEngineIfNeeded() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    private func synchronizedStartTime() -> AVAudioTime? {
        guard let last = engine.outputNode.lastRenderTime, last.isSampleTimeValid else {
            return nil
        }
        let delay = AVAudioFramePosition(workingFormat.sampleRate * 0.04)
        return AVAudioTime(sampleTime: last.sampleTime + delay, atRate: last.sampleRate)
    }

    private static func decodeFile(url: URL, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0,
              let raw = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames)
        else {
            throw NSError(
                domain: "StudioEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not read audio file"]
            )
        }
        try file.read(into: raw)

        if sourceFormat.sampleRate == format.sampleRate,
           sourceFormat.channelCount == format.channelCount {
            return raw
        }
        return try convert(raw, to: format)
    }

    private static func convert(_ source: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: source.format, to: format) else {
            throw NSError(
                domain: "StudioEngine",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Audio format conversion failed"]
            )
        }
        let ratio = format.sampleRate / source.format.sampleRate
        let destFrames = AVAudioFrameCount(Double(source.frameLength) * ratio) + 32
        guard let dest = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: destFrames) else {
            throw NSError(
                domain: "StudioEngine",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not allocate converted buffer"]
            )
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: dest, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return source
        }
        if let error { throw error }
        return dest
    }
}
