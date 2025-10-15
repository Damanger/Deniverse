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
            summary
            quickActions
            filter
            transactionsList
        }
    }

    // MARK: - Partes
    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen").font(.headline)
            HStack(spacing: 12) {
                summaryCard(title: "Ingresos", value: incomeTotal, systemImage: "arrow.down.circle.fill")
                summaryCard(title: "Gastos", value: expenseTotal, systemImage: "arrow.up.circle.fill")
                summaryCard(title: "Balance", value: balance, systemImage: "equal.circle.fill")
            }
        }
    }

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

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transacciones").font(.headline)
            VStack(spacing: 10) {
                ForEach(filteredTransactions.indices, id: \.self) { index in
                    let tx = filteredTransactions[index]
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill((tx.amount < 0 ? Color.red : Color.green).opacity(0.12)).frame(width: 32, height: 32)
                            Image(systemName: tx.amount < 0 ? "arrow.up" : "arrow.down")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(tx.amount < 0 ? .red : .green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.title).font(.subheadline.weight(.semibold))
                            Text(tx.dateFormatted).font(.footnote).foregroundStyle(subtleForeground)
                        }
                        Spacer()
                        Text(currencyString(tx.amount)).font(.subheadline.weight(.semibold)).foregroundStyle(contentForeground)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(appStroke, lineWidth: 1))
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Helpers
    private func summaryCard(title: String, value: Double, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(subtleForeground)
            Text(currencyString(value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(contentForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appStroke, lineWidth: 1))
    }

    private var incomeTotal: Double { transactions.filter { $0.amount > 0 }.map(\.amount).reduce(0, +) }
    private var expenseTotal: Double { abs(transactions.filter { $0.amount < 0 }.map(\.amount).reduce(0, +)) }
    private var balance: Double { incomeTotal - expenseTotal }

    private var filteredTransactions: [Transaction] {
        transactions.filter { tx in
            switch txFilter {
            case .all: return true
            case .income: return tx.amount > 0
            case .expense: return tx.amount < 0
            }
        }
    }

    // Estilo derivado del tema
    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var contentForeground: Color { prefs.tone == .white ? .black : .white }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }
}

