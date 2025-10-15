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
                    Toggle("Mostrar tarjeta de bienvenida", isOn: Binding(
                        get: { !prefs.hideWelcomeCard },
                        set: { prefs.hideWelcomeCard = !$0 }
                    ))
                    Toggle("Modo Finanzas activo", isOn: Binding(
                        get: { prefs.showFinance },
                        set: { prefs.showFinance = $0 }
                    ))
                }

                Section(header: Text("Tema"), footer: Text("Se guarda en JSON para recordar tu preferencia.")) {
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

                Section(footer: Text("Estos ajustes afectan solo esta sesión de demostración.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
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
            let bgColors: [Color] = {
                switch prefs.tone {
                case .white:
                    return [prefs.theme.color.opacity(0.55), .white.opacity(0.7)]
                case .dark:
                    return [prefs.theme.themeDarkSurface.opacity(0.9), .black.opacity(0.85)]
                }
            }()
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
}
