import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var finance: FinanceStore
    @State private var searchText: String = ""
    @State private var txFilter: TxFilter = .all
    @State private var activeEntryType: EntryType?
    @State private var selectedTab: MainTab = .notes

    var body: some View {
        NavigationStack {
            Group {
                if selectedTab == .settings {
                    SettingsView()
                        .environmentObject(prefs)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            switch selectedTab {
                            case .agenda:
                                AgendaView()
                            case .notes:
                                NotesView(
                                    searchText: $searchText,
                                    onNew: {},
                                    onIncome: { withAnimation { selectedTab = .finance }; activeEntryType = .income },
                                    onExpense: { withAnimation { selectedTab = .finance }; activeEntryType = .expense }
                                )
                            case .finance:
                                FinanceView(
                                    txFilter: $txFilter,
                                    transactions: Binding(get: { finance.transactions }, set: { finance.transactions = $0 }),
                                    onIncome: { activeEntryType = .income },
                                    onExpense: { activeEntryType = .expense },
                                    onReports: {}
                                )
                            case .settings:
                                EmptyView() // handled above
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .foregroundStyle(contentForeground)
            .appItalic(prefs.useItalic)
            .appFontDesign(prefs.fontDesign)
            .background(themedBackground)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer(minLength: 0)
                    FooterTabBar(selected: $selectedTab)
                        .environmentObject(prefs)
                        .frame(maxWidth: 480)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    Spacer(minLength: 0)
                }
                .background(Color.clear)
            }
        }
        .sheet(item: $activeEntryType) { type in
            AddTransactionView(kind: type) { tx in
                finance.transactions.insert(tx, at: 0)
                // Ajusta el saldo directamente con el movimiento
                finance.walletBalance += tx.amount
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
                    withAnimation { selectedTab = .finance }
                    activeEntryType = .income
                }, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: {
                    withAnimation { selectedTab = .finance }
                    activeEntryType = .expense
                }, useWhiteBackground: true)
            }
        }
    }

    // Se removió la sección de Recientes y sus datos
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
                                    Text(tx.category.emoji)
                                        .font(.system(size: 16))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(tx.category.emoji) \(tx.title)")
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

    private var incomeTotal: Double { finance.transactions.filter { $0.amount > 0 }.map { $0.amount }.reduce(0, +) }
    private var expenseTotal: Double { abs(finance.transactions.filter { $0.amount < 0 }.map { $0.amount }.reduce(0, +)) }
    private var balance: Double { incomeTotal - expenseTotal }

    private var filteredTransactions: [Transaction] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return finance.transactions.filter { tx in
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

// MARK: - Footer Tab Bar

enum MainTab: String, CaseIterable, Identifiable {
    case agenda, notes, finance, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .agenda: return "Agenda"
        case .notes: return "Notas"
        case .finance: return "Finanzas"
        case .settings: return "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .agenda: return "calendar"
        case .notes: return "note.text"
        case .finance: return "banknote"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FooterTabBar: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @Binding var selected: MainTab
    @State private var dragIndex: CGFloat? // continuous index during drag

    var body: some View {
        GeometryReader { geo in
            let items = MainTab.allCases
            // Compute compact layout to avoid excessive gaps
            let count = CGFloat(items.count)
            let spacing: CGFloat = 12
            let calcItem = (geo.size.width - (count - 1) * spacing) / count
            let itemWidth: CGFloat = max(76, min(104, calcItem))
            let itemHeight: CGFloat = 36
            let capsuleWidth: CGFloat = itemWidth + 12
            let contentWidth = itemWidth * count + spacing * (count - 1)
            let originX = max(0, (geo.size.width - contentWidth) / 2)

            ZStack(alignment: .leading) {
                // Background footer container with slight blur + glass contour
                ZStack {
                    let isLight = (prefs.tone == .white)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isLight ? .regularMaterial : .ultraThinMaterial)
                        .opacity(0.75)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill((isLight ? Color.white.opacity(0.06) : Color.black.opacity(0.10)))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(isLight ? 0.45 : 0.25), prefs.theme.stroke(for: prefs.tone).opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.9
                        )
                }
                .frame(width: contentWidth + 24, height: itemHeight + 16)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                // Selector capsule (glass without blur)
                glassCapsule
                    .frame(width: capsuleWidth, height: itemHeight + 8)
                    .offset(x: originX + xForCurrent(itemWidth: itemWidth, spacing: spacing) + (itemWidth - capsuleWidth) / 2,
                            y: (geo.size.height - (itemHeight + 8)) / 2)

                HStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, tab in
                        Text(tab.title.uppercased())
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .kerning(0.6)
                            .foregroundStyle(tab == selected ? (prefs.tone == .white ? Color.black : Color.white) : subtleForeground)
                            .frame(width: itemWidth, height: itemHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tab }
                            }
                    }
                }
                .frame(width: contentWidth, height: itemHeight)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            // Drag-to-select: update highlight live; commit on end
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let slot = (itemWidth + spacing)
                        let local = max(0, min(value.location.x - originX, contentWidth))
                        let idx = local / slot
                        withAnimation(.easeOut(duration: 0.12)) { dragIndex = idx }
                    }
                    .onEnded { _ in
                        let itemsArr = items
                        let idx = Int(round((dragIndex ?? CGFloat(itemsArr.firstIndex(of: selected) ?? 0))))
                        let clamped = max(0, min(idx, itemsArr.count - 1))
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            selected = itemsArr[clamped]
                            dragIndex = nil
                        }
                    }
            )
        }
        .frame(height: 52)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.clear)
    }

    // X offset for capsule origin (uses dragIndex if present)
    private func xForCurrent(itemWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let baseIdx: CGFloat = dragIndex ?? CGFloat(MainTab.allCases.firstIndex(of: selected) ?? 0)
        return baseIdx * (itemWidth + spacing)
    }

    // Glass capsule style (no blur material)
    private var glassCapsule: some View {
        ZStack {
            let accent = prefs.theme.accent(for: prefs.tone)
            Capsule(style: .continuous)
                .fill(accent.opacity(prefs.tone == .white ? 0.22 : 0.28))
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.65), accent.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .shadow(color: (prefs.tone == .white ? .black.opacity(0.10) : .black.opacity(0.35)), radius: 10, y: 4)
    }

    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }
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

// Tipo RecentItem eliminado junto con la sección de Recientes

enum FinanceCategory: String, CaseIterable, Identifiable, Codable {
    case salary, food, coffee, transport, shopping, health, home, fun, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .salary: return "Salario"
        case .food: return "Comida"
        case .coffee: return "Café"
        case .transport: return "Transporte"
        case .shopping: return "Compras"
        case .health: return "Salud"
        case .home: return "Hogar"
        case .fun: return "Diversión"
        case .other: return "Otro"
        }
    }
    var emoji: String {
        switch self {
        case .salary: return "💼"
        case .food: return "🍔"
        case .coffee: return "☕️"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .health: return "🩺"
        case .home: return "🏠"
        case .fun: return "🎉"
        case .other: return "🧩"
        }
    }
}

struct Transaction: Identifiable {
    let id: UUID
    let title: String
    let amount: Double // positivo ingreso, negativo gasto
    let date: Date
    let category: FinanceCategory

    init(id: UUID = UUID(), title: String, amount: Double, date: Date, category: FinanceCategory = .other) {
        self.id = id; self.title = title; self.amount = amount; self.date = date; self.category = category
    }

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
            Button("Activar") { withAnimation { selectedTab = .finance } }
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

private extension ContentView {}

struct AddTransactionView: View {
    let kind: EntryType
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var category: FinanceCategory = .other

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
                Section(header: Text("Categoría")) {
                    Picker("Categoría", selection: $category) {
                        ForEach(FinanceCategory.allCases) { c in
                            Text("\(c.emoji) \(c.title)").tag(c)
                        }
                    }
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
        let tx = Transaction(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: signed, date: date, category: category)
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
