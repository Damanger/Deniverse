import SwiftUI
import PencilKit
import UniformTypeIdentifiers

enum AgendaMode { case month, week }

struct AgendaView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var selectedDate: Date = .now
    @State private var mode: AgendaMode = .month
    @EnvironmentObject private var agenda: AgendaStore
    @State private var editor: DaySelection?
    @State private var hourPicker: DaySelection? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Group {
                switch mode {
                case .month:
                    MonthCalendarView(date: $selectedDate, onDayTap: { d in hourPicker = DaySelection(date: d) })
                        .environmentObject(prefs)
                case .week:
                    WeeklyPlannerView(
                        date: $selectedDate,
                        drawingFor: { date in
                            if let data = agenda.entry(for: date)?.drawingData, let d = try? PKDrawing(data: data) { return d }
                            return nil
                        },
                        onDayTap: { d in hourPicker = DaySelection(date: d) }
                    )
                    .environmentObject(prefs)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appStroke, lineWidth: 1))
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
            .padding(.bottom, 2)
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
            .frame(height: h)
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
