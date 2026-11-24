import SwiftUI

@main
struct KlawaApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var phase
    @State private var reload = 0

    var body: some View {
        let defaults = AppGroup.defaults
        let lastSeen = defaults?.object(forKey: "lastSeen") as? Date
        NavigationStack {
            List {
                Section("Włączanie klawiatury") {
                    Text("1. Ustawienia → Ogólne → Klawiatura → Klawiatury → Dodaj nową klawiaturę → Klawa")
                    Text("2. Stuknij „Klawa” na liście → włącz „Pozwól na pełny dostęp”")
                    Text("3. W dowolnej apce przytrzymaj globus i wybierz Klawa")
                }
                Section("Test etapu 0") {
                    LabeledContent("ID grupy", value: AppGroup.id)
                    LabeledContent("Kontener grupy", value: AppGroup.containerURL == nil ? "BRAK" : "ok")
                    LabeledContent("Klawiatura widziana", value: lastSeen?.formatted(date: .omitted, time: .standard) ?? "brak danych")
                    LabeledContent("Pełny dostęp", value: lastSeen == nil ? "brak danych" : (defaults?.bool(forKey: "hasFullAccess") == true ? "tak" : "nie"))
                }
            }
            .navigationTitle("Klawa")
            .id(reload)
        }
        .onChange(of: phase) { _, new in if new == .active { reload += 1 } }
    }
}
