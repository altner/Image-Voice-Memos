import Foundation

extension URL {
    var filenameStem: String {
        deletingPathExtension().lastPathComponent
    }
}

extension TimeInterval {
    var formattedAsVoiceMemoDuration: String {
        let total = Int(max(0, self))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
