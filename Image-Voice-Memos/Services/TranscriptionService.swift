import Foundation
import Speech
import AVFoundation

struct TranscriptionService {
    func transcribe(audioURL: URL, locale: Locale = Locale(identifier: "de-DE")) async -> String? {
        print("🎙️ Starting transcription for: \(audioURL.lastPathComponent) [\(locale.identifier)]")

        // Check if Speech Recognition is available for the requested locale
        guard SFSpeechRecognizer.supportedLocales().contains(locale) else {
            print("❌ Speech recognition not available for \(locale.identifier)")
            return nil
        }

        let recognizer = SFSpeechRecognizer(locale: locale)
        guard recognizer?.isAvailable == true else {
            print("❌ Speech recognizer not available")
            return nil
        }

        // Check for speech recognition permission
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            print("⚠️ Speech recognition permission not granted, requesting...")
            let authorized = await requestSpeechRecognitionAuthorization()
            if !authorized {
                print("❌ Speech recognition permission denied")
                return nil
            }
        }

        // Determine audio duration for adaptive timeout
        let audioDuration = await loadAudioDuration(url: audioURL)
        print("🎙️ Audio duration: \(String(format: "%.1f", audioDuration))s")

        do {
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true

            let timeoutSeconds = max(120.0, audioDuration * 3.0)
            print("🎙️ Transcription timeout set to \(String(format: "%.0f", timeoutSeconds))s")

            let transcript = try await recognizeAudio(request, with: recognizer, timeoutSeconds: timeoutSeconds)
            return transcript
        } catch {
            print("❌ Transcription error: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 60.0 }
        let seconds = duration.seconds
        return seconds.isNaN || seconds <= 0 ? 60.0 : seconds
    }

    private func requestSpeechRecognitionAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func recognizeAudio(_ request: SFSpeechURLRecognitionRequest, with recognizer: SFSpeechRecognizer?, timeoutSeconds: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let recognizer = recognizer else {
                continuation.resume(throwing: NSError(domain: "TranscriptionService", code: -1, userInfo: nil))
                return
            }

            var resumed = false
            var bestTranscriptSoFar = ""
            var timeoutWork: DispatchWorkItem?

            let task = recognizer.recognitionTask(with: request) { result, error in
                if resumed { return }

                if let result = result {
                    bestTranscriptSoFar = result.bestTranscription.formattedString

                    if result.isFinal {
                        let text = result.bestTranscription.formattedString
                        print("✅ Transcription complete: \(text.prefix(50))...")
                        resumed = true
                        timeoutWork?.cancel()
                        continuation.resume(returning: text)
                    }
                }

                if let error = error, !resumed {
                    print("❌ Recognition error: \(error.localizedDescription)")
                    resumed = true
                    timeoutWork?.cancel()
                    if !bestTranscriptSoFar.isEmpty {
                        print("⚠️ Returning partial transcript (\(bestTranscriptSoFar.count) chars) after error")
                        continuation.resume(returning: bestTranscriptSoFar)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Adaptive timeout to prevent hanging forever
            timeoutWork = DispatchWorkItem {
                guard !resumed else { return }
                resumed = true
                task.cancel()
                if !bestTranscriptSoFar.isEmpty {
                    print("⚠️ Transcription timed out after \(Int(timeoutSeconds))s — returning partial transcript (\(bestTranscriptSoFar.count) chars)")
                    continuation.resume(returning: bestTranscriptSoFar)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "TranscriptionService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Transcription timed out after \(Int(timeoutSeconds)) seconds"]
                    ))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWork!)
        }
    }

    func saveTranscription(_ text: String, for audioURL: URL) throws {
        let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
        try text.write(to: txtURL, atomically: true, encoding: .utf8)
    }

    func loadTranscription(for audioURL: URL) -> String? {
        let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
        return try? String(contentsOf: txtURL, encoding: .utf8)
    }
}
