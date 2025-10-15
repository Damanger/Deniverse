import SwiftUI

@main
struct DeniApp: App {
    @StateObject private var prefs = PreferencesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prefs)
                .tint(prefs.theme.accent(for: prefs.tone))
                .preferredColorScheme(prefs.tone == .dark ? .dark : .light)
        }
    }
}
