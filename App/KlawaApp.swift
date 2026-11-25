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
                Section("Status") {
                    LabeledContent("Wspólny folder", value: AppGroup.containerURL == nil ? "BRAK" : "ok")
                }
            }
            .navigationTitle("Klawa")
        }
    }
}
