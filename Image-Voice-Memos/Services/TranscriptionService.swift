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

        do {
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true

            let transcript = try await recognizeAudio(request, with: recognizer)
            return transcript
        } catch {
            print("❌ Transcription error: \(error.localizedDescription)")
            return nil
        }
    }

    private func requestSpeechRecognitionAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func recognizeAudio(_ request: SFSpeechURLRecognitionRequest, with recognizer: SFSpeechRecognizer?) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let recognizer = recognizer else {
                continuation.resume(throwing: NSError(domain: "TranscriptionService", code: -1, userInfo: nil))
                return
            }

            var resumed = false

            let task = recognizer.recognitionTask(with: request) { result, error in
                if resumed { return }

                if let error = error {
                    print("❌ Recognition error: \(error.localizedDescription)")
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    print("✅ Transcription complete: \(text.prefix(50))...")
                    resumed = true
                    continuation.resume(returning: text)
                }
            }

            // Timeout after 60 seconds to prevent hanging forever
            let timeoutWork = DispatchWorkItem {
                guard !resumed else { return }
                resumed = true
                task.cancel()
                continuation.resume(throwing: NSError(
                    domain: "TranscriptionService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Transcription timed out after 60 seconds"]
                ))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeoutWork)
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
