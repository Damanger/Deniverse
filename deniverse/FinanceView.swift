import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var prefs: PreferencesStore

    @Binding var txFilter: TxFilter
    @Binding var transactions: [Transaction]

    let onIncome: () -> Void
    let onExpense: () -> Void
    let onReports: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickActions
            filter
        }
    }

    // MARK: - Partes

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones de finanzas").font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Reportes", systemImage: "chart.pie.fill", tint: .orange, action: onReports, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: onIncome, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: onExpense, useWhiteBackground: true)
            }
        }
    }

    private var filter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filtrar").font(.headline)
            Picker("Filtro", selection: $txFilter) {
                ForEach(TxFilter.allCases) { f in Text(f.title).tag(f) }
            }
            .pickerStyle(.segmented)
        }
    }

    // Se eliminó la lista de Transacciones

    // MARK: - Helpers
    // Se eliminó el Resumen (tarjetas, totales y balance)

    // Estilo derivado del tema (ya no usado en secciones removidas, se mantiene por si se reusa)
    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var contentForeground: Color { prefs.tone == .white ? .black : .white }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }
}
