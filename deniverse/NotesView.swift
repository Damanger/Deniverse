import SwiftUI
import UserNotifications

struct NotesView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore

    @Binding var searchText: String

    let onNew: () -> Void
    let onIncome: () -> Void
    let onExpense: () -> Void

    @State private var notesCurrentDate: Date = .now
    @State private var showTextEditor: Bool = false
    @State private var editingNote: NoteItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchBar
            quickActions
            monthlyCalendar
            if prefs.isWoman { cycleTracking }
        }
        .appItalic(prefs.useItalic)
        .appFontDesign(prefs.fontDesign)
        .sheet(isPresented: $showTextEditor) {
            if let n = editingNote {
                TextNoteEditor(
                    date: notesCurrentDate,
                    initialText: n.text,
                    initialReminder: n.reminder,
                    initialCategory: n.category,
                    onSave: { text, category, notify, when in
                        let reminder = notify ? (when ?? notesCurrentDate) : nil
                        agenda.updateNote(on: notesCurrentDate, id: n.id, text: text, category: category, reminder: reminder)
                        if let r = reminder { scheduleNotification(at: r, title: "Nota", body: text) }
                    },
                    onDelete: {
                        agenda.deleteNote(on: notesCurrentDate, id: n.id)
                    }
                )
            } else {
                TextNoteEditor(
                    date: notesCurrentDate,
                    onSave: { text, category, notify, when in
                        let reminder = notify ? (when ?? notesCurrentDate) : nil
                        agenda.addNote(on: notesCurrentDate, text: text, category: category, reminder: reminder)
                        if let r = reminder { scheduleNotification(at: r, title: "Nota", body: text) }
                    },
                    onDelete: {}
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.85), Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "note.text")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Notas")
                    .font(.title2.weight(.bold))
                Text("Notas y recordatorios")
                    .font(.footnote)
                    .foregroundStyle(subtleForeground)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notas y recordatorios")
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas").font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "Nuevo", systemImage: "plus", tint: .orange, action: newNote, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: onIncome, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: onExpense, useWhiteBackground: true)
            }
        }
    }

    // Se eliminó la sección de "Recientes" temporalmente

    // Estilo derivado del tema
    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var contentForeground: Color { prefs.tone == .white ? .black : .white }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }
    
    // MARK: - Monthly Calendar

    private var monthlyCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotesMonthCalendarView(current: $notesCurrentDate, onSelect: { d in
                notesCurrentDate = d
            })
            .environmentObject(prefs)
            .environmentObject(agenda)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(appSurface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(appStroke, lineWidth: 1))

        // Day notes list below calendar
        VStack(alignment: .leading, spacing: 8) {
            let items = agenda.notes(for: notesCurrentDate)
            if !items.isEmpty {
                Text("Notas del día").font(.headline)
                ForEach(agenda.notes(for: notesCurrentDate)) { n in
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
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appSurface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(appStroke, lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture { editingNote = n; showTextEditor = true }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { editingNote = n; showTextEditor = true } label: { Label("Editar", systemImage: "square.and.pencil") }
                                .tint(.blue)
                            Button(role: .destructive) { withAnimation { agenda.deleteNote(on: notesCurrentDate, id: n.id) } } label: { Label("Borrar", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .id(agenda.notes(for: notesCurrentDate).count) // fuerza refresco inmediato de la lista del día
    }

    // MARK: - Cycle Tracking label
    private var cycleTracking: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ciclo menstrual").font(.headline)
            Text("Se destacan días de periodo y ventana fértil según Ajustes > Salud.")
                .font(.footnote)
                .foregroundStyle(subtleForeground)
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
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill").foregroundStyle(.yellow)
                    Text("Recordatorio")
                        .font(.footnote)
                        .foregroundStyle(subtleForeground)
                }
            }
            .padding(.top, 2)
        }
    }
    // MARK: - New note action
    private func newNote() { editingNote = nil; showTextEditor = true }

    // Schedule a local notification
    private func scheduleNotification(at date: Date, title: String, body: String) {
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

    private func shortDate(_ d: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; return df.string(from: d)
    }
}

// Simple month calendar for Notes with cycle markers
private struct NotesMonthCalendarView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var agenda: AgendaStore
    @Binding var current: Date
    var onSelect: (Date) -> Void

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2
        return c
    }

    private var monthInterval: DateInterval { calendar.dateInterval(of: .month, for: current)! }
    private var daysInMonth: Int { calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day! }
    private var startOffset: Int {
        let wd = calendar.component(.weekday, from: monthInterval.start)
        let mondayBased = (wd - calendar.firstWeekday + 7) % 7 + 1
        return mondayBased - 1
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var headers: [String] { ["L", "M", "M", "J", "V", "S", "D"] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { current = calendar.date(byAdding: .month, value: -1, to: current) ?? current } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                Text(monthTitle(current)).font(.headline.weight(.semibold))
                Spacer()
                Button { current = calendar.date(byAdding: .month, value: 1, to: current) ?? current } label: {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(headers, id: \.self) { h in
                    Text(h)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(prefs.tone == .dark ? Color.white : Color.black)
                }
            }
            Divider().opacity(0.2)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0 ..< (Int(ceil(Double(startOffset + daysInMonth) / 7.0)) * 7), id: \.self) { idx in
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(Color.clear).frame(height: 42)
                        if let comps = dayComponents(idx), let day = comps.day, let cellDate = calendar.date(from: comps) {
                            // Today ring
                            if calendar.isDateInToday(cellDate) {
                                Circle()
                                    .stroke(prefs.theme.accent(for: prefs.tone), lineWidth: 1.3)
                                    .frame(width: 24, height: 24)
                                    .padding(.top, 2)
                                    .padding(.leading, 2)
                            }
                            Text("\(day)")
                                .font(.caption.weight(.semibold))
                                .padding(.top, 4)
                                .padding(.leading, 6)
                            if isPeriod(comps) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.red)
                                    .padding(.top, 20)
                                    .padding(.leading, 6)
                            } else if isFertile(comps) {
                                Circle().fill(Color.green.opacity(0.9)).frame(width: 8, height: 8).padding(.top, 22).padding(.leading, 8)
                            }
                            if hasReminder(comps) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.yellow)
                                    .padding(.top, 20)
                                    .padding(.trailing, 6)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            if hasNotes(cellDate) {
                                Circle().fill(Color.blue.opacity(0.9))
                                    .frame(width: 6, height: 6)
                                    .padding(.bottom, 4)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let comps = dayComponents(idx), let d = calendar.date(from: comps) { onSelect(d) }
                    }
                    .overlay(Rectangle().strokeBorder(stroke, lineWidth: 0.5))
                }
            }
        }
    }

    private var stroke: Color { prefs.theme.stroke(for: prefs.tone) }

    private func dayComponents(_ idx: Int) -> DateComponents? {
        let day = idx - startOffset + 1
        guard day >= 1 && day <= daysInMonth else { return nil }
        var dc = calendar.dateComponents([.year, .month], from: monthInterval.start)
        dc.day = day
        return dc
    }

    private func monthTitle(_ d: Date) -> String {
        let df = DateFormatter(); df.locale = calendar.locale; df.calendar = calendar; df.dateFormat = "LLLL yyyy"
        let s = df.string(from: d); return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func isPeriod(_ comps: DateComponents) -> Bool {
        guard prefs.isWoman, let date = calendar.date(from: comps) else { return false }
        let start = prefs.lastPeriodStart
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        let mod = (diff % prefs.cycleLength + prefs.cycleLength) % prefs.cycleLength
        return mod >= 0 && mod < prefs.periodLength
    }

    private func isFertile(_ comps: DateComponents) -> Bool {
        guard prefs.isWoman, let date = calendar.date(from: comps) else { return false }
        let start = prefs.lastPeriodStart
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        let mod = (diff % prefs.cycleLength + prefs.cycleLength) % prefs.cycleLength
        return (10...15).contains(mod)
    }

    private func hasReminder(_ comps: DateComponents) -> Bool {
        guard let d = calendar.date(from: comps), let rem = agenda.entry(for: d)?.reminder else { return false }
        // Mark if same calendar day
        return calendar.isDate(rem, inSameDayAs: d)
    }

    private func hasNotes(_ d: Date) -> Bool { !agenda.notes(for: d).isEmpty }
}

// Simple text note editor with optional notification
private struct TextNoteEditor: View {
    let date: Date
    var initialText: String = ""
    var initialReminder: Date? = nil
    var initialCategory: NoteCategory = .personal
    let onSave: (String, NoteCategory, Bool, Date?) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var category: NoteCategory = .personal
    @State private var notify: Bool = false
    @State private var notifyDate: Date = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
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
            }
            .navigationTitle("Nota del día")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { onSave(text, category, notify, notify ? notifyDate : nil); dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                ToolbarItem(placement: .destructiveAction) { Button("Borrar", role: .destructive) { onDelete(); dismiss() } }
            }
        }
        .onAppear {
            text = initialText
            category = initialCategory
            if let r = initialReminder { notify = true; notifyDate = r }
        }
    }
}
