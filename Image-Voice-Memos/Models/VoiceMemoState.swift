import Foundation

enum VoiceMemoState: Equatable {
    case noNote
    case noteExists(duration: TimeInterval)
    case countingDown(secondsRemaining: Int)  // Countdown before recording starts
    case recording(level: Float)
    case converting
    case playing(progress: Double)
    case paused

    static func == (lhs: VoiceMemoState, rhs: VoiceMemoState) -> Bool {
        switch (lhs, rhs) {
        case (.noNote, .noNote): return true
        case (.noteExists, .noteExists): return true
        case (.countingDown, .countingDown): return true
        case (.recording, .recording): return true
        case (.converting, .converting): return true
        case (.playing, .playing): return true
        case (.paused, .paused): return true
        default: return false
        }
    }
}
