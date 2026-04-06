import Foundation
import AVFoundation

@MainActor
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {

    private var player: AVAudioPlayer?
    var onFinished: ((Bool) -> Void)?

    var isPlaying: Bool { player?.isPlaying ?? false }
    var isPrepared: Bool { player != nil && !(player?.isPlaying ?? false) }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    /// Pre-loads and buffers audio so playback can start instantly.
    func prepare(url: URL) throws {
        stop()
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.delegate = self
        newPlayer.prepareToPlay()
        self.player = newPlayer
    }

    /// Starts a pre-buffered player instantly.
    func playPrepared() {
        player?.play()
    }

    func play(url: URL) throws {
        try prepare(url: url)
        playPrepared()
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.onFinished?(flag)
        }
    }
}
