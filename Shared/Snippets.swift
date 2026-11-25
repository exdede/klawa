import Foundation

/// Saved texts (emails, links, anything) in categories. Edited in the app, inserted from the keyboard.
struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
}

struct SnippetCategory: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var items: [Snippet] = []
}

enum Snippets {
    static func load() -> [SnippetCategory] {
        guard let data = AppGroup.defaults?.data(forKey: SettingsKey.snippets),
              let saved = try? JSONDecoder().decode([SnippetCategory].self, from: data)
        else { return ["E-mail", "Strony", "Różne"].map { SnippetCategory(name: $0) } }
        return saved
    }

    static func save(_ categories: [SnippetCategory]) {
        AppGroup.defaults?.set(try? JSONEncoder().encode(categories), forKey: SettingsKey.snippets)
    }
}
