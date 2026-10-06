import Foundation
import Accelerate
import AVFoundation
import AppKit
import SwiftUI

final class WaveformGenerator {

    private static let cacheLock = NSLock()
    private static var sampleCache: [String: [Float]] = [:]
    private static let decodeGate = DispatchSemaphore(value: 2)

    /// Peak amplitudes 0…1, length ≈ targetWidth.
    static func samples(from url: URL, targetWidth: Int = 400) -> [Float]? {
        let key = "\(url.standardizedFileURL.path)|\(targetWidth)"
        cacheLock.lock()
        if let cached = sampleCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let data = generate(from: url, targetWidth: targetWidth) else { return nil }
        let values = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        cacheLock.lock()
        sampleCache[key] = values
        cacheLock.unlock()
        return values
    }

    static func generate(from url: URL, targetWidth: Int = 400) -> Data? {
        decodeGate.wait()
        defer { decodeGate.signal() }

        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return nil }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            return nil
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var allSamples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                CMSampleBufferInvalidate(sampleBuffer)
                continue
            }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            let data = UnsafeMutablePointer<Int16>.allocate(capacity: length / MemoryLayout<Int16>.size)
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: data)

            let count = length / MemoryLayout<Int16>.size
            for i in 0..<count {
                allSamples.append(Float(data[i]) / 32768.0)
            }
            data.deallocate()
            CMSampleBufferInvalidate(sampleBuffer)
        }

        reader.cancelReading()

        guard !allSamples.isEmpty else { return nil }

        let pixelCount = min(targetWidth, allSamples.count)
        let samplesPerPixel = max(1, allSamples.count / pixelCount)
        var waveform = [Float](repeating: 0, count: pixelCount)

        for i in 0..<pixelCount {
            let start = i * samplesPerPixel
            let end = min(start + samplesPerPixel, allSamples.count)
            let count = end - start
            let slice = Array(allSamples[start..<end])

            var maxVal: Float = 0
            vDSP_maxmgv(slice, 1, &maxVal, vDSP_Length(count))
            waveform[i] = maxVal
        }

        return waveform.withUnsafeBufferPointer { ptr in
            let bytes = ptr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: ptr.count * MemoryLayout<Float>.size) {
                Data(bytes: $0, count: ptr.count * MemoryLayout<Float>.size)
            }
            return bytes
        }
    }

    static func image(
        from waveformData: Data,
        size: CGSize = CGSize(width: 400, height: 60),
        key: LoopKey = .unknown
    ) -> NSImage? {
        guard !waveformData.isEmpty else { return nil }

        let samples = waveformData.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        guard !samples.isEmpty else { return nil }

        let colors = AppTheme.waveformGradient(for: key)

        let renderer = NSImage(size: size)
        renderer.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let path = NSBezierPath()
        let midY = size.height / 2
        let count = samples.count

        for i in 0..<count {
            let x = CGFloat(i) / CGFloat(max(count - 1, 1)) * size.width
            let amplitude = CGFloat(samples[i]) * midY * 0.95
            let topY = midY - amplitude

            if i == 0 {
                path.move(to: NSPoint(x: x, y: topY))
            } else {
                path.line(to: NSPoint(x: x, y: topY))
            }
        }

        for i in stride(from: count - 1, through: 0, by: -1) {
            let x = CGFloat(i) / CGFloat(max(count - 1, 1)) * size.width
            let bottomY = midY + CGFloat(samples[i]) * midY * 0.95
            path.line(to: NSPoint(x: x, y: bottomY))
        }

        path.close()

        let bounds = path.bounds.insetBy(dx: -1, dy: -1)
        if let gradient = NSGradient(colors: colors) {
            gradient.draw(in: path, angle: 90)
            // Soft glow fill for empty path bounds edge cases
            if bounds.width > 0, bounds.height > 0 {
                gradient.draw(in: path, angle: 90)
            }
        } else {
            colors.first?.setFill()
            path.fill()
        }

        renderer.unlockFocus()
        return renderer
    }
}

// MARK: - Interactive animated waveform scrubber (SwiftUI)

struct AnimatedWaveformScrubber: View {
    let samples: [Float]
    let progress: Double
    let color: Color
    let isPlaying: Bool
    var onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var pulse: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barCount = max(samples.count, 1)
            let spacing: CGFloat = 1.5
            let barWidth = max(1.5, (w - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))

            ZStack(alignment: .leading) {
                // Track bars
                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let amp = CGFloat(samples.indices.contains(i) ? samples[i] : 0.1)
                        let filled = Double(i) / Double(barCount) <= progress
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(filled ? color : color.opacity(0.22))
                            .frame(
                                width: barWidth,
                                height: max(3, h * (0.18 + amp * 0.82) * (isPlaying && filled ? pulse : 1))
                            )
                    }
                }
                .frame(maxHeight: .infinity)

                // Playhead
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: h * 0.92)
                    .shadow(color: color.opacity(0.6), radius: 4)
                    .offset(x: max(0, min(w - 2, w * progress - 1)))
                    .opacity(progress > 0 || isDragging ? 1 : 0.35)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let p = min(max(value.location.x / w, 0), 1)
                        onSeek(p)
                    }
                    .onEnded { value in
                        isDragging = false
                        let p = min(max(value.location.x / w, 0), 1)
                        onSeek(p)
                    }
            )
        }
        .onAppear {
            guard isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = 1.08
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    pulse = 1
                }
            }
        }
    }
}

/// Compact static waveform for list/grid previews (key-colored).
struct KeyWaveformView: View {
    let samples: [Float]
    let key: LoopKey
    var progress: Double = 0
    var showProgress: Bool = false

    private var color: Color { AppTheme.color(for: key) }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let count = max(samples.count, 1)
            let spacing: CGFloat = 1.2
            let barWidth = max(1.2, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let amp = CGFloat(samples.indices.contains(i) ? samples[i] : 0.08)
                    let filled = showProgress && (Double(i) / Double(count) <= progress)
                    RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                        .fill(filled ? color : color.opacity(showProgress ? 0.25 : 0.85))
                        .frame(width: barWidth, height: max(2, h * (0.15 + amp * 0.85)))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
