import Foundation
import Translation

struct TranslationService {
    func makeConfiguration() -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: "de"),
            target: Locale.Language(identifier: "en")
        )
    }

    func saveTranslation(_ text: String, for audioURL: URL) throws {
        let url = audioURL.deletingPathExtension().appendingPathExtension("en.txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func loadTranslation(for audioURL: URL) -> String? {
        let url = audioURL.deletingPathExtension().appendingPathExtension("en.txt")
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
