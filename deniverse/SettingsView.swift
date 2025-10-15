import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: PreferencesStore

    var body: some View {
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
                                let strokeColor: Color = {
                                    if c == .white { return prefs.tone == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.18) }
                                    if c == .black { return prefs.tone == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.5) }
                                    return prefs.theme.stroke(for: prefs.tone)
                                }()
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1))
                                Text(c.displayName)
                            }
                            .tag(c)
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

                Section(header: Text("Finanzas")) {
                    HStack {
                        Text("Límite diario de gasto")
                        Spacer()
                        Text(prefs.dailySpendLimit != nil ? currencyString(prefs.dailySpendLimit!) : "Sin límite")
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("Sin límite") { prefs.dailySpendLimit = nil }
                        Spacer()
                        Stepper(value: Binding(get: { Int(prefs.dailySpendLimit ?? 0) }, set: { prefs.dailySpendLimit = Double($0) }), in: 0...100000) {
                            Text("Ajustar: \(Int(prefs.dailySpendLimit ?? 0))")
                        }
                    }
                }

                Section(header: Text("Tipografía")) {
                    Picker("Peso", selection: Binding(
                        get: { prefs.useItalic ? 1 : 0 },
                        set: { prefs.useItalic = ($0 == 1) }
                    )) {
                        Text("Normal").tag(0)
                        Text("Cursiva").tag(1)
                    }
                    .pickerStyle(.segmented)

                    Picker("Familia", selection: Binding(
                        get: { prefs.fontDesign },
                        set: { prefs.fontDesign = $0 }
                    )) {
                        ForEach(TypographyDesign.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                }

                Section(header: Text("Salud")) {
                    Toggle("Soy mujer", isOn: Binding(
                        get: { prefs.isWoman },
                        set: { prefs.isWoman = $0 }
                    ))
                    if prefs.isWoman {
                        DatePicker("Último periodo", selection: Binding(
                            get: { prefs.lastPeriodStart },
                            set: { prefs.lastPeriodStart = $0 }
                        ), displayedComponents: .date)
                        Stepper(value: Binding(get: { prefs.cycleLength }, set: { prefs.cycleLength = $0 }), in: 20...40) {
                            Text("Duración del ciclo: \(prefs.cycleLength) días")
                        }
                        Stepper(value: Binding(get: { prefs.periodLength }, set: { prefs.periodLength = $0 }), in: 2...10) {
                            Text("Duración del periodo: \(prefs.periodLength) días")
                        }
                    }
                }

        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(glassBG(14))
        .foregroundStyle(prefs.tone == .dark ? .white : .black)
        .navigationTitle("Ajustes")
        // Usa esquema de color según Tono seleccionado
        .tint(prefs.theme.accent(for: prefs.tone))
        .preferredColorScheme(prefs.tone == .dark ? .dark : .light)
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
        // La tarjeta de vista previa debe reflejar el tono seleccionado
        let isDark = (prefs.tone == .dark)
        let bgColors: [Color] = isDark
            ? [prefs.theme.themeDarkSurface, .black.opacity(0.85)]
            : [prefs.theme.color.opacity(0.55), .white.opacity(0.7)]

        return ZStack(alignment: .leading) {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                Text("Así se verá el tema")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? Color.white : Color.black)
                HStack(spacing: 12) {
                    Circle().fill(prefs.theme.color).frame(width: 18, height: 18)
                    Text(prefs.theme.displayName)
                        .font(.footnote)
                        .foregroundStyle(isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.55))
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        // Fuerza el esquema de color solo dentro de la tarjeta
        .preferredColorScheme(isDark ? .dark : .light)
    }

    // Light-looking glass for settings (igual en blanco y obscuro)
    func glassBG(_ corner: CGFloat = 12) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(.regularMaterial)
            RoundedRectangle(cornerRadius: corner).fill(Color.black.opacity(0.10))
        }
    }
}
