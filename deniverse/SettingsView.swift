import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prefs: PreferencesStore

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Vista previa")) {
                    themePreview
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                Section(header: Text("Tono")) {
                    Picker("Tono", selection: Binding(
                        get: { prefs.tone },
                        set: { prefs.tone = $0 }
                    )) {
                        ForEach(ThemeTone.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("General")) {
                    HStack {
                        Text("Nombre de la app")
                        Spacer()
                        Text("Deniverse")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Tema")) {
                    Picker("Color de tema", selection: Binding(
                        get: { prefs.theme },
                        set: { prefs.theme = $0 }
                    )) {
                        ForEach(ThemeColor.allCases) { c in
                            HStack {
                                Circle().fill(c.color).frame(width: 16, height: 16)
                                Text(c.displayName)
                            }.tag(c)
                        }
                    }
                }

                Section(header: Text("Preferencias")) {
                    Picker("Moneda", selection: Binding(
                        get: { prefs.preferredCurrency },
                        set: { prefs.preferredCurrency = $0 }
                    )) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("MXN").tag("MXN")
                        Text("COP").tag("COP")
                        Text("CLP").tag("CLP")
                    }
                    Toggle("Notificaciones", isOn: Binding(
                        get: { prefs.notificationsEnabled },
                        set: { prefs.notificationsEnabled = $0 }
                    ))
                }

                
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(glassBG(14))
            .foregroundStyle(.black)
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.black)
                }
            }
        }
        .tint(prefs.theme.accent(for: .white))
        .preferredColorScheme(.light)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(PreferencesStore())
    }
}

// MARK: - Preview helper

private extension SettingsView {
    var themePreview: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [prefs.theme.color.opacity(0.55), .white.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                Text("Así se verá el tema")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 12) {
                    Circle().fill(prefs.theme.color).frame(width: 18, height: 18)
                    Text(prefs.theme.displayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // Light-looking glass for settings (igual en blanco y obscuro)
    func glassBG(_ corner: CGFloat = 12) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(.regularMaterial)
            RoundedRectangle(cornerRadius: corner).fill(Color.black.opacity(0.10))
        }
    }
}
