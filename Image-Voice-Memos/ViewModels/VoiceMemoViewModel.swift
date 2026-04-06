import Foundation
import AppKit
import AVFoundation
import Translation

@MainActor
final class VoiceMemoViewModel: ObservableObject {

    @Published var voiceMemoState: VoiceMemoState = .noNote
    @Published var playbackTime: TimeInterval = 0
    @Published var recordingTime: TimeInterval = 0
    @Published var showMicPermissionAlert = false

    private let recorder = AudioRecordingService()
    private let player = AudioPlaybackService()
    private let transcriptionService = TranscriptionService()
    let translationService = TranslationService()
    private var meteringTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingStartTime: Date?

    @Published var transcription: String = ""
    @Published var isTranscribing: Bool = false
    @Published var translation: String = ""
    @Published var isTranslating: Bool = false
    @Published var translationConfiguration: TranslationSession.Configuration?

    weak var libraryViewModel: LibraryViewModel?

    init() {
        recorder.onFinished = { [weak self] success in
            Task { @MainActor [weak self] in
                self?.handleRecordingFinished(success: success)
            }
        }
        player.onFinished = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackFinished()
            }
        }
    }

    func loadState(for item: PhotoItem) {
        stopPlayback()
        stopMeteringTimer()

        guard let folderURL = libraryViewModel?.folderURL else {
            voiceMemoState = .noNote
            transcription = ""
            return
        }

        // Load transcription and translation regardless of voice note existence
        let url = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
        if let transcript = transcriptionService.loadTranscription(for: url) {
            transcription = transcript
        } else {
            transcription = ""
        }
        if let trans = translationService.loadTranslation(for: url) {
            translation = trans
        } else {
            translation = ""
        }

        if VoiceMemoStorageService.voiceMemoExists(for: item, in: folderURL) {
            Task {
                let dur = await VoiceMemoStorageService.duration(for: item, in: folderURL) ?? 0
                voiceMemoState = .noteExists(duration: dur)
            }
        } else {
            voiceMemoState = .noNote
        }

        // Pre-warm the recorder so it starts instantly when the user taps Record
        prepareRecorder(for: item, in: folderURL)
    }

    private func prepareRecorder(for item: PhotoItem, in folderURL: URL) {
        do {
            try VoiceMemoStorageService.ensureVoiceMemosDirectoryExists(in: folderURL)
            let url = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
            try recorder.prepare(targetURL: url)
        } catch {
            // Preparation failed; will fall back to non-prepared start
        }
    }

    func startRecording(for item: PhotoItem) {
        guard let folderURL = libraryViewModel?.folderURL else { return }

        let status = recorder.microphonePermissionStatus()
        if status == .notDetermined {
            Task {
                let granted = await recorder.requestMicrophonePermission()
                guard granted else { showMicPermissionAlert = true; return }
                showCountdown(for: item, in: folderURL)
            }
            return
        }
        guard status == .authorized else {
            showMicPermissionAlert = true
            return
        }

        showCountdown(for: item, in: folderURL)
    }

    private func showCountdown(for item: PhotoItem, in folderURL: URL) {
        voiceMemoState = .countingDown(secondsRemaining: 1)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            await MainActor.run {
                self.beginRecording(for: item, in: folderURL)
            }
        }
    }

    private func beginRecording(for item: PhotoItem, in folderURL: URL) {
        do {
            let expectedURL = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
            try VoiceMemoStorageService.ensureVoiceMemosDirectoryExists(in: folderURL)

            if recorder.isPrepared && recorder.targetURL == expectedURL {
                // Recorder was pre-warmed for THIS exact photo — instant start
                recorder.startPreparedRecording()
            } else {
                // Not prepared, or prepared for a different photo — start fresh with correct URL
                try recorder.startRecording(to: expectedURL)
            }

            // Countdown has given the audio hardware time to warm up,
            // so recording is now active and capture clean audio
            recordingStartTime = Date()
            recordingTime = 0
            voiceMemoState = .recording(level: 0)
            startMeteringTimer()
        } catch {
            // Recording failed silently; state stays as-is
        }
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        stopMeteringTimer()
        _ = recorder.stopRecording()
        // State will be refreshed by handleRecordingFinished
    }

    func cancelRecording() {
        stopMeteringTimer()
        recorder.cancelRecording()
        // Reload state — a previous voice note may still exist on disk
        // (also cancels any pending countdown)
        if let item = libraryViewModel?.selectedItem {
            loadState(for: item)
        } else {
            voiceMemoState = .noNote
        }
    }

    func startPlayback(for item: PhotoItem) {
        guard let folderURL = libraryViewModel?.folderURL else { return }
        let url = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
        do {
            try player.play(url: url)
            voiceMemoState = .playing(progress: 0)
            playbackTime = 0
            startPlaybackTimer()
        } catch {
            // Playback failed; state unchanged
        }
    }

    func pausePlayback() {
        player.pause()
        stopPlaybackTimer()
        voiceMemoState = .paused
    }

    func resumePlayback() {
        player.resume()
        voiceMemoState = .playing(progress: player.duration > 0 ? player.currentTime / player.duration : 0)
        startPlaybackTimer()
    }

    func stopPlayback() {
        player.stop()
        stopPlaybackTimer()
        playbackTime = 0
    }

    func deleteVoiceMemo(for item: PhotoItem) {
        guard let folderURL = libraryViewModel?.folderURL else { return }
        stopPlayback()
        try? VoiceMemoStorageService.delete(for: item, in: folderURL)
        voiceMemoState = .noNote
        transcription = ""
        translation = ""
        libraryViewModel?.refreshVoiceMemoStatus(for: item)
    }

    // MARK: - Private

    private func startMeteringTimer() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let level = self.recorder.currentLevel
                if let start = self.recordingStartTime {
                    self.recordingTime = Date().timeIntervalSince(start)
                }
                self.voiceMemoState = .recording(level: level)
            }
        }
    }

    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.isPlaying else { return }
                let duration = self.player.duration
                let current = self.player.currentTime
                self.playbackTime = current
                let progress = duration > 0 ? current / duration : 0
                self.voiceMemoState = .playing(progress: progress)
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func handleRecordingFinished(success: Bool) {
        stopMeteringTimer()
        recordingStartTime = nil
        if success, let item = libraryViewModel?.selectedItem, let folderURL = libraryViewModel?.folderURL {
            voiceMemoState = .converting
            Task {
                let pipelineStart = Date()

                do {
                    try await recorder.convertToAAC()
                } catch {
                    print("❌ AAC conversion failed: \(error.localizedDescription)")
                    voiceMemoState = .noNote
                    return
                }

                let url = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
                let conversionTime = Date().timeIntervalSince(pipelineStart)
                print("⏱️ AAC conversion took \(String(format: "%.1f", conversionTime))s")

                // Pre-buffer audio for instant playback
                try? player.prepare(url: url)

                let dur = await VoiceMemoStorageService.duration(for: item, in: folderURL) ?? 0
                print("⏱️ Audio duration: \(String(format: "%.1f", dur))s")

                await MainActor.run {
                    self.voiceMemoState = .noteExists(duration: dur)
                }
                self.libraryViewModel?.refreshVoiceMemoStatus(for: item)

                // Transcribe audio in background (can take time on first run)
                await MainActor.run {
                    self.isTranscribing = true
                }

                let transcriptionStart = Date()
                let locale = self.libraryViewModel?.transcriptionLanguage.locale ?? Locale(identifier: "de-DE")
                if let transcript = await transcriptionService.transcribe(audioURL: url, locale: locale) {
                    let transcriptionTime = Date().timeIntervalSince(transcriptionStart)
                    print("⏱️ Transcription took \(String(format: "%.1f", transcriptionTime))s")
                    print("📝 Transcript received (\(transcript.count) chars): \(transcript.prefix(100))...")
                    do {
                        try transcriptionService.saveTranscription(transcript, for: url)
                        print("💾 Transcript saved successfully")
                        await MainActor.run {
                            self.transcription = transcript
                            self.isTranscribing = false
                            print("✅ Transcription updated in UI: \(self.transcription.prefix(50))...")
                            self.triggerTranslationIfNeeded()
                        }
                    } catch {
                        print("❌ Failed to save transcription: \(error)")
                        await MainActor.run {
                            self.isTranscribing = false
                        }
                    }
                } else {
                    let transcriptionTime = Date().timeIntervalSince(transcriptionStart)
                    print("❌ Transcription failed or returned nil after \(String(format: "%.1f", transcriptionTime))s")
                    await MainActor.run {
                        self.isTranscribing = false
                    }
                }
            }
        } else {
            voiceMemoState = .noNote
        }
    }

    func triggerTranslationIfNeeded() {
        guard libraryViewModel?.translateToEnglish == true,
              !transcription.isEmpty,
              libraryViewModel?.transcriptionLanguage != .english else { return }
        isTranslating = true
        translationConfiguration = translationService.makeConfiguration()
    }

    func handleTranslationResult(_ text: String) {
        guard let item = libraryViewModel?.selectedItem,
              let folderURL = libraryViewModel?.folderURL else { return }
        let url = VoiceMemoStorageService.voiceMemoURL(for: item, in: folderURL)
        translation = text
        isTranslating = false
        try? translationService.saveTranslation(text, for: url)
    }

    func handleTranslationError() {
        isTranslating = false
    }

    private func handlePlaybackFinished() {
        stopPlaybackTimer()
        playbackTime = 0
        if let item = libraryViewModel?.selectedItem, let folderURL = libraryViewModel?.folderURL {
            Task {
                let dur = await VoiceMemoStorageService.duration(for: item, in: folderURL) ?? 0
                voiceMemoState = .noteExists(duration: dur)
            }
        } else {
            voiceMemoState = .noNote
        }
    }
}
