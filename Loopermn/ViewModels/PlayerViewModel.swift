import Foundation
import AVFoundation
import Combine

final class PlayerViewModel: ObservableObject {

    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playerItem: LoopItem?
    @Published var isLooping: Bool = false

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var playerItemID: UUID?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    func play(_ item: LoopItem) {
        StudioViewModel.shared.stopIfPlaying()

        if playerItemID == item.id && isPlaying {
            pause()
            return
        }

        stop()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: item.url)
            audioPlayer?.numberOfLoops = isLooping ? -1 : 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            playerItem = item
            playerItemID = item.id
            duration = item.duration
            isPlaying = true

            startTimer()
        } catch {
            print("Playback error: \(error)")
        }
    }

    func togglePlayPause() {
        guard audioPlayer != nil, playerItemID != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
        playerItemID = nil
    }

    func toggleLoop() {
        isLooping.toggle()
        audioPlayer?.numberOfLoops = isLooping ? -1 : 0
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func playNext(from items: [LoopItem], currentIndex: Int) {
        guard currentIndex < items.count - 1 else { return }
        let nextItem = items[currentIndex + 1]
        play(nextItem)
    }

    func playPrevious(from items: [LoopItem], currentIndex: Int) {
        guard currentIndex > 0 else { return }
        let prevItem = items[currentIndex - 1]
        play(prevItem)
    }

    private func startTimer() {
        // ~30 fps for smooth scrubber animation; .common keeps ticks while scrolling UI
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = self.audioPlayer?.currentTime ?? 0
            if self.currentTime >= self.duration && self.duration > 0 {
                if self.isLooping {
                    self.audioPlayer?.currentTime = 0
                    self.currentTime = 0
                } else {
                    self.pause()
                    self.currentTime = 0
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time - Double(totalSeconds)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}