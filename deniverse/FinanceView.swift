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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            balanceCard
            quickActions
            filter
            transactionsList
            chartSection
        }
        .appItalic(prefs.useItalic)
        .appFontDesign(prefs.fontDesign)
        .onReceive(finance.$transactions) { _ in checkLimit() }
        .onAppear { checkLimit() }
        .alert("Límite diario excedido", isPresented: $showLimitAlert, actions: {
            Button("Entendido", role: .cancel) {}
        }, message: {
            Text("Has superado tu límite diario de gasto.")
        })
    }

    // MARK: - Partes

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas").font(.headline)
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

    // MARK: - Lista de transacciones
    @State private var editing: Transaction? = nil
    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transacciones").font(.headline)
            if filtered.isEmpty {
                Text("Sin movimientos para este filtro")
                    .font(.footnote).foregroundStyle(subtleForeground)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(filtered, id: \.id) { tx in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((tx.amount < 0 ? Color.red : Color.green).opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Text(tx.category.emoji).font(.system(size: 16))
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
                                .foregroundStyle(tx.amount < 0 ? .red : .green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(appSurface))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(appStroke, lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture { editing = tx }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { editing = tx } label: { Label("Editar", systemImage: "square.and.pencil") }.tint(.blue)
                            Button(role: .destructive) { delete(tx) } label: { Label("Borrar", systemImage: "trash") }
                        }
                    }
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

    private var filtered: [Transaction] {
        finance.transactions.filter { tx in
            switch txFilter {
            case .all: return true
            case .income: return tx.amount > 0
            case .expense: return tx.amount < 0
            }
        }
    }

    private func delete(_ tx: Transaction) {
        if let idx = finance.transactions.firstIndex(where: { $0.id == tx.id }) {
            finance.transactions.remove(at: idx)
            finance.walletBalance -= tx.amount // revert effect en saldo
        }
    }

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
                                Text("Actual: \(currencyString(finance.walletBalance))")
                                    .font(.footnote).foregroundStyle(subtleForeground)
                            }
                            .padding(.bottom, 16)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Gasto de hoy").font(.headline)
                                    Spacer()
                                    Text(prefs.dailySpendLimit != nil ? "de \(currencyString(limit))" : "Sin límite")
                                        .foregroundStyle(subtleForeground)
                                }
                                HStack {
                                    Text(currencyString(spentToday)).font(.title3.weight(.semibold))
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
                Text(currencyString(spentToday))
                Spacer()
                Text(prefs.dailySpendLimit != nil ? "de \(currencyString(limit))" : "Sin límite")
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
                                Text("+\(currencyString(item.income))  -\(currencyString(abs(item.expense)))")
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
                if let ti = topIncome { Text("Mayor ingreso: \(ti.label) → \(currencyString(ti.income))").font(.footnote).foregroundStyle(subtleForeground) }
                if let te = topExpense { Text("Mayor gasto: \(te.label) → \(currencyString(abs(te.expense)))").font(.footnote).foregroundStyle(subtleForeground) }
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
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
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
