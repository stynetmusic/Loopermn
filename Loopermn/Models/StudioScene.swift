import Foundation

struct StudioLayer: Identifiable, Hashable {
    let id: UUID
    let loopID: UUID
    let url: URL
    let displayName: String
    let sourceBPM: Int?
    let sourceKey: LoopKey
    var volume: Float
    var isMuted: Bool
    var isSoloed: Bool
    var isReady: Bool

    init(from item: LoopItem) {
        self.id = UUID()
        self.loopID = item.id
        self.url = item.url
        self.displayName = item.displayName
        self.sourceBPM = item.bpm
        self.sourceKey = item.key
        self.volume = 0.85
        self.isMuted = false
        self.isSoloed = false
        self.isReady = false
    }

    func timePitch(targetBPM: Int, targetKey: LoopKey) -> (rate: Float, pitchCents: Float) {
        let rate: Float
        if let sourceBPM, sourceBPM > 0 {
            rate = max(0.25, min(4.0, Float(targetBPM) / Float(sourceBPM)))
        } else {
            rate = 1
        }
        let cents = Float(LoopKey.semitoneDelta(from: sourceKey, to: targetKey)) * 100
        return (rate, cents)
    }
}

enum StudioLimits {
    static let maxLayers = 8
    static let minBPM = 40
    static let maxBPM = 200
}
