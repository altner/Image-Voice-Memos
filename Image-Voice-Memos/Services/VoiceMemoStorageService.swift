import Foundation
import AVFoundation

struct VoiceMemoStorageService {

    static func voiceMemosDirectory(for folderURL: URL) -> URL {
        folderURL.appending(component: ".voicememos", directoryHint: .isDirectory)
    }

    static func ensureVoiceMemosDirectoryExists(in folderURL: URL) throws {
        let dir = voiceMemosDirectory(for: folderURL)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func voiceMemoURL(for item: PhotoItem, in folderURL: URL) -> URL {
        voiceMemosDirectory(for: folderURL)
            .appending(component: "\(item.filenameStem).m4a")
    }

    static func voiceMemoExists(for item: PhotoItem, in folderURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: voiceMemoURL(for: item, in: folderURL).path)
    }

    static func delete(for item: PhotoItem, in folderURL: URL) throws {
        let url = voiceMemoURL(for: item, in: folderURL)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Also delete transcription .txt sidecar
        let txtURL = url.deletingPathExtension().appendingPathExtension("txt")
        if FileManager.default.fileExists(atPath: txtURL.path) {
            try FileManager.default.removeItem(at: txtURL)
        }
        // Also delete translation .en.txt sidecar
        let enTxtURL = url.deletingPathExtension().appendingPathExtension("en.txt")
        if FileManager.default.fileExists(atPath: enTxtURL.path) {
            try FileManager.default.removeItem(at: enTxtURL)
        }
    }

    static func duration(for item: PhotoItem, in folderURL: URL) async -> TimeInterval? {
        let url = voiceMemoURL(for: item, in: folderURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        return duration.seconds
    }
}
