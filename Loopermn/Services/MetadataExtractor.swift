import Foundation
import AVFoundation
import Accelerate

enum MetadataError: LocalizedError {
    case fileMissing
    case emptyFile
    case unreadableAudio
    case zeroDuration

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Файл не найден после скачивания"
        case .emptyFile:
            return "Скачанный файл пустой или повреждён"
        case .unreadableAudio:
            return "Файл не является поддерживаемым аудио"
        case .zeroDuration:
            return "Не удалось прочитать длительность — файл, вероятно, повреждён"
        }
    }
}

final class MetadataExtractor {

    func extractBasicMetadata(from url: URL) async -> (duration: TimeInterval, sampleRate: Double, channels: Int, format: AVFileType) {
        let asset = AVAsset(url: url)

        var duration: TimeInterval = 0
        var sampleRate: Double = 44100
        var channels: Int = 2
        var format: AVFileType = .wav

        do {
            duration = try await asset.load(.duration).seconds
        } catch {
            duration = 0
        }

        do {
            let tracks = try await asset.load(.tracks)
            for track in tracks where track.mediaType == .audio {
                let desc = try await track.load(.formatDescriptions)
                if let cmDesc = desc.first {
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(cmDesc)
                    if let asbd = asbd {
                        sampleRate = asbd.pointee.mSampleRate
                        channels = Int(asbd.pointee.mChannelsPerFrame)
                    }
                }
                break
            }
        } catch {
            // Keep defaults
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": format = .wav
        case "aif", "aiff": format = .aiff
        case "mp3": format = .mp3
        case "m4a", "aac": format = .m4a
        case "caf": format = .caf
        default: format = .wav
        }

        return (duration, sampleRate, channels, format)
    }

    /// Validates that the file exists, is non-empty, and can be read as audio.
    func validateAndExtract(from url: URL) async throws -> (duration: TimeInterval, sampleRate: Double, channels: Int, format: AVFileType) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MetadataError.fileMissing
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int64 ?? 0
        guard size > 0 else {
            throw MetadataError.emptyFile
        }

        let asset = AVAsset(url: url)
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.load(.tracks)
        } catch {
            throw MetadataError.unreadableAudio
        }

        let hasAudio = tracks.contains { $0.mediaType == .audio }
        guard hasAudio else {
            throw MetadataError.unreadableAudio
        }

        let meta = await extractBasicMetadata(from: url)
        guard meta.duration > 0, meta.duration.isFinite else {
            throw MetadataError.zeroDuration
        }

        return meta
    }

    func generateWaveformData(from url: URL, targetWidth: Int = 800) -> Data? {
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

    func parseBPM(from filename: String) -> Int? {
        let patterns = [
            #"(\d{2,3})[\s_-]?bpm"#,
            #"bpm(\d{2,3})"#,
            #"(\d{2,3})bpm"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) {
                let range = Range(match.range(at: 1), in: filename)!
                return Int(filename[range])
            }
        }
        return nil
    }

    func parseKey(from filename: String) -> LoopKey {
        let patterns = [
            #"[A-G](#|b|sharp|flat)?\s*(maj|min|m|major|minor)?"#,
            #"(maj|min|m|major|minor)\s*[A-G](#|b|sharp|flat)?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) {
                let range = Range(match.range, in: filename)!
                let raw = String(filename[range]).uppercased()
                if let key = LoopKey(rawValue: raw) {
                    return key
                }
                let cleaned = raw
                    .replacingOccurrences(of: "MAJ", with: "")
                    .replacingOccurrences(of: "MIN", with: "")
                    .replacingOccurrences(of: "M", with: "")
                    .replacingOccurrences(of: " ", with: "")
                if let key = LoopKey(rawValue: cleaned) {
                    return key
                }
            }
        }
        return .unknown
    }
}