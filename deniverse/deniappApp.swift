import SwiftUI

@main
struct DeniApp: App {
    @StateObject private var prefs = PreferencesStore()
    @StateObject private var agenda = AgendaStore()
    @StateObject private var finance = FinanceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prefs)
                .environmentObject(agenda)
                .environmentObject(finance)
                .tint(prefs.theme.accent(for: prefs.tone))
                .preferredColorScheme(prefs.tone == .dark ? .dark : .light)
                .appFontDesign(prefs.fontDesign)
        }
    }
}
