import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var finance: FinanceStore

    @Binding var txFilter: TxFilter
    @Binding var transactions: [Transaction]

    let onIncome: () -> Void
    let onExpense: () -> Void
    let onReports: () -> Void

    enum Period: String, CaseIterable, Identifiable { case day, week, month; var id: String { rawValue }; var title: String { self == .day ? "Día" : self == .week ? "Semana" : "Mes" } }
    @State private var selectedPeriod: Period = .week
    @State private var showLimitAlert = false
    @FocusState private var walletFocused: Bool
    enum BalanceMode: String, CaseIterable, Identifiable { case total, today; var id: String { rawValue }; var title: String { self == .total ? "Saldo" : "Hoy" } }
    @State private var balanceMode: BalanceMode = .total
    @State private var dragX: CGFloat = 0
    // Day filter state (Todos / Hoy / Fecha)
    enum DayMode: String, CaseIterable, Identifiable { case all, today, specific; var id: String { rawValue }; var title: String { self == .all ? "Todos" : (self == .today ? "Hoy" : "Fecha") } }
    @State private var dayMode: DayMode = .all
    @State private var daySelected: Date = .now
    @State private var showReports = false

    @State private var seasonalEffect: SeasonalEffect? = SeasonalEffectPicker.pick()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let eff = seasonalEffect { SeasonalOverlay(effect: eff).ignoresSafeArea() }
            VStack(alignment: .leading, spacing: 16) {
            header
            balanceCard
            quickActions
            filter
            transactionsList
            chartSection
            }
        }
        .appItalic(prefs.useItalic)
        .appFontDesign(prefs.fontDesign)
        .onReceive(finance.$transactions) { _ in checkLimit() }
        .onAppear { checkLimit(); seasonalEffect = SeasonalEffectPicker.pick() }
        .alert("Límite diario excedido", isPresented: $showLimitAlert, actions: {
            Button("Entendido", role: .cancel) {}
        }, message: {
            Text("Has superado tu límite diario de gasto.")
        })
        // Modal centrado para Reportes (reemplaza popover)
        .overlay(alignment: .center) {
            if showReports {
                GeometryReader { geo in
                    let modalW = min(geo.size.width * 0.9, 420)
                    let modalH = min(geo.size.height * 0.9, 520)
                    ZStack {
                        // Scrim
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showReports = false } }

                        // Card
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { showReports = false }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 8)

                            // Content area (scroll if small screens)
                            ScrollView {
                                FinanceReportsView()
                                    .environmentObject(prefs)
                                    .environmentObject(finance)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: modalW, height: modalH)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(appStroke, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                        .transition(.scale(scale: 0.98).combined(with: .opacity))
                    }
                }
                .zIndex(10)
            }
        }
    }

    // MARK: - Partes

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas").font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Reportes", systemImage: "chart.pie.fill", tint: .orange, action: { showReports = true; onReports() }, useWhiteBackground: true)
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
            // Day filter
            Picker("Día", selection: $dayMode) {
                ForEach(DayMode.allCases) { m in Text(m.title).tag(m) }
            }
            .pickerStyle(.segmented)
            if dayMode == .specific {
                DatePicker("Fecha", selection: $daySelected, displayedComponents: .date)
            }
        }
    }

    // MARK: - Lista de transacciones
    @State private var editing: Transaction? = nil
    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transacciones").font(.headline)
            if filteredSorted.isEmpty {
                Text("Sin movimientos para este filtro")
                    .font(.footnote).foregroundStyle(subtleForeground)
                    .padding(.vertical, 6)
            } else {
                let rowH: CGFloat = 72
                VStack(spacing: 10) {
                    ForEach(filteredSorted, id: \.id) { tx in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill((tx.amount < 0 ? Color.red : Color(red: 0.0, green: 0.5, blue: 0.2)).opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Text(tx.category.emoji).font(.system(size: 14))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.title)
                                    .font(.callout.weight(.semibold))
                                Text(tx.dateTimeFormatted)
                                    .font(.caption)
                                    .foregroundStyle(subtleForeground)
                            }
                            Spacer()
                            Text(prefs.currencyString(tx.amount))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(tx.amount < 0 ? .red : Color(red: 0.0, green: 0.5, blue: 0.2))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    ZStack {
                                        Capsule(style: .continuous)
                                            .fill((tx.amount < 0 ? Color.red : Color(red: 0.0, green: 0.5, blue: 0.2))
                                                .opacity(prefs.tone == .white ? 0.12 : 0.22))
                                        Capsule(style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.6), (tx.amount < 0 ? Color.red : Color(red: 0.0, green: 0.5, blue: 0.2)).opacity(0.45)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                )
                        }
                        .frame(minHeight: rowH)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(appStroke, lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture { editing = tx }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { editing = tx } label: { Label("Editar", systemImage: "square.and.pencil") }.tint(.blue)
                            Button(role: .destructive) { delete(tx) } label: { Label("Borrar", systemImage: "trash") }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .sheet(item: $editing) { item in
            FinanceEditView(tx: item, onSave: { updated in
                applyEdit(old: item, new: updated)
            }, onDelete: {
                delete(item)
            })
        }
    }

    private var filteredSorted: [Transaction] {
        let cal = Calendar.current
        return finance.transactions.filter { tx in
            switch txFilter {
            case .all: return true
            case .income: return tx.amount > 0
            case .expense: return tx.amount < 0
            }
        }.filter { tx in
            switch dayMode {
            case .all: return true
            case .today: return cal.isDateInToday(tx.date)
            case .specific: return cal.isDate(tx.date, inSameDayAs: daySelected)
            }
        }.sorted(by: { $0.date > $1.date })
    }

    private func delete(_ tx: Transaction) { finance.remove(tx) }

    private func applyEdit(old: Transaction, new: Transaction) {
        guard let idx = finance.transactions.firstIndex(where: { $0.id == old.id }) else { return }
        finance.transactions[idx] = new
        let delta = new.amount - old.amount
        finance.walletBalance += delta
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green.opacity(0.9), .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "banknote")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Finanzas")
                    .font(.title2.weight(.bold))
                Text("Gastos e ingresos")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finanzas: gastos e ingresos")
    }

    // Se eliminó la lista de Transacciones

    // MARK: - Helpers
    // Se eliminó el Resumen (tarjetas, totales y balance)

    // Estilo derivado del tema (ya no usado en secciones removidas, se mantiene por si se reusa)
    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var contentForeground: Color { prefs.tone == .white ? .black : .white }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }

    // Wallet card
    @State private var walletText: String = ""
    private var balanceCard: some View {
        let spentToday = finance.transactions.filter { $0.amount < 0 && Calendar.current.isDateInToday($0.date) }.map { abs($0.amount) }.reduce(0, +)
        let limit = prefs.dailySpendLimit ?? 0
        return VStack(spacing: 12) {
            ZStack(alignment: .top) {
                // Main rounded card
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(appSurface)
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
                // Title and action area
                VStack(spacing: 8) {
                    // (notch removed)
                    HStack {
                        Spacer()
                        Text(balanceMode.title)
                            .font(.title2.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 2)
                    // Content
                    Group {
                        if balanceMode == .total {
                            VStack(spacing: 10) {
                                TextField("0.00", text: Binding(
                                    get: { walletText.isEmpty ? String(format: "%.2f", finance.walletBalance) : walletText },
                                    set: { walletText = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .focused($walletFocused)
                                .submitLabel(.done)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                                Text("Actual: \(prefs.currencyString(finance.walletBalance))")
                                    .font(.footnote).foregroundStyle(subtleForeground)
                            }
                            .padding(.bottom, 16)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Gasto de hoy").font(.headline)
                                    Spacer()
                                    Text(prefs.dailySpendLimit != nil ? "de \(prefs.currencyString(limit))" : "Sin límite")
                                        .foregroundStyle(subtleForeground)
                                }
                                HStack {
                                    Text(prefs.currencyString(spentToday)).font(.title3.weight(.semibold))
                                    Spacer()
                                }
                                if let l = prefs.dailySpendLimit, l > 0 {
                                    ProgressView(value: min(spentToday / l, 1))
                                        .tint(spentToday > l ? .red : .green)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                    // Pager dots indicator at bottom
                    HStack(spacing: 10) {
                        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { balanceMode = .total } } label: {
                            Circle()
                                .fill(balanceMode == .total ? prefs.theme.accent(for: prefs.tone) : Color.secondary.opacity(0.3))
                                .frame(width: 10, height: 10)
                                .contentShape(Circle())
                        }
                        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { balanceMode = .today } } label: {
                            Circle()
                                .fill(balanceMode == .today ? prefs.theme.accent(for: prefs.tone) : Color.secondary.opacity(0.3))
                                .frame(width: 10, height: 10)
                                .contentShape(Circle())
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }
                .padding(.vertical, 6)
            }
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(appStroke, lineWidth: 1))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in dragX = value.translation.width }
                    .onEnded { value in
                        let t: CGFloat = 60
                        if value.translation.width < -t { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { balanceMode = .today } }
                        else if value.translation.width > t { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { balanceMode = .total } }
                        dragX = 0
                    }
            )
        }
        .onAppear { walletText = String(format: "%.2f", finance.walletBalance) }
        .onChange(of: walletFocused) { old, newVal in if newVal == false { commitWallet() } }
    }

    private func commitWallet() {
        let cleaned = walletText.replacingOccurrences(of: ",", with: ".")
        if let v = Double(cleaned) {
            finance.walletBalance = v
            walletFocused = false // cierra el teclado
        }
    }

    // (toggle binding removed in favor of swipe gesture)

    private var limitCard: some View {
        let spentToday = finance.transactions.filter { $0.amount < 0 && Calendar.current.isDateInToday($0.date) }.map { abs($0.amount) }.reduce(0, +)
        let limit = prefs.dailySpendLimit ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Gasto de hoy").font(.headline)
            HStack {
                Text(prefs.currencyString(spentToday))
                Spacer()
                Text(prefs.dailySpendLimit != nil ? "de \(prefs.currencyString(limit))" : "Sin límite")
                    .foregroundStyle(subtleForeground)
            }
            if let l = prefs.dailySpendLimit, l > 0 {
                ProgressView(value: min(spentToday / l, 1))
                    .tint(spentToday > l ? .red : .green)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(appStroke, lineWidth: 1))
    }

    private func checkLimit() {
        guard let l = prefs.dailySpendLimit, l > 0 else { return }
        let spent = finance.transactions.filter { $0.amount < 0 && Calendar.current.isDateInToday($0.date) }.map { abs($0.amount) }.reduce(0, +)
        showLimitAlert = spent > l
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Resumen por \(selectedPeriod.title)").font(.headline)
                Spacer()
                Picker("Periodo", selection: $selectedPeriod) {
                    ForEach(Period.allCases) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            let data = aggregatesSplit(for: selectedPeriod)
            if data.isEmpty {
                Text("Sin datos").font(.footnote).foregroundStyle(subtleForeground)
            } else {
                let maxVal = max(max(data.map { $0.income }.max() ?? 1, 1), max(data.map { abs($0.expense) }.max() ?? 1, 1))
                VStack(spacing: 10) {
                    ForEach(data, id: \.label) { item in
                        VStack(spacing: 4) {
                            HStack {
                                Text(item.label).font(.caption)
                                Spacer()
                                Text("+\(prefs.currencyString(item.income))  -\(prefs.currencyString(abs(item.expense)))")
                                    .font(.caption)
                                    .foregroundStyle(subtleForeground)
                            }
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: CGFloat(item.income / maxVal) * 200, height: 8)
                                Spacer()
                            }
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: CGFloat(abs(item.expense) / maxVal) * 200, height: 8)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                let topIncome = data.max(by: { $0.income < $1.income })
                let topExpense = data.max(by: { abs($0.expense) < abs($1.expense) })
                if let ti = topIncome { Text("Mayor ingreso: \(ti.label) → \(prefs.currencyString(ti.income))").font(.footnote).foregroundStyle(subtleForeground) }
                if let te = topExpense { Text("Mayor gasto: \(te.label) → \(prefs.currencyString(abs(te.expense)))").font(.footnote).foregroundStyle(subtleForeground) }
            }
        }
    }

    private func aggregatesSplit(for period: Period) -> [(label: String, income: Double, expense: Double)] {
        let cal = Calendar.current
        let txs = finance.transactions
        switch period {
        case .day:
            let groups = Dictionary(grouping: txs) { cal.startOfDay(for: $0.date) }
            return groups.keys.sorted().map { d in
                let inc = groups[d]!.filter { $0.amount > 0 }.map { $0.amount }.reduce(0, +)
                let exp = groups[d]!.filter { $0.amount < 0 }.map { $0.amount }.reduce(0, +)
                return (label: dateLabel(d, format: "d/M"), income: inc, expense: exp)
            }
        case .week:
            let groups = Dictionary(grouping: txs) { (tx: Transaction) -> Date in
                let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: tx.date)
                return cal.date(from: comps) ?? cal.startOfDay(for: tx.date)
            }
            return groups.keys.sorted().map { d in
                let inc = groups[d]!.filter { $0.amount > 0 }.map { $0.amount }.reduce(0, +)
                let exp = groups[d]!.filter { $0.amount < 0 }.map { $0.amount }.reduce(0, +)
                return (label: dateLabel(d, format: "w/YY"), income: inc, expense: exp)
            }
        case .month:
            let groups = Dictionary(grouping: txs) { (tx: Transaction) -> Date in
                let comps = cal.dateComponents([.year, .month], from: tx.date)
                return cal.date(from: comps) ?? cal.startOfDay(for: tx.date)
            }
            return groups.keys.sorted().map { d in
                let inc = groups[d]!.filter { $0.amount > 0 }.map { $0.amount }.reduce(0, +)
                let exp = groups[d]!.filter { $0.amount < 0 }.map { $0.amount }.reduce(0, +)
                return (label: dateLabel(d, format: "MMM YY"), income: inc, expense: exp)
            }
        }
    }

    private func dateLabel(_ d: Date, format: String) -> String {
        let df = DateFormatter(); df.locale = Locale.current; df.dateFormat = format; return df.string(from: d)
    }
}

// MARK: - Editor de transacción
struct FinanceEditView: View {
    let tx: Transaction
    let onSave: (Transaction) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var category: FinanceCategory = .other
    @State private var isIncome: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Movimiento")) {
                    TextField("Título", text: $title)
                    TextField("Monto", text: $amountText).keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Categoría", selection: $category) {
                        ForEach(FinanceCategory.allCases) { c in Text("\(c.emoji) \(c.title)").tag(c) }
                    }
                }
                Section(header: Text("Tipo")) {
                    Toggle(isOn: $isIncome) {
                        Label(isIncome ? "Ingreso" : "Gasto", systemImage: isIncome ? "arrow.down" : "arrow.up")
                            .foregroundStyle(isIncome ? Color.green : Color.red)
                    }
                    .tint(isIncome ? .green : .red)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Editar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(!canSave) }
                ToolbarItem(placement: .destructiveAction) { Button("Borrar", role: .destructive) { onDelete(); dismiss() } }
            }
        }
        .onAppear {
            title = tx.title
            amountText = String(format: "%.2f", abs(tx.amount))
            date = tx.date
            category = tx.category
            isIncome = tx.amount >= 0
        }
    }

    private var canSave: Bool { Double(amountText.replacingOccurrences(of: ",", with: ".")) != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func save() {
        guard let v = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
        let signed = isIncome ? v : -v
        let updated = Transaction(id: tx.id, title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: signed, date: date, category: category)
        onSave(updated)
        dismiss()
    }
}

// MARK: - Reports (Pie / Bar) Popover
private struct FinanceReportsView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var finance: FinanceStore

    enum ChartKind: String, CaseIterable, Identifiable { case pie, bars; var id: String { rawValue }; var title: String { self == .pie ? "Pastel" : "Barras" } }

    @State private var chartKind: ChartKind = .pie
    @State private var monthStart: Date = Calendar.current.startOfMonth(for: Date())
    @Namespace private var anim

    var body: some View {
        let summary = monthSummary(for: monthStart)
        let income = summary.income
        let expense = abs(summary.expense)
        VStack(spacing: 14) {
            // Header with month switcher
            HStack(spacing: 8) {
                Button { monthStart = Calendar.current.date(byAdding: .month, value: -1, to: monthStart).map { Calendar.current.startOfMonth(for: $0) } ?? monthStart } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthTitle(monthStart))
                    .font(.system(.title3, design: .serif).weight(.black))
                Spacer()
                Button { monthStart = Calendar.current.date(byAdding: .month, value: 1, to: monthStart).map { Calendar.current.startOfMonth(for: $0) } ?? monthStart } label: { Image(systemName: "chevron.right") }
            }
            .padding(.bottom, 4)

            Picker("Tipo", selection: $chartKind) {
                ForEach(ChartKind.allCases) { k in Text(k.title).tag(k) }
            }
            .pickerStyle(.segmented)

            ZStack {
                if chartKind == .pie {
                    DonutChart(income: income, expense: expense)
                        .matchedGeometryEffect(id: "chart", in: anim)
                        .frame(height: 240)
                        .padding(.vertical, 8)
                } else {
                    BarsChart(income: income, expense: expense)
                        .matchedGeometryEffect(id: "chart", in: anim)
                        .frame(height: 240)
                        .padding(.vertical, 8)
                }
            }

            // Legend and numbers
            HStack(spacing: 14) {
                legendItem(color: .green, title: "Ingresos", value: prefs.currencyString(income))
                legendItem(color: .red, title: "Gastos", value: prefs.currencyString(expense))
            }
            .font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(prefs.theme.surface(for: prefs.tone))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(prefs.theme.stroke(for: prefs.tone), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: chartKind)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: monthStart)
    }

    // MARK: - Data helpers
    private func monthSummary(for start: Date) -> (income: Double, expense: Double) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: start)
        let ms = cal.date(from: comps) ?? start
        let me = cal.date(byAdding: DateComponents(month: 1, day: -1), to: ms) ?? ms
        let tx = finance.transactions.filter { cal.component(.year, from: $0.date) == cal.component(.year, from: ms) && cal.component(.month, from: $0.date) == cal.component(.month, from: ms) }
        let inc = tx.filter { $0.amount > 0 }.map { $0.amount }.reduce(0, +)
        let exp = tx.filter { $0.amount < 0 }.map { $0.amount }.reduce(0, +)
        _ = me // not used further; kept for clarity
        return (inc, exp)
    }

    private func monthTitle(_ d: Date) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "LLLL yyyy"; let s = df.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func legendItem(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(prefs.tone == .white ? 0.25 : 0.35)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Donut/Pie Chart
private struct DonutChart: View {
    let income: Double
    let expense: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        let total = max(0.0001, income + abs(expense))
        let incRatio = CGFloat(income / total)
        let expRatio = CGFloat(abs(expense) / total)
        ZStack {
            // Fondo donut
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 18)
            // Ingresos
            Circle()
                .trim(from: 0, to: min(progress, incRatio))
                .stroke(LinearGradient(colors: [.green.opacity(0.9), .green], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // Gastos
            Circle()
                .trim(from: 0, to: min(max(0, progress - incRatio), expRatio))
                .stroke(LinearGradient(colors: [.red.opacity(0.9), .red], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90 + Double(incRatio) * 360))
            // Labels en centro
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Circle().fill(Color.green.opacity(0.3)).frame(width: 10, height: 10)
                    Text(String(format: "%.0f%%", incRatio * 100)).font(.title3.weight(.bold))
                }
                HStack(spacing: 12) {
                    Circle().fill(Color.red.opacity(0.3)).frame(width: 10, height: 10)
                    Text(String(format: "%.0f%%", expRatio * 100)).font(.title3.weight(.bold))
                }
            }
        }
        .padding(20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { progress = incRatio + expRatio }
        }
        .transition(.scale)
    }
}

private struct PieSliceShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(center: center, radius: r, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Bars Chart
private struct BarsChart: View {
    let income: Double
    let expense: Double
    @State private var anim: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            let maxVal = max(1, income, abs(expense))
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                // línea base
                Rectangle().fill(Color.secondary.opacity(0.12)).frame(height: 1).offset(y: -8)
                HStack(spacing: 32) {
                    VStack(spacing: 6) {
                        Text(String(format: "%.0f%%", (income / maxVal) * 100)).font(.caption2).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.green.opacity(0.9), .green], startPoint: .top, endPoint: .bottom))
                            .frame(width: 38, height: anim * CGFloat(income / maxVal) * (h - 40))
                    }
                    VStack(spacing: 6) {
                        Text(String(format: "%.0f%%", (abs(expense) / maxVal) * 100)).font(.caption2).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.red.opacity(0.9), .red], startPoint: .top, endPoint: .bottom))
                            .frame(width: 38, height: anim * CGFloat(abs(expense) / maxVal) * (h - 40))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { anim = 1 } }
        .transition(.opacity.combined(with: .scale))
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let c = dateComponents([.year, .month], from: date)
        return self.date(from: c) ?? date
    }
}
