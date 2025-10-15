import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var searchText: String = ""
    @State private var txFilter: TxFilter = .all
    @State private var showSettings: Bool = false
    @State private var transactions: [Transaction] = [
        Transaction(title: "Salario", amount: 2400, date: .now.addingTimeInterval(-86400 * 3)),
        Transaction(title: "Café", amount: -3.9, date: .now.addingTimeInterval(-86400 * 2)),
        Transaction(title: "Supermercado", amount: -54.2, date: .now.addingTimeInterval(-86400 * 2.3)),
        Transaction(title: "Venta artículo", amount: 120, date: .now.addingTimeInterval(-86400 * 5)),
        Transaction(title: "Suscripción", amount: -9.99, date: .now.addingTimeInterval(-86400 * 7))
    ]
    @State private var activeEntryType: EntryType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    modeToggle

                    if prefs.showFinance {
                        FinanceView(
                            txFilter: $txFilter,
                            transactions: $transactions,
                            onIncome: { activeEntryType = .income },
                            onExpense: { activeEntryType = .expense },
                            onReports: {}
                        )
                    } else {
                        NotesView(
                            searchText: $searchText,
                            filteredItems: filteredItems,
                            onNew: {},
                            onIncome: { withAnimation { prefs.showFinance = true }; activeEntryType = .income },
                            onExpense: { withAnimation { prefs.showFinance = true }; activeEntryType = .expense }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .foregroundStyle(contentForeground)
            .background(themedBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $activeEntryType) { type in
            AddTransactionView(kind: type) { tx in
                transactions.insert(tx, at: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            AppLogoView(size: 56, appStroke: appStroke)
            VStack(alignment: .leading, spacing: 4) {
                Text("Deniverse")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Tu punto de partida")
                    .font(.subheadline)
                    .foregroundStyle(subtleForeground)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deniverse, tu punto de partida")
    }

    private var modeToggle: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icono circular con gradiente
            ZStack {
                let colors: [Color] = prefs.showFinance
                    ? [.green.opacity(0.9), .teal]
                    : [Color.blue.opacity(0.8), Color.purple]
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: prefs.showFinance ? "banknote" : "note.text")
                    .foregroundStyle(.white)
                    .font(.system(size: 20, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(prefs.showFinance ? "Finanzas" : "Notas")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(contentForeground)
                Text(prefs.showFinance ? "Gastos e ingresos" : "Notas y recordatorios")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
            }

            Spacer()
            Toggle("", isOn: showFinanceBinding)
                .labelsHidden()
                .tint(prefs.theme.accent(for: prefs.tone))
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(subtleForeground)
                    .accessibilityLabel("Ajustes")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(prefs)
                    .environment(\.colorScheme, .light)
                    .preferredColorScheme(.light)
                    .presentationDetents([.large])
                    .presentationBackground(.regularMaterial)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityLabel("Alternar entre inicio y finanzas")
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(subtleForeground)
            TextField("Buscar...", text: $searchText)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled(true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(alignment: .trailing) {
            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(subtleForeground)
                }
                .padding(.trailing, 10)
                .accessibilityLabel("Limpiar búsqueda")
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(appStroke, lineWidth: 1)
        )
        .accessibilityLabel("Barra de búsqueda")
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas")
                .font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Nuevo", systemImage: "plus", tint: .orange, action: {}, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: {
                    withAnimation { prefs.showFinance = true }
                    activeEntryType = .income
                }, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: {
                    withAnimation { prefs.showFinance = true }
                    activeEntryType = .expense
                }, useWhiteBackground: true)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recientes")
                .font(.headline)
            VStack(spacing: 10) {
                ForEach(filteredItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .frame(width: 28)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(contentForeground)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Text(item.subtitle)
                                .font(.footnote)
                                .foregroundStyle(subtleForeground)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(subtleForeground)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(appSurface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(appStroke, lineWidth: 1)
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private var sampleItems: [RecentItem] {
        [
            RecentItem(icon: "doc.text", title: "Documento de bienvenida", subtitle: "Editado hace 2 h"),
            RecentItem(icon: "bolt.fill", title: "Acción rápida", subtitle: "Automatización"),
            RecentItem(icon: "folder", title: "Proyecto Deni", subtitle: "Actualizado ayer")
        ]
    }

    private var filteredItems: [RecentItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sampleItems }
        return sampleItems.filter { item in
            item.title.lowercased().contains(q) || item.subtitle.lowercased().contains(q)
        }
    }
}

// MARK: - Finanzas (Gastos e Ingresos)

extension ContentView {
    private var financeHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green.opacity(0.9), .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "banknote")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Finanzas")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Gastos e ingresos")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sección de finanzas: gastos e ingresos")
    }

    private var financeSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen")
                .font(.headline)
            HStack(spacing: 12) {
                summaryCard(title: "Ingresos", value: incomeTotal, color: .green, systemImage: "arrow.down.circle.fill")
                summaryCard(title: "Gastos", value: expenseTotal, color: .red, systemImage: "arrow.up.circle.fill")
                summaryCard(title: "Balance", value: balance, color: .blue, systemImage: "equal.circle.fill")
            }
        }
    }

    private var financeFilter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filtrar")
                .font(.headline)
            Picker("Filtro", selection: $txFilter) {
                ForEach(TxFilter.allCases) { f in
                    Text(f.title).tag(f)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func summaryCard(title: String, value: Double, color: Color, systemImage: String) -> some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(appStroke, lineWidth: 1)
        )
    }

    private var financeQuickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones de finanzas")
                .font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Reportes", systemImage: "chart.pie.fill", tint: .orange, action: {}, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: {
                    activeEntryType = .income
                }, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: {
                    activeEntryType = .expense
                }, useWhiteBackground: true)
            }
        }
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transacciones")
                .font(.headline)
            Group {
                if filteredTransactions.isEmpty {
                    emptyTransactionsView
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredTransactions) { tx in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill((tx.amount < 0 ? Color.red : Color.green).opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: tx.amount < 0 ? "arrow.up" : "arrow.down")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(tx.amount < 0 ? .red : .green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(tx.dateFormatted)
                                        .font(.footnote)
                                        .foregroundStyle(subtleForeground)
                                }
                                Spacer()
                                Text(currencyString(tx.amount))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(contentForeground)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(appSurface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(appStroke, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private var incomeTotal: Double { transactions.filter { $0.amount > 0 }.map(\.amount).reduce(0, +) }
    private var expenseTotal: Double { abs(transactions.filter { $0.amount < 0 }.map(\.amount).reduce(0, +)) }
    private var balance: Double { incomeTotal - expenseTotal }

    private var filteredTransactions: [Transaction] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return transactions.filter { tx in
            let matchesFilter: Bool = {
                switch txFilter {
                case .all: return true
                case .income: return tx.amount > 0
                case .expense: return tx.amount < 0
                }
            }()
            let matchesSearch = q.isEmpty || tx.title.lowercased().contains(q)
            return matchesFilter && matchesSearch
        }
    }
}

// MARK: - Fondo temático

private extension ContentView {
    var themedBackground: some View {
        let colors: [Color] = {
            switch prefs.tone {
            case .white:
                return [prefs.theme.color.opacity(0.45), .white]
            case .dark:
                return [prefs.theme.themeDarkSurface, .black.opacity(0.85)]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }

    // Typography
    var isLightTone: Bool { prefs.tone == .white }
    var contentForeground: Color { isLightTone ? .black : .white }
    var subtleForeground: Color { isLightTone ? .black.opacity(0.7) : .white.opacity(0.85) }
    var glassBorder: Color { isLightTone ? .black.opacity(0.16) : .white.opacity(0.2) }

    // Glass background with extra tint for contrast in light tone
    @ViewBuilder
    func glass(_ corner: CGFloat = 12) -> some View {
        let material: Material = isLightTone ? .regularMaterial : .ultraThinMaterial
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(material)
            RoundedRectangle(cornerRadius: corner).fill(isLightTone ? Color.black.opacity(0.10) : Color.white.opacity(0.06))
        }
    }
}

struct AppLogoView: View {
    var size: CGFloat = 56
    let appStroke: Color

    var body: some View {
        if let uiImage = UIImage(named: "AppLogo") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(appStroke, lineWidth: 1)
                )
                .accessibilityHidden(true)
        } else {
            ZStack {
                if #available(iOS 18.0, *) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.clear)
                        .frame(width: size, height: size)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.regularMaterial)
                        )
                } else {
                    LinearGradient(
                        colors: [.blue.opacity(0.9), .purple],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.39, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(appStroke, lineWidth: 1)
            )
            .accessibilityHidden(true)
        }
    }
}

struct ActionButton: View {
    @EnvironmentObject private var prefs: PreferencesStore
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    var useWhiteBackground: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(useWhiteBackground ? Color.white : prefs.theme.surface(for: prefs.tone))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(useWhiteBackground ? (prefs.tone == .white ? Color.black.opacity(0.12) : Color.white.opacity(0.15)) : prefs.theme.stroke(for: prefs.tone), lineWidth: 1)
            )
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct RecentItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct Transaction: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double // positivo ingreso, negativo gasto
    let date: Date

    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

// MARK: - Ingreso/Gasto: tipos y formulario

enum EntryType: String, Identifiable {
    case income
    case expense
    var id: String { rawValue }

    var title: String { self == .income ? "Ingreso" : "Gasto" }
    var color: Color { self == .income ? .green : .red }
    var symbol: String { self == .income ? "arrow.down" : "arrow.up" }
}

// MARK: - Utilidades

// currencyString moved to UIUtils.swift

// MARK: - Componentes de ayuda y tipos auxiliares

private extension ContentView {
    var welcomeCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bienvenido")
                    .font(.subheadline.weight(.semibold))
                Text("Activa Finanzas para registrar ingresos y gastos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Activar") { withAnimation { prefs.showFinance = true } }
                .font(.footnote.weight(.semibold))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(appStroke, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { prefs.hideWelcomeCard = true }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .padding(8)
            .accessibilityLabel("Ocultar tarjeta de bienvenida")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tarjeta de bienvenida. Activa Finanzas para registrar movimientos")
    }

    var emptyTransactionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Sin transacciones")
                .font(.subheadline.weight(.semibold))
            Text("Agrega tu primer movimiento para empezar")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green) { activeEntryType = .income }
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red) { activeEntryType = .expense }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(appStroke, lineWidth: 1)
        )
    }
}

enum TxFilter: String, CaseIterable, Identifiable {
    case all, income, expense
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Todos"
        case .income: return "Ingresos"
        case .expense: return "Gastos"
        }
    }
}

// MARK: - Bindings para EnvironmentObject

private extension ContentView {
    var showFinanceBinding: Binding<Bool> {
        Binding(get: { prefs.showFinance }, set: { prefs.showFinance = $0 })
    }
}

struct AddTransactionView: View {
    let kind: EntryType
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = .now

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tipo")) {
                    HStack {
                        Image(systemName: kind.symbol)
                            .foregroundStyle(kind.color)
                        Text(kind.title)
                            .foregroundStyle(kind.color)
                            .fontWeight(.semibold)
                    }
                }
                Section(header: Text("Detalle")) {
                    TextField("Título", text: $title)
                    TextField("Monto", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Nuevo \(kind.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        guard let amount = parsedAmount else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    private func save() {
        guard let amount = parsedAmount, amount > 0 else { return }
        let signed = kind == .income ? amount : -amount
        let tx = Transaction(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: signed, date: date)
        onSave(tx)
        dismiss()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(PreferencesStore())
                .preferredColorScheme(.light)
            ContentView()
                .environmentObject(PreferencesStore())
                .preferredColorScheme(.dark)
        }
    }
}

