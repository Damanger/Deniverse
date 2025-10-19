import SwiftUI
import PencilKit
import UserNotifications
import UniformTypeIdentifiers

enum AgendaMode { case month, week }

struct AgendaView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var selectedDate: Date = .now
    @State private var mode: AgendaMode = .month
    @EnvironmentObject private var agenda: AgendaStore
    @State private var editor: DaySelection?
    @State private var hourPicker: DaySelection? = nil
    @State private var pendingNoteDate: Date? = nil
    // Notas integradas
    @State private var searchText: String = ""
    @State private var showTextEditor: Bool = false
    @State private var editingNote: NoteItem? = nil
    @State private var showCycleAlert: Bool = false
    @State private var cycleAlertDate: Date = Date()

    // Quick actions hooks
    let onIncome: () -> Void
    let onExpense: () -> Void

    init(onIncome: @escaping () -> Void = {}, onExpense: @escaping () -> Void = {}) {
        self.onIncome = onIncome
        self.onExpense = onExpense
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            agendaSearchBar
            agendaQuickActions
            Group {
                VStack(alignment: .leading, spacing: 10) {
                    switch mode {
                    case .month:
                        VerticalMonthsCalendarView(focusDate: $selectedDate, selected: $selectedDate, onDayTap: { d in
                            let cal = Calendar.current
                            if cal.isDate(d, inSameDayAs: selectedDate) {
                                // Segundo tap en el mismo día → abrir horas del día
                                hourPicker = DaySelection(date: d)
                            } else {
                                // Primer tap → seleccionar
                                selectedDate = d
                            }
                        })
                        .environmentObject(prefs)
                        .environmentObject(agenda)
                        .frame(height: 640)
                    case .week:
                        WeeklyPlannerView(
                            date: $selectedDate,
                            drawingFor: { date in
                                if let data = agenda.entry(for: date)?.drawingData, let d = try? PKDrawing(data: data) { return d }
                                return nil
                            },
                            onDayTap: { d in
                                // Selecciona el día para que "+Nuevo" use esa fecha
                                selectedDate = d
                            }
                        )
                        .environmentObject(prefs)
                    }
                    if prefs.isWoman { cycleLegend }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appStroke, lineWidth: 1))

            // Notas del día: solo en vista mensual para evitar duplicar en semanal
            if mode == .month {
                dayNotesSection
            }
        }
        .sheet(item: $editor) { sel in
            DayDrawingEditor(
                date: sel.date,
                initial: agenda.entry(for: sel.date)?.drawingData.flatMap { try? PKDrawing(data: $0) },
                onSave: { drawing in
                    let data = drawing.dataRepresentation()
                    agenda.update(date: sel.date, text: nil, drawingData: data)
                },
                onDelete: {
                    agenda.update(date: sel.date, text: nil, drawingData: nil)
                }
            )
        }
        // Horas del día (popover/sheet) para la vista semanal
        .sheet(item: $hourPicker) { sel in
            DayHoursSheet(date: sel.date)
                .environmentObject(prefs)
                .environmentObject(agenda)
        }
        // Editor de notas (integrado)
        .sheet(isPresented: $showTextEditor) {
            if let n = editingNote {
                AgendaTextNoteEditor(
                    date: selectedDate,
                    initialText: n.text,
                    initialReminder: n.reminder,
                    initialCategory: n.category,
                    initialDate: (pendingNoteDate ?? selectedDate),
                    allowDateChange: false,
                    onSave: { noteDay, text, category, notify, when in
                        let reminder = notify ? (when ?? noteDay) : nil
                        agenda.updateNote(on: noteDay, id: n.id, text: text, category: category, reminder: reminder)
                        if let r = reminder { scheduleNotification(at: r, title: "Nota", body: text) }
                    },
                    onDelete: {
                        agenda.deleteNote(on: selectedDate, id: n.id)
                    }
                )
                .environmentObject(prefs)
            } else {
                AgendaTextNoteEditor(
                    date: selectedDate,
                    initialDate: (pendingNoteDate ?? selectedDate),
                    allowDateChange: true,
                    onSave: { noteDay, text, category, notify, when in
                        let reminder = notify ? (when ?? noteDay) : nil
                        agenda.addNote(on: noteDay, text: text, category: category, reminder: reminder)
                        if let r = reminder { scheduleNotification(at: r, title: "Nota", body: text) }
                        selectedDate = noteDay
                    },
                    onDelete: {}
                )
                .environmentObject(prefs)
            }
        }
        // Alerta de inicio de ciclo
        .alert("Iniciar ciclo", isPresented: $showCycleAlert) {
            Button("Retraso") {
                agenda.setPeriodDelay(on: cycleAlertDate, delayed: true)
                prefs.lastCycleAlertDayKey = dayKey(cycleAlertDate)
            }
            Button("Confirmar") {
                prefs.lastPeriodStart = cycleAlertDate
                prefs.lastCycleAlertDayKey = dayKey(cycleAlertDate)
                agenda.setPeriodDelay(on: cycleAlertDate, delayed: false)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Quieres marcar hoy como inicio de ciclo?")
        }
        .onAppear { checkCycleStartForToday() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.9), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Agenda")
                    .font(.system(.title2, design: .serif).weight(.bold)).appItalic(prefs.useItalic)
                Text("Próximos eventos y recordatorios")
                    .font(.system(.footnote, design: .serif)).appItalic(prefs.useItalic)
                    .foregroundStyle(subtleForeground)
            }
            Spacer()
            // Toggle estilo Ajustes para cambiar Mes/Semana
            HStack(spacing: 8) {
                Text("Semana")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
                Toggle("Semana", isOn: weekToggle)
                    .labelsHidden()
                    .tint(prefs.theme.accent(for: prefs.tone))
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Agenda: próximos eventos y recordatorios")
    }

    // Replaced placeholder with large graphical calendar

    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }

    private var modeToggle: some View { EmptyView() }

    private var weekToggle: Binding<Bool> {
        Binding(get: { mode == .week }, set: { mode = $0 ? .week : .month })
    }

    private func key(for date: Date) -> String { agenda.key(for: date) }
}

// MARK: - Search + Quick Actions + Day Notes

private extension AgendaView {
    var agendaSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(subtleForeground)
            TextField("Buscar en notas del día...", text: $searchText)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled(true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appStroke, lineWidth: 1))
        .overlay(alignment: .trailing) {
            if !searchText.isEmpty {
                Button { withAnimation(.easeOut(duration: 0.15)) { searchText = "" } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(subtleForeground)
                }
                .padding(.trailing, 10)
                .accessibilityLabel("Limpiar búsqueda")
            }
        }
    }

    var agendaQuickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas").font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Nuevo", systemImage: "plus", tint: .orange, action: { newNote() }, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: onIncome, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: onExpense, useWhiteBackground: true)
            }
        }
    }

    // Leyenda de ciclo (periodo y fértil)
    var cycleLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").foregroundStyle(.red)
                Text("Periodo")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
            }
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("Ventana fértil")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
            }
        }
        .padding(.top, 6)
    }

    var dayNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let items = agenda.notes(for: selectedDate).filter { n in
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return q.isEmpty || n.text.lowercased().contains(q)
            }
            if !items.isEmpty { Text("Notas del día").font(.headline) }
            ForEach(items) { n in
                HStack(alignment: .top, spacing: 10) {
                    Label(n.category.displayName, systemImage: "folder")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(subtleForeground)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(n.text).font(.subheadline).lineLimit(3)
                        HStack(spacing: 6) {
                            if let r = n.reminder {
                                Image(systemName: "bell.fill").foregroundStyle(.yellow)
                                Text(shortDate(r)).font(.caption).foregroundStyle(subtleForeground)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button { editingNote = n; showTextEditor = true } label: { Image(systemName: "square.and.pencil") }
                        .buttonStyle(.plain)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(appSurface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(appStroke, lineWidth: 1))
            }
            if items.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("Sin notas para este día")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(appSurface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(appStroke, lineWidth: 1))
            }
        }
    }

    // Actions
    func newNote() {
        let cal = Calendar.current
        pendingNoteDate = cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        editingNote = nil
        showTextEditor = true
    }

    // Local notification (copied from NotesView)
    func scheduleNotification(at date: Date, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let triggerDate = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    func shortDate(_ d: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; return df.string(from: d)
    }
    
    // Normaliza a mediodía para evitar problemas de DST al comparar días
    func midday(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    // Checa si hoy es inicio esperado de ciclo y muestra alerta 1 vez
    func checkCycleStartForToday() {
        guard prefs.isWoman else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let key = dayKey(today)
        if prefs.lastCycleAlertDayKey == key { return }
        let start = cal.startOfDay(for: prefs.lastPeriodStart)
        let diff = cal.dateComponents([.day], from: start, to: today).day ?? 0
        if diff < 0 { return }
        let cycle = max(1, prefs.cycleLength)
        let cycles = diff / cycle
        guard let expected = cal.date(byAdding: .day, value: cycles * cycle, to: start) else { return }
        if cal.isDate(expected, inSameDayAs: today) {
            cycleAlertDate = today
            showCycleAlert = true
        }
    }

    func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Large Month Grid Calendar

private struct MonthCalendarView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Binding var date: Date
    var onDayTap: (Date) -> Void

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_ES")
        cal.firstWeekday = 1 // Sunday-first
        return cal
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: date)!
    }

    private var daysInMonth: Int {
        calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day!
    }

    private var startWeekdayOffset: Int {
        // 0-based offset from Monday
        let wd = calendar.component(.weekday, from: monthInterval.start)
        // Convert to Monday=1..Sunday=7, then offset-1
        let mondayBased = (wd - calendar.firstWeekday + 7) % 7 + 1
        return mondayBased - 1
    }

    private var totalCells: Int {
        let raw = startWeekdayOffset + daysInMonth
        return Int(ceil(Double(raw) / 7.0) * 7)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var weekdayHeaders: [String] { ["D", "L", "M", "M", "J", "V", "S"] }

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation header
            HStack(alignment: .center) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        date = calendar.date(byAdding: .month, value: -1, to: date) ?? date
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: .serif)).appItalic(prefs.useItalic)
                }
                Spacer()
                Text(monthTitle(for: date))
                    .font(.system(.headline, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        date = calendar.date(byAdding: .month, value: 1, to: date) ?? date
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold, design: .serif)).appItalic(prefs.useItalic)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            // Weekday header row
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdayHeaders.indices, id: \.self) { i in
                    let isWeekend = (i == 0 || i == 6)
                    Text(weekdayHeaders[i])
                        .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(prefs.tone == .dark ? Color.white : Color.black)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill((isWeekend ? Color.green : Color.blue).opacity(0.22))
                        )
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                }
            }
            .padding(.bottom, 4)

            // Day cells grid
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0 ..< totalCells, id: \.self) { idx in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 80)
                            .overlay(Rectangle().strokeBorder(appStroke, lineWidth: 1))

                        // Dot decoration similar to reference
                        if let comp = dayComponents(forCell: idx) {
                            let isWeekend = isWeekendDay(comp)
                            let isToday = isToday(comp)
                            // Today ring behind number
                            if isToday {
                                Circle()
                                    .stroke(prefs.theme.accent(for: prefs.tone), lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                                    .padding(.top, 4)
                                    .padding(.leading, 4)
                            }
                            // Day number
                            if let dayNum = comp.day {
                                Text(String(dayNum))
                                    .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                                    .foregroundStyle(prefs.tone == .dark ? Color.white : Color.black)
                                    .padding(.top, 6)
                                    .padding(.leading, 6)
                            }
                            // Thumbnail preview if we have a drawing
                            if let d = thumbnail(for: comp) {
                                d
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .opacity(0.9)
                                    .padding(.top, 28)
                                    .padding(.leading, 8)
                            } else {
                                Circle()
                                    .fill(isWeekend ? Color.green.opacity(0.6) : Color.blue.opacity(0.6))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 28)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let comp = dayComponents(forCell: idx), let d = calendar.date(from: comp) {
                            onDayTap(d)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func dayComponents(forCell idx: Int) -> DateComponents? {
        let day = idx - startWeekdayOffset + 1
        guard day >= 1 && day <= daysInMonth else { return nil }
        var dc = calendar.dateComponents([.year, .month], from: monthInterval.start)
        dc.day = day
        return dc
    }

    private func isWeekendDay(_ comps: DateComponents) -> Bool {
        guard let d = calendar.date(from: comps) else { return false }
        return calendar.isDateInWeekend(d)
    }

    private func isToday(_ comps: DateComponents) -> Bool {
        guard let d = calendar.date(from: comps) else { return false }
        return calendar.isDateInToday(d)
    }

    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }

    // Month title formatter
    private func monthTitle(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.calendar = calendar
        df.dateFormat = "LLLL yyyy"
        let s = df.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
    // Generate a small thumbnail image for a drawing if present
    private func thumbnail(for comps: DateComponents) -> Image? {
        guard let d = calendar.date(from: comps), let data = agenda.entry(for: d)?.drawingData, let drawing = try? PKDrawing(data: data) else { return nil }
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 64, height: 64) : drawing.bounds.insetBy(dx: -8, dy: -8)
        let ui = drawing.image(from: bounds, scale: 2)
        return Image(uiImage: ui)
    }

    private func hasText(for comps: DateComponents) -> Bool {
        guard let d = calendar.date(from: comps) else { return false }
        return (agenda.entry(for: d)?.text?.isEmpty == false)
    }

    private func textFor(_ comps: DateComponents) -> String? {
        guard let d = calendar.date(from: comps), let t = agenda.entry(for: d)?.text else { return nil }
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Vertical Multi-Month Calendar (Apple-like)

private struct VerticalMonthsCalendarView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Binding var focusDate: Date
    @Binding var selected: Date
    var onDayTap: (Date) -> Void

    @State private var months: [Date] = [] // month start dates
    @State private var currentMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var showYearPicker = false
    @State private var yearAnchor: Date = Calendar.current.startOfMonth(for: .now)
    private var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
    @State private var didInitialPosition: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { m in
                        Section(header: MonthPinnedHeader(monthStart: m, onYearTap: {
                            yearAnchor = m
                            showYearPicker = true
                        }, onToday: {
                            goToToday(proxy: proxy)
                        })) {
                            MonthGridSection(monthStart: m, selected: $selected, onDayTap: onDayTap)
                        }
                        .id(monthID(m))
                        .onAppear {
                            // Extiende meses en app real con límites de seguridad
                            guard !isPreview, didInitialPosition else { return }
                            if months.count < 180 {
                                if m == months.first { prependMonths(count: 12, anchor: m, proxy: proxy) }
                                if m == months.last { appendMonths(count: 12) }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .onAppear {
                ensureVisible(date: focusDate, proxy: proxy, animated: false)
                // Marca que ya centramos al mes actual; evita que el primer onAppear del primer mes
                // dispare expansión hacia el pasado antes de posicionar el scroll.
                DispatchQueue.main.async { didInitialPosition = true }
            }
            .onChange(of: focusDate) { _, newVal in ensureVisible(date: newVal, proxy: proxy, animated: true) }
            .sheet(isPresented: $showYearPicker) {
                YearOverviewView(initialYear: Calendar.current.component(.year, from: yearAnchor), selectedMonth: yearAnchor) { picked in
                    let m = Calendar.current.startOfMonth(for: picked)
                    focusDate = m
                    currentMonth = m
                    months = generateMonths(around: m)
                    // Scroll will occur via onChange(focusDate)
                    showYearPicker = false
                }
                .environmentObject(prefs)
                .interactiveDismissDisabled(true)
            }
        }
    }

    // MARK: - Helpers
    private func generateMonths(around center: Date) -> [Date] {
        let cal = Calendar.current
        let base = cal.startOfMonth(for: center)
        // Ventana inicial: Preview ±2, App ±6 (se expande al desplazarse)
        let range = isPreview ? (-2...2) : (-6...6)
        return range.compactMap { cal.date(byAdding: .month, value: $0, to: base) }.map { cal.startOfMonth(for: $0) }
    }

    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "LLLL"; let s = df.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func monthID(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private func yearString(for date: Date) -> String { String(Calendar.current.component(.year, from: date)) }

    private func nearestIndexToCurrent() -> Int? { months.firstIndex(of: currentMonth) }

    private func goToToday(proxy: ScrollViewProxy) {
        let today = midday(Date())
        focusDate = today
        selected = today
        ensureVisible(date: today, proxy: proxy, animated: true)
    }

    private func ensureVisible(date: Date, proxy: ScrollViewProxy, animated: Bool) {
        let norm = midday(date)
        let target = Calendar.current.startOfMonth(for: norm)
        currentMonth = target
        if !months.contains(target) { months = generateMonths(around: target) }
        let action = { proxy.scrollTo(monthID(target), anchor: .top) }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { action() }
        } else {
            action()
        }
        // En la siguiente vuelta de runloop, repite el scroll por si el layout cambió
        DispatchQueue.main.async {
            if animated {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { action() }
            } else { action() }
        }
    }

    private func midday(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private func prependMonths(count: Int, anchor: Date, proxy: ScrollViewProxy) {
        guard let first = months.first else { return }
        let cal = Calendar.current
        let adds = (1...count).compactMap { cal.date(byAdding: .month, value: -$0, to: first) }.map { cal.startOfMonth(for: $0) }.reversed()
        var newOnes: [Date] = []
        for m in adds where !months.contains(m) { newOnes.append(m) }
        guard !newOnes.isEmpty else { return }
        let anchorID = monthID(anchor)
        months.insert(contentsOf: newOnes, at: 0)
        // Keep visual position by scrolling back to the same anchor month
        DispatchQueue.main.async { proxy.scrollTo(anchorID, anchor: .top) }
    }

    private func appendMonths(count: Int) {
        guard let last = months.last else { return }
        let cal = Calendar.current
        let adds = (1...count).compactMap { cal.date(byAdding: .month, value: $0, to: last) }.map { cal.startOfMonth(for: $0) }
        for m in adds where !months.contains(m) { months.append(m) }
    }
}

// Sticky header for each month section
private struct MonthPinnedHeader: View {
    @EnvironmentObject private var prefs: PreferencesStore
    let monthStart: Date
    let onYearTap: () -> Void
    let onToday: () -> Void
    private var year: String { String(Calendar.current.component(.year, from: monthStart)) }
    private var monthName: String {
        // Abreviaturas fijas sin punto: Ene, Feb, Mar, Abr, May, Jun, Jul, Ago, Sep, Oct, Nov, Dic
        let abbr = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
        let m = Calendar.current.component(.month, from: monthStart)
        let idx = max(1, min(12, m)) - 1
        return abbr[idx]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Clear background so el card mantiene su color y contraste
            Color.clear
            HStack(spacing: 10) {
                Button(action: onYearTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(year)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(prefs.tone == .dark ? Color.black : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(prefs.theme.accent(for: prefs.tone))
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
                Text(monthName)
                    .font(.system(size: 34, weight: .black, design: .serif)).appItalic(prefs.useItalic)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.vertical, 2)
                Spacer()
                Button(action: onToday) {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                        Text("Hoy")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(prefs.tone == .dark ? Color.black : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(prefs.theme.accent(for: prefs.tone)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// One month section with large day cells + indicators
private struct MonthGridSection: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    let monthStart: Date
    @Binding var selected: Date
    var onDayTap: (Date) -> Void

    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.locale = Locale(identifier: "es_ES"); c.firstWeekday = 1; return c }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }

    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: monthStart)!.count }
    private var startWeekdayOffset: Int {
        let w = calendar.component(.weekday, from: monthStart)
        return (w - calendar.firstWeekday + 7) % 7
    }
    private var totalCells: Int { let rows = Int(ceil(Double(startWeekdayOffset + daysInMonth) / 7.0)); return rows * 7 }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Weekday initials
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdayHeaders.indices, id: \.self) { i in
                    Text(weekdayHeaders[i])
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(.primary)
                        .background(
                            Capsule(style: .continuous)
                                .fill(weekdayBG(i))
                                .padding(.horizontal, 10)
                        )
                }
            }

            // Day cells grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<totalCells, id: \.self) { idx in
                    if let date = dateForCell(idx) {
                        DayCell(date: date, isInMonth: true, onTap: { onDayTap(date) })
                    } else {
                        DayCell(date: nil, isInMonth: false, onTap: {})
                    }
                }
            }
        }
    }

    private var weekdayHeaders: [String] { ["D", "L", "M", "M", "J", "V", "S"] }
    private func weekdayBG(_ index: Int) -> Color {
        // Subtle unique tint per weekday
        let palette: [Color] = [.red, .cyan, .teal, .indigo, .orange, .green, .blue]
        let base = palette[index % palette.count]
        return base.opacity(prefs.tone == .dark ? 0.22 : 0.15)
    }

    private func dateForCell(_ idx: Int) -> Date? {
        let day = idx - startWeekdayOffset + 1
        guard day >= 1 && day <= daysInMonth else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    // Day cell view
    @ViewBuilder
    private func DayCell(date: Date?, isInMonth: Bool, onTap: @escaping () -> Void) -> some View {
        let height: CGFloat = 98
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
            if let d = date, isInMonth {
                let isToday = Calendar.current.isDateInToday(d)
                let isSelected = Calendar.current.isDate(d, inSameDayAs: selected)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(prefs.theme.accent(for: prefs.tone))
                                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                            } else if isSelected {
                                Circle()
                                    .stroke(prefs.theme.accent(for: prefs.tone), lineWidth: 2)
                            }
                            Text(String(Calendar.current.component(.day, from: d)))
                                .font(.system(.subheadline, design: .serif).weight(isToday ? .heavy : .semibold)).appItalic(prefs.useItalic)
                                .foregroundStyle(isToday ? Color.white : (prefs.tone == .dark ? .white : .black))
                        }
                        .frame(width: 30, height: 30)
                        Spacer(minLength: 0)
                    }
                    // Cycle tracking markers (period / fertile)
                    if prefs.isWoman {
                        if isPeriodDate(d) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        } else if isFertileDate(d) {
                            Circle()
                                .fill(Color.green.opacity(0.9))
                                .frame(width: 7, height: 7)
                                .padding(.leading, 6)
                        } else if agenda.isPeriodDelayed(on: d) {
                            Text("🕒").font(.system(size: 11)).padding(.leading, 4)
                        }
                    }
                    // Notes/text chips
                    chips(for: d)
                        .padding(.trailing, 4)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture { if isInMonth { onTap() } }
    }

    // Indicators
    @ViewBuilder
    private func chips(for date: Date) -> some View {
        let notes = agenda.notes(for: date)
        let dayText = agenda.entry(for: date)?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let showText = !dayText.isEmpty
        let limit = 3
        VStack(alignment: .leading, spacing: 2) {
            if showText {
                pill(icon: "doc.text", text: String(dayText.prefix(12)), color: .teal)
            }
            ForEach(Array(notes.prefix(limit)).indices, id: \.self) { i in
                let n = notes[i]
                pill(icon: icon(for: n.category), text: String(n.category.displayName.prefix(10)), color: color(for: n.category))
            }
            if (notes.count + (showText ? 1 : 0)) == 0 {
                // If no content at all but hourly or drawing exists, show a small hint dot row
                if hasDrawing(date) || hasHourly(date) {
                    HStack(spacing: 4) {
                        if hasDrawing(date) { Circle().fill(Color.purple.opacity(0.7)).frame(width: 6, height: 6) }
                        if hasHourly(date) { Circle().fill(Color.orange.opacity(0.7)).frame(width: 6, height: 6) }
                    }
                }
            }
        }
    }

    private func pill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(color.opacity(prefs.tone == .dark ? 0.22 : 0.16)))
        .overlay(Capsule(style: .continuous).stroke(appStroke, lineWidth: 0.8))
        .foregroundStyle(prefs.tone == .dark ? Color.white : Color.black)
    }

    private func color(for category: NoteCategory) -> Color {
        switch category {
        case .personal: return .purple
        case .work: return .blue
        case .finance: return .green
        case .health: return .red
        case .other: return .gray
        }
    }
    private func icon(for category: NoteCategory) -> String {
        switch category {
        case .personal: return "person"
        case .work: return "briefcase"
        case .finance: return "banknote"
        case .health: return "heart.fill"
        case .other: return "tag"
        }
    }
    private func hasAnyContent(on d: Date) -> Bool {
        if let e = agenda.entry(for: d) { if let t = e.text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }; if let n = e.notes, !n.isEmpty { return true }; if e.drawingData != nil { return true }; if let h = e.hourly, !h.isEmpty { return true } }
        return false
    }
    private func hasDrawing(_ d: Date) -> Bool { agenda.entry(for: d)?.drawingData != nil }
    private func hasHourly(_ d: Date) -> Bool { (agenda.entry(for: d)?.hourly?.isEmpty == false) }

    // MARK: - Cycle helpers (period / fertile)
    private func isPeriodDate(_ d: Date) -> Bool {
        guard prefs.isWoman else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: prefs.lastPeriodStart)
        let day = cal.startOfDay(for: d)
        let diff = cal.dateComponents([.day], from: start, to: day).day ?? 0
        let cycle = max(1, prefs.cycleLength)
        let mod = ((diff % cycle) + cycle) % cycle
        return mod >= 0 && mod < max(1, prefs.periodLength)
    }
    private func isFertileDate(_ d: Date) -> Bool {
        guard prefs.isWoman else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: prefs.lastPeriodStart)
        let day = cal.startOfDay(for: d)
        let diff = cal.dateComponents([.day], from: start, to: day).day ?? 0
        let cycle = max(1, prefs.cycleLength)
        let mod = ((diff % cycle) + cycle) % cycle
        return (10...15).contains(mod)
    }
}

// MARK: - Year Overview

private struct YearOverviewView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State var year: Int
    let selectedMonth: Date
    let onSelect: (Date) -> Void

    init(initialYear: Int, selectedMonth: Date, onSelect: @escaping (Date) -> Void) {
        _year = State(initialValue: initialYear)
        self.selectedMonth = selectedMonth
        self.onSelect = onSelect
    }

    private var months: [Date] {
        let cal = Calendar.current
        let jan = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        return (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: jan) }
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(months, id: \.self) { m in
                        Button { onSelect(m) } label: {
                            MonthMiniGrid(monthStart: m)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(highlight(for: m), lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle(String(year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { year += 1 } label: { Image(systemName: "chevron.right") }
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private func highlight(for m: Date) -> Color {
        let cal = Calendar.current
        let a = cal.startOfMonth(for: m)
        let b = cal.startOfMonth(for: selectedMonth)
        return a == b ? prefs.theme.accent(for: prefs.tone) : Color.clear
    }
}

private struct MonthMiniGrid: View {
    @EnvironmentObject private var prefs: PreferencesStore
    let monthStart: Date
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.locale = Locale(identifier: "es_ES"); c.firstWeekday = 1; return c }
    private var title: String { let df = DateFormatter(); df.locale = calendar.locale; df.dateFormat = "LLL"; return df.string(from: monthStart).capitalized }
    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: monthStart)!.count }
    private var startWeekdayOffset: Int { let w = calendar.component(.weekday, from: monthStart); return (w - calendar.firstWeekday + 7) % 7 }
    private var totalCells: Int { let rows = Int(ceil(Double(startWeekdayOffset + daysInMonth) / 7.0)); return rows * 7 }
    private let columns = Array(repeating: GridItem(.flexible(minimum: 12), spacing: 2), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<totalCells, id: \.self) { idx in
                    let day = idx - startWeekdayOffset + 1
                    if day >= 1 && day <= daysInMonth {
                        Text(String(day))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.primary)
                    } else {
                        Text("")
                            .font(.system(size: 10))
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(prefs.theme.surface(for: prefs.tone))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(prefs.theme.stroke(for: prefs.tone), lineWidth: 1)
        )
    }
}

// MARK: - Calendar helpers
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let c = dateComponents([.year, .month], from: date)
        return self.date(from: c) ?? date
    }
}

// MARK: - Text Note Editor (for Agenda integration)

private struct AgendaTextNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prefs: PreferencesStore
    let date: Date
    var initialText: String = ""
    var initialReminder: Date? = nil
    var initialCategory: NoteCategory = .personal
    var initialDate: Date = Date()
    var allowDateChange: Bool = true
    let onSave: (Date, String, NoteCategory, Bool, Date?) -> Void
    let onDelete: () -> Void

    @State private var text: String = ""
    @State private var category: NoteCategory = .personal
    @State private var notify: Bool = false
    @State private var notifyDate: Date = Date().addingTimeInterval(3600)
    @State private var noteDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                if allowDateChange {
                    Section(header: Text("Día")) {
                        DatePicker("Día", selection: $noteDate, displayedComponents: .date)
                    }
                }
                Section(header: Text("Nota")) {
                    TextEditor(text: $text).frame(minHeight: 160)
                }
                Section(header: Text("Categoría")) {
                    Picker("Categoría", selection: $category) {
                        ForEach(NoteCategory.allCases) { c in Text(c.displayName).tag(c) }
                    }
                }
                Section(header: Text("Recordatorio")) {
                    Toggle("Notificar", isOn: $notify)
                    if notify {
                        DatePicker("Cuando", selection: $notifyDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                if !initialText.isEmpty || initialReminder != nil { // likely editing
                    Section { Button("Borrar", role: .destructive) { onDelete(); dismiss() } }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Nota del día")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { onSave(noteDate, text, category, notify, notify ? notifyDate : nil); dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .onAppear {
            text = initialText
            category = initialCategory
            if let r = initialReminder { notify = true; notifyDate = r }
            noteDate = initialDate
        }
    }
}

// MARK: - Weekly Planner

private struct WeeklyPlannerView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Binding var date: Date
    var drawingFor: (Date) -> PKDrawing?
    var onDayTap: (Date) -> Void

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_ES")
        cal.firstWeekday = 2
        return cal
    }

    private var weekStart: Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? date
        // Ensure Monday
        let wd = calendar.component(.weekday, from: start)
        let delta = ((wd - calendar.firstWeekday + 7) % 7)
        return calendar.date(byAdding: .day, value: -delta, to: start) ?? start
    }

    private var days: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private let dayTitles = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    private let columns3 = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let columns2 = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    @State private var showWeekEditor: Bool = false
    @State private var weekDraft: String = ""

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns3, spacing: 12) {
                ForEach(0..<6, id: \.self) { i in
                    dayBox(index: i)
                }
            }
            LazyVGrid(columns: columns2, spacing: 12) {
                dayBox(index: 6)
                notesBox
            }
        }
        .sheet(isPresented: $showWeekEditor) {
            NavigationStack {
                Form {
                    Section(header: Text(weekHeaderTitle)) {
                        TextEditor(text: $weekDraft)
                            .frame(minHeight: 180)
                    }
                }
                .navigationTitle("Notas de la semana")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showWeekEditor = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            agenda.setWeekNote(for: weekStart, text: weekDraft)
                            showWeekEditor = false
                        }
                    }
                }
                .onAppear { weekDraft = agenda.weekNote(for: weekStart) ?? "" }
            }
        }
    }

    @ViewBuilder
    private func dayBox(index i: Int) -> some View {
        let d = days[i]
        let isToday = calendar.isDateInToday(d)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(dayTitles[i])
                    .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                    .textCase(.none)
                Text("\(calendar.component(.day, from: d))")
                    .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                    .foregroundStyle(subtle)
            }
            if prefs.isWoman {
                HStack(spacing: 6) {
                    if isPeriodDateWeekly(d) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                    } else if isFertileDateWeekly(d) {
                        Circle()
                            .fill(Color.green.opacity(0.9))
                            .frame(width: 7, height: 7)
                    } else if agenda.isPeriodDelayed(on: d) {
                        Text("🕒")
                            .font(.system(size: 11))
                    }
                }
                .padding(.leading, 2)
                .padding(.bottom, 2)
            }
            
            // Si hay horas con texto, mostrar 3 entradas más cercanas a la hora actual; si no, mostrar dibujo
            if let hourly = agenda.entry(for: d)?.hourly, !hourly.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    let nearest = nearestHours(for: d, limit: 3)
                    ForEach(nearest, id: \.self) { h in
                        HStack(spacing: 6) {
                            Text(String(format: "%02d:00", h))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(subtle)
                                .frame(width: 44, alignment: .leading)
                            Text(hourly[h] ?? "")
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(prefs.tone == .white ? .black : .white)
                        }
                    }
                }
                .frame(minHeight: 80, alignment: .topLeading)
                .overlay(alignment: .bottomTrailing) {
                    let extra = extraCount(for: d, shown: 3)
                    if extra > 0 {
                        Text("+\(extra)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(prefs.tone == .white ? Color.black.opacity(0.08) : Color.white.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
                    }
                }
            } else if let draw = drawingFor(d) {
                DrawingThumbnail(drawing: draw)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Spacer(minLength: 80)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(10)
        .background(glassBox(12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isToday ? prefs.theme.accent(for: prefs.tone) : stroke, lineWidth: isToday ? 1.8 : 1)
        )
        .shadow(color: Color.black.opacity(prefs.tone == .white ? 0.06 : 0.3), radius: 6, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onDayTap(d) }
    }

    // Devuelve hasta `limit` horas con texto, más cercanas a la hora actual
    private func nearestHours(for d: Date, limit: Int) -> [Int] {
        guard let dict = agenda.entry(for: d)?.hourly, !dict.isEmpty else { return [] }
        let nowHour = Calendar.current.component(.hour, from: Date())
        return dict.keys
            .sorted { lhs, rhs in
                let dl = abs(lhs - nowHour), dr = abs(rhs - nowHour)
                return dl == dr ? lhs < rhs : dl < dr
            }
            .prefix(limit)
            .map { $0 }
    }

    private func extraCount(for d: Date, shown: Int) -> Int {
        let total = agenda.entry(for: d)?.hourly?.count ?? 0
        return max(0, total - shown)
    }
    // Ciclo: helpers
    private func isPeriodDateWeekly(_ d: Date) -> Bool {
        guard prefs.isWoman else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: prefs.lastPeriodStart)
        let day = cal.startOfDay(for: d)
        let diff = cal.dateComponents([.day], from: start, to: day).day ?? 0
        let cycle = max(1, prefs.cycleLength)
        let mod = ((diff % cycle) + cycle) % cycle
        return mod >= 0 && mod < max(1, prefs.periodLength)
    }
    private func isFertileDateWeekly(_ d: Date) -> Bool {
        guard prefs.isWoman else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: prefs.lastPeriodStart)
        let day = cal.startOfDay(for: d)
        let diff = cal.dateComponents([.day], from: start, to: day).day ?? 0
        let cycle = max(1, prefs.cycleLength)
        let mod = ((diff % cycle) + cycle) % cycle
        return (10...15).contains(mod)
    }

    private var notesBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTAS").font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
            let text = agenda.weekNote(for: weekStart) ?? ""
            if text.isEmpty {
                Button {
                    showWeekEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("Escribe notas para esta semana")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                Spacer(minLength: 60)
            } else {
                Text(text)
                    .font(.caption)
                    .lineLimit(6)
                HStack {
                    Spacer()
                    Button("Editar") { showWeekEditor = true }
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(10)
        .background(glassBox(12))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(stroke, lineWidth: 1))
        .shadow(color: Color.black.opacity(prefs.tone == .white ? 0.06 : 0.3), radius: 6, y: 3)
    }

    private var weekHeaderTitle: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "'Semana de' d 'de' MMMM"; return df.string(from: weekStart).capitalized
    }

    private var stroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var subtle: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }

    @ViewBuilder
    private func glassBox(_ corner: CGFloat) -> some View {
        let isLight = (prefs.tone == .white)
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isLight ? .regularMaterial : .ultraThinMaterial)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.06))
        }
    }
}

// MARK: - Day Hours Sheet for weekly planner

private struct DayHoursSheet: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var activeHour: Int? = nil
    @State private var selectedHourForEdit: Int? = nil
    // Modo de intercambio por selección (sin drag & drop)
    @State private var swapMode: Bool = false
    @State private var selectedForSwap: Set<Int> = []

    private var hours: [Int] { Array(prefs.agendaStartHour...prefs.agendaEndHour) }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(dateHeader)) {
                    ForEach(hours, id: \.self) { h in
                        hourRow(for: h)
                    }
                }
            }
            .navigationTitle("Horas del día")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(swapMode ? "Cancelar" : "Intercambiar") {
                        withAnimation { swapMode.toggle(); selectedForSwap.removeAll() }
                    }
                }
            }
            .sheet(isPresented: Binding(get: { selectedHourForEdit != nil }, set: { if !$0 { selectedHourForEdit = nil } })) {
                if let h = selectedHourForEdit {
                    NavigationStack {
                        HourEntryEditor(date: date, hour: h)
                            .environmentObject(prefs)
                            .environmentObject(agenda)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hourRow(for h: Int) -> some View {
        HStack {
            Text(String(format: "%02d:00", h))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(agenda.hourlyText(on: date, hour: h) ?? "")
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Button {
                selectedHourForEdit = h
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill( selectedForSwap.contains(h) ? Color.accentColor.opacity(0.18) : Color.clear )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard swapMode else { return }
            toggleSelection(hour: h)
            if selectedForSwap.count == 2 { performSwap() }
        }
    }

    private var dateHeader: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "EEEE d 'de' MMMM"; return df.string(from: date).capitalized
    }

    // MARK: - Swap selection helpers
    private func toggleSelection(hour: Int) {
        if selectedForSwap.contains(hour) {
            selectedForSwap.remove(hour)
        } else {
            if selectedForSwap.count < 2 { selectedForSwap.insert(hour) }
            else {
                // If already two selected, replace the most recent selection
                if let first = selectedForSwap.first { selectedForSwap.remove(first) }
                selectedForSwap.insert(hour)
            }
        }
    }

    private func performSwap() {
        guard selectedForSwap.count == 2 else { return }
        let hours = Array(selectedForSwap).sorted()
        let h1 = hours[0], h2 = hours[1]
        if h1 == h2 { return }
        let t1 = agenda.hourlyText(on: date, hour: h1)
        let t2 = agenda.hourlyText(on: date, hour: h2)
        agenda.setHourly(on: date, hour: h1, text: t2)
        agenda.setHourly(on: date, hour: h2, text: t1)
        withAnimation {
            selectedForSwap.removeAll(); swapMode = false
        }
    }
}

// MARK: - Conditional draggable helper
private struct ConditionalDraggable: ViewModifier {
    let payload: String?
    @ViewBuilder func body(content: Content) -> some View {
        if let p = payload {
            content.draggable(p)
        } else {
            content
        }
    }
}

private extension View {
    func draggableIf(_ payload: String?) -> some View { self.modifier(ConditionalDraggable(payload: payload)) }
}

// (Drag & Drop removido por simplicidad; se usa intercambio por selección)

private struct HourEntryEditor: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let hour: Int
    @State private var text: String = ""

    var body: some View {
        Form {
            Section(header: Text(header)) {
                TextField("Escribe aquí...", text: $text, axis: .vertical)
                    .lineLimit(3...8)
            }
            if !(agenda.hourlyText(on: date, hour: hour) ?? "").isEmpty {
                Section {
                    Button("Borrar", role: .destructive) {
                        agenda.setHourly(on: date, hour: hour, text: nil)
                        dismiss()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Editar hora")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") { agenda.setHourly(on: date, hour: hour, text: text); dismiss() } }
        }
        .onAppear { text = agenda.hourlyText(on: date, hour: hour) ?? "" }
    }

    private var header: String { String(format: "%@ · %02d:00", dateShort, hour) }
    private var dateShort: String { let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "EEE d MMM"; return df.string(from: date) }
}

// MARK: - Weekly Hours Grid (configurable)

private struct WeeklyHoursGrid: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Binding var date: Date

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_ES")
        cal.firstWeekday = 2
        return cal
    }

    private var weekStart: Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? date
        let wd = calendar.component(.weekday, from: start)
        let delta = ((wd - calendar.firstWeekday + 7) % 7)
        return calendar.date(byAdding: .day, value: -delta, to: start) ?? start
    }

    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }
    private var hours: [Int] { Array(prefs.agendaStartHour...prefs.agendaEndHour) }

    private var columns: [GridItem] {
        // First column is fixed width for time labels
        var cols: [GridItem] = [GridItem(.fixed(56), spacing: 0)]
        cols.append(contentsOf: Array(repeating: GridItem(.flexible(minimum: 40), spacing: 0), count: 7))
        return cols
    }

    @State private var adding: DaySelection? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planificador semanal")
                .font(.headline)
            // Headers
            LazyVGrid(columns: columns, spacing: 0) {
                // Empty corner cell
                Text("")
                    .frame(height: 28)
                    .background(headerBG)
                ForEach(["Lun","Mar","Mié","Jue","Vie","Sáb","Dom"], id: \.self) { title in
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(headerBG)
                        .overlay(Rectangle().strokeBorder(stroke, lineWidth: 0.5))
                }
            }
            // Grid rows (sin ScrollView interno para que todo el contenido esté disponible
            // y el Scroll exterior de la pantalla sea quien maneje el desplazamiento)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(hours, id: \.self) { h in
                    HStack {
                        Text(String(format: "%02d:00", h))
                            .font(.caption)
                            .padding(.leading, 6)
                        Spacer()
                    }
                    .frame(height: 36)
                    .overlay(Rectangle().strokeBorder(stroke, lineWidth: 0.5))
                    ForEach(0..<7, id: \.self) { i in
                        let d = days[i]
                        Button {
                            adding = DaySelection(date: d)
                        } label: {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 36)
                                .overlay(Rectangle().strokeBorder(stroke, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(stroke, lineWidth: 1))
            .sheet(item: $adding) { sel in
                DayNoteQuickEditor(date: sel.date) { text in
                    agenda.addNote(on: sel.date, text: text, category: .other, reminder: nil)
                }
                .environmentObject(prefs)
            }
        }
    }

    private var stroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var headerBG: some View { (prefs.tone == .white ? Color.black.opacity(0.06) : Color.white.opacity(0.06)) }
}

private struct DayNoteQuickEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prefs: PreferencesStore
    let date: Date
    var onSave: (String) -> Void
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(dateLabel)) {
                    TextField("Escribe una nota para este día...", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Nueva nota")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { onSave(text); dismiss() } }
            }
        }
    }

    private var dateLabel: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "es_ES"); df.dateFormat = "EEE d MMM"; return df.string(from: date)
    }
}

// MARK: - Day Drawing Editor (solo Pencil)

private struct DaySelection: Identifiable { let date: Date; var id: Double { date.timeIntervalSince1970 } }

private struct DayDrawingEditor: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let initial: PKDrawing?
    let onSave: (PKDrawing) -> Void
    let onDelete: () -> Void

    @State private var drawing: PKDrawing = PKDrawing()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(dateLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PencilCanvas(drawing: $drawing)
                    .frame(minHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
                Spacer()
            }
            .padding()
            .navigationTitle("Nota del día")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { onSave(drawing); dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Borrar", role: .destructive) { onDelete(); dismiss() }
                }
            }
        }
        .onAppear { drawing = initial ?? PKDrawing() }
    }

    private var dateLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "EEEE d 'de' MMMM yyyy"
        return df.string(from: date).capitalized
    }
}

// PencilKit canvas wrapper
private struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.pen, color: .label, width: 4)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing { uiView.drawing = drawing }
    }

    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

// Thumbnail view for PKDrawing
private struct DrawingThumbnail: View {
    let drawing: PKDrawing
    var body: some View {
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 120, height: 80) : drawing.bounds.insetBy(dx: -8, dy: -8)
        let img = drawing.image(from: bounds, scale: 2)
        return Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .opacity(0.95)
    }
}

// MARK: - Glass Switcher (Mes / Semana)

private struct GlassSwitcher: View { // (mantained for reference, no longer used)
    @EnvironmentObject private var prefs: PreferencesStore
    @Binding var selection: AgendaMode
    @Namespace private var ns

    var body: some View {
        GeometryReader { geo in
            let w = max(0, geo.size.width)
            let h: CGFloat = 36
            let segW = w / 2
            ZStack {
                // Background glass
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prefs.tone == .white ? .regularMaterial : .ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((prefs.tone == .white ? Color.black.opacity(0.10) : Color.white.opacity(0.06)))

                // Selection pill (glass)
                HStack(spacing: 0) {
                    Capsule().fill(Color.clear).frame(width: segW)
                    Capsule().fill(Color.clear).frame(width: segW)
                }
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(prefs.tone == .white ? .regularMaterial : .ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder((prefs.tone == .white ? Color.black.opacity(0.16) : Color.white.opacity(0.20)), lineWidth: 1)
                        )
                        .frame(width: segW - 6, height: h - 6)
                        .padding(3)
                        .offset(x: selection == .month ? 0 : segW)
                        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selection)
                }

                HStack(spacing: 0) {
                    segment(title: "Mes", isSelected: selection == .month) { selection = .month }
                        .frame(width: segW, height: h)
                    segment(title: "Semana", isSelected: selection == .week) { selection = .week }
                        .frame(width: segW, height: h)
                }
            }
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder((prefs.tone == .white ? Color.black.opacity(0.16) : Color.white.opacity(0.20)), lineWidth: 1))
        }
        .frame(height: 36)
    }

    private func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? (prefs.tone == .white ? Color.black : Color.white) : (prefs.tone == .white ? Color.black.opacity(0.6) : Color.white.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Liquid Switch (Mes / Semana)

private struct ModeSwitch: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @Binding var selection: AgendaMode

    var isOn: Bool { selection == .week }

    var body: some View {
        HStack(spacing: 10) {
            Text("Mes")
                .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                .foregroundStyle(isOn ? dimmed : active)
                .frame(minWidth: 28, alignment: .leading)

            ZStack(alignment: isOn ? .trailing : .leading) {
                // Background track (tinted like iOS switch)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(trackGradient)
                    .frame(width: 76, height: 36)
                    .shadow(color: glow.opacity(0.30), radius: 8, y: 2)

                // Glass knob
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(prefs.tone == .white ? .regularMaterial : .ultraThinMaterial)
                    .frame(width: 52, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(highlightStroke, lineWidth: 1)
                    )
                    .padding(4)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: isOn)
            .onTapGesture { withAnimation { selection = isOn ? .month : .week } }

            Text("Semana")
                .font(.system(.footnote, design: .serif).weight(.semibold)).appItalic(prefs.useItalic)
                .foregroundStyle(isOn ? active : dimmed)
                .frame(minWidth: 48, alignment: .leading)
        }
    }

    private var active: Color { prefs.tone == .white ? .black : .white }
    private var dimmed: Color { prefs.tone == .white ? .black.opacity(0.5) : .white.opacity(0.7) }
    private var glow: Color { prefs.theme.accent(for: prefs.tone) }
    private var trackGradient: LinearGradient {
        LinearGradient(
            colors: [glow.opacity(0.85), glow.opacity(0.7)],
            startPoint: .leading, endPoint: .trailing
        )
    }
    private var highlightStroke: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.75), Color.white.opacity(0.15)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// No extra helpers

