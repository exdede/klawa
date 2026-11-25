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
                } header: {
                    Text("Ustawienia")
                } footer: {
                    Text("Zmiany działają od następnego otwarcia klawiatury.")
                }
                Section {
                    NavigationLink("Szybkie teksty") { SnippetsView() }
                } footer: {
                    Text("Maile, strony i inne teksty w kategoriach. W klawiaturze: ikona dymka obok schowka.")
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
