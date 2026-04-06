import Foundation
import AVFoundation

@MainActor
final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {

    private var recorder: AVAudioRecorder?
    private(set) var tempRecordingURL: URL?
    private(set) var targetURL: URL?
    var onFinished: ((Bool) -> Void)?

    var isRecording: Bool { recorder?.isRecording ?? false }
    var isPrepared: Bool { recorder != nil && !(recorder?.isRecording ?? false) }

    var currentLevel: Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        return max(0, (db + 80) / 80)
    }

    func requestMicrophonePermission() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    func microphonePermissionStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private static let recordingSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// Pre-creates the recorder and warms up audio hardware.
    /// Call this when a photo is selected so recording can start instantly later.
    func prepare(targetURL url: URL) throws {
        // Clean up any previous prepared-but-not-started recorder
        if isPrepared {
            recorder = nil
            cleanupTempFiles()
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        self.tempRecordingURL = temp
        self.targetURL = url

        let newRecorder = try AVAudioRecorder(url: temp, settings: Self.recordingSettings)
        newRecorder.delegate = self
        newRecorder.isMeteringEnabled = true
        newRecorder.prepareToRecord()  // Warms up audio hardware + allocates buffers
        self.recorder = newRecorder
    }

    /// Starts a pre-warmed recorder instantly. Call prepare(targetURL:) first.
    func startPreparedRecording() {
        recorder?.record()
    }

    /// Fallback: creates recorder and starts recording in one call.
    func startRecording(to url: URL) throws {
        try prepare(targetURL: url)
        startPreparedRecording()
    }

    func stopRecording() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = tempRecordingURL
        self.recorder = nil
        return url
    }

    /// Konvertiert das aufgenommene PCM-Audio zu AAC/M4A für kompakte Speicherung.
    func convertToAAC() async throws {
        guard let tempURL = tempRecordingURL, let finalURL = targetURL else { return }

        let asset = AVURLAsset(url: tempURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            cleanupTempFiles()
            throw NSError(domain: "AudioRecordingService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Export session could not be created"])
        }
        try? FileManager.default.removeItem(at: finalURL)
        try await session.export(to: finalURL, as: .m4a)

        cleanupTempFiles()
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        cleanupTempFiles()
    }

    private func cleanupTempFiles() {
        if let temp = tempRecordingURL {
            try? FileManager.default.removeItem(at: temp)
        }
        tempRecordingURL = nil
        targetURL = nil
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.onFinished?(flag)
        }
    }
}
