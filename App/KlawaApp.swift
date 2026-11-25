import SwiftUI
import KlawaCore

@main
struct KlawaApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @AppStorage(SettingsKey.layout, store: AppGroup.defaults) private var layout = LayoutName.qwerty
    @AppStorage(SettingsKey.haptics, store: AppGroup.defaults) private var haptics = true
    @AppStorage(SettingsKey.autocorrect, store: AppGroup.defaults) private var autocorrect = true
    @AppStorage(SettingsKey.keyPopup, store: AppGroup.defaults) private var keyPopup = false

    var body: some View {
        NavigationStack {
            List {
                Section("Włączanie") {
                    Text("1. Settings → General → Keyboard → Keyboards → Add New Keyboard → Klawa")
                    Text("2. Stuknij „Klawa” → włącz „Allow Full Access”")
                    Text("3. W dowolnej apce przełącz globusem na Klawę")
                }
                Section {
                    Picker("Układ", selection: $layout) {
                        Text("QWERTY").tag(LayoutName.qwerty)
                        Text("Colemak").tag(LayoutName.colemak)
                    }
                    Toggle("Wibracje", isOn: $haptics)
                    Toggle("Autokorekta", isOn: $autocorrect)
                    Toggle("Powiększona litera nad klawiszem", isOn: $keyPopup)
                } header: {
                    Text("Ustawienia")
                } footer: {
                    Text("Zmiany działają od następnego otwarcia klawiatury.")
                }
                Section {
                    NavigationLink("Szybkie teksty") { SnippetsView() }
                    NavigationLink("Moje słowa") { CustomWordsView() }
                } footer: {
                    Text("Szybkie teksty: maile, strony i inne w kategoriach (ikona dymka obok schowka). Moje słowa: imiona i nazwy, które klawiatura ma znać.")
                }
                Section("Status") {
                    LabeledContent("Wspólny folder", value: AppGroup.containerURL == nil ? "BRAK" : "ok")
                }
            }
            .navigationTitle("Klawa")
        }
    }
}

struct SnippetsView: View {
    @State private var categories = Snippets.load()
    @State private var newCategory = ""

    var body: some View {
        List {
            Section {
                ForEach($categories) { $category in
                    NavigationLink {
                        CategoryView(category: $category)
                    } label: {
                        LabeledContent(category.name, value: "\(category.items.count)")
                    }
                }
                .onDelete { categories.remove(atOffsets: $0) }
                .onMove { categories.move(fromOffsets: $0, toOffset: $1) }
            }
            Section {
                HStack {
                    TextField("Nowa kategoria", text: $newCategory)
                    Button("Dodaj") {
                        categories.append(SnippetCategory(name: newCategory.trimmingCharacters(in: .whitespaces)))
                        newCategory = ""
                    }
                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Szybkie teksty")
        .toolbar { EditButton() }
        .onChange(of: categories) { _, new in Snippets.save(new) }
    }
}

struct CategoryView: View {
    @Binding var category: SnippetCategory
    @State private var newItem = ""

    var body: some View {
        List {
            Section("Nazwa") {
                TextField("Nazwa", text: $category.name)
            }
            Section {
                ForEach($category.items) { $item in
                    TextField("Tekst", text: $item.text, axis: .vertical)
                }
                .onDelete { category.items.remove(atOffsets: $0) }
                .onMove { category.items.move(fromOffsets: $0, toOffset: $1) }
                HStack {
                    TextField("Nowy tekst, np. adres e-mail", text: $newItem, axis: .vertical)
                    Button("Dodaj") {
                        category.items.append(Snippet(text: newItem))
                        newItem = ""
                    }
                    .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Teksty")
            } footer: {
                Text("Przesuń w lewo, żeby usunąć. Zmiany widać po ponownym otwarciu klawiatury.")
            }
        }
        .navigationTitle(category.name)
        .toolbar { EditButton() }
    }
}

struct CustomWordsView: View {
    @State private var words = CustomWords.load()
    @State private var newWord = ""

    var body: some View {
        List {
            Section {
                ForEach(words, id: \.self) { Text($0) }
                    .onDelete { words.remove(atOffsets: $0) }
                HStack {
                    TextField("Np. imię, z wielką literą", text: $newWord)
                        .autocorrectionDisabled()
                    Button("Dodaj") {
                        let w = newWord.trimmingCharacters(in: .whitespaces)
                        if !words.contains(w) { words.append(w) }
                        newWord = ""
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Klawiatura podpowiada te słowa, poprawia na nie literówki i wielką literę, i nigdy ich nie zmienia. "
                     + "Dyktowania Apple klawiatura nie zmieni; imię lepiej rozpoznaje, gdy jest w twojej wizytówce w Kontaktach.")
            }
        }
        .navigationTitle("Moje słowa")
        .onChange(of: words) { _, new in CustomWords.save(new) }
    }
}
