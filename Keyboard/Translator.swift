import Foundation
import KlawaCore
import Translation

/// Apple's on-device translation (iOS 26+), PL ↔ EN. Both languages must be downloaded
/// (Klawa app → Tłumacz, or Settings → Apps → Translate). Nothing leaves the phone.
final class Translator {
    private var task: Task<Void, Never>?
    private var session: Any?
    private var sessionSource: LanguageMode?

    /// Debounced: only the last call within 0.3 s translates. `done` runs on the main thread.
    func translate(_ text: String, from source: LanguageMode, done: @escaping (Result<String, Error>) -> Void) {
        task?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return done(.success("")) }
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard #available(iOS 26.0, *) else { return done(.failure(TranslatorError.needsNewerIOS)) }
            do {
                let session: TranslationSession
                if let cached = self.session as? TranslationSession, sessionSource == source {
                    session = cached
                } else {
                    session = TranslationSession(installedSource: Locale.Language(identifier: source == .pl ? "pl" : "en"),
                                                 target: Locale.Language(identifier: source == .pl ? "en" : "pl"))
                    self.session = session
                    sessionSource = source
                }
                let response = try await session.translate(text)
                guard !Task.isCancelled else { return }
                done(.success(response.targetText))
            } catch {
                self.session = nil
                if !Task.isCancelled { done(.failure(error)) }
            }
        }
    }
}

enum TranslatorError: Error { case needsNewerIOS }
