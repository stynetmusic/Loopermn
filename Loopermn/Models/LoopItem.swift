import Foundation
import AVFoundation

enum LoopFormat: String, Codable, CaseIterable, Identifiable {
    case wav = "WAV"
    case aiff = "AIFF"
    case mp3 = "MP3"
    case flac = "FLAC"
    case aac = "AAC"
    case ogg = "OGG"
    case caf = "CAF"
    case other = "Other"

    var id: String { rawValue }

    init(from url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": self = .wav
        case "aif", "aiff": self = .aiff
        case "mp3": self = .mp3
        case "flac": self = .flac
        case "aac", "m4a": self = .aac
        case "ogg", "oga": self = .ogg
        case "caf": self = .caf
        default: self = .other
        }
    }
}

enum LoopKey: String, Codable, CaseIterable, Identifiable {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "D#"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "G#"
    case a = "A"
    case aSharp = "A#"
    case b = "B"
    case unknown = "—"

    var id: String { rawValue }

    /// 0 = C … 11 = B. `nil` for unknown.
    var chromaticIndex: Int? {
        switch self {
        case .c: return 0
        case .cSharp: return 1
        case .d: return 2
        case .dSharp: return 3
        case .e: return 4
        case .f: return 5
        case .fSharp: return 6
        case .g: return 7
        case .gSharp: return 8
        case .a: return 9
        case .aSharp: return 10
        case .b: return 11
        case .unknown: return nil
        }
    }

    /// Shortest-path semitone shift from `from` to `to`. 0 if either key is unknown.
    static func semitoneDelta(from: LoopKey, to: LoopKey) -> Int {
        guard let source = from.chromaticIndex, let target = to.chromaticIndex else { return 0 }
        var delta = target - source
        while delta > 6 { delta -= 12 }
        while delta < -6 { delta += 12 }
        return delta
    }
}

struct LoopTag: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LoopItem: Codable, Identifiable, Hashable {
    let id: UUID
    var url: URL
    var fileName: String
    var displayName: String
    var format: LoopFormat
    var fileSize: Int64
    var duration: TimeInterval
    var sampleRate: Double
    var channels: Int
    var bpm: Int?
    var key: LoopKey
    var dateAdded: Date
    var tags: [LoopTag]
    var rating: Int
    var isFavorite: Bool
    var waveformData: Data?

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var bpmDisplay: String {
        guard let bpm = bpm else { return "—"
        }
        return "\(bpm) BPM"
    }

    var keyDisplay: String {
        key.rawValue
    }

    init(
        url: URL,
        fileName: String,
        displayName: String,
        format: LoopFormat,
        fileSize: Int64,
        duration: TimeInterval,
        sampleRate: Double,
        channels: Int,
        bpm: Int?,
        key: LoopKey,
        dateAdded: Date,
        tags: [LoopTag] = [],
        rating: Int = 0,
        isFavorite: Bool = false,
        waveformData: Data? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.fileName = fileName
        self.displayName = displayName
        self.format = format
        self.fileSize = fileSize
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.bpm = bpm
        self.key = key
        self.dateAdded = dateAdded
        self.tags = tags
        self.rating = rating
        self.isFavorite = isFavorite
        self.waveformData = waveformData
    }
}