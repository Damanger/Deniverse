import Foundation
import Combine

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case personal, work, finance, health, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .work: return "Trabajo"
        case .finance: return "Finanzas"
        case .health: return "Salud"
        case .other: return "Otro"
        }
    }
}

struct NoteItem: Codable, Identifiable {
    var id = UUID()
    var text: String
    var category: NoteCategory
    var createdAt: Date
    var reminder: Date?
}

struct DayEntry: Codable {
    var text: String?
    var drawingData: Data?
    var reminder: Date?
    var notes: [NoteItem]? // notas creadas desde Notas
    var hourly: [Int: String]? // clave: hora (0-23)
    var periodDelayed: Bool? // marca de retraso de ciclo
}

final class AgendaStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var entries: [String: DayEntry] { didSet { save() } }
    // Notas por semana (clave: año-semana)
    @Published var weekNotes: [String: String] { didSet { saveWeekNotes() } }

    private let url: URL
    private let weekUrl: URL
    private var loading = false

    init(filename: String = "Agenda.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = dir.appendingPathComponent(filename)
        let weekURL = dir.appendingPathComponent("WeekNotes.json")

        // Prepare initial values without using self
        let initialEntries: [String: DayEntry]
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? JSONDecoder().decode([String: DayEntry].self, from: data) {
            initialEntries = dict
        } else {
            initialEntries = [:]
        }
        // Load week notes (separate archivo)
        let initialWeekNotes: [String: String]
        if let wdata = try? Data(contentsOf: weekURL),
           let wdict = try? JSONDecoder().decode([String: String].self, from: wdata) {
            initialWeekNotes = wdict
        } else {
            initialWeekNotes = [:]
        }

        // Now initialize stored properties
        self.url = fileURL
        self.weekUrl = weekURL
        self.entries = initialEntries
        self.weekNotes = initialWeekNotes
    }

    /// Vuelve a cargar el JSON desde disco y reemplaza `entries` sin volver a guardar.
    func reloadFromDisk() {
        do {
            let data = try Data(contentsOf: url)
            let dict = try JSONDecoder().decode([String: DayEntry].self, from: data)
            loading = true
            entries = dict
            loading = false
            DispatchQueue.main.async { self.objectWillChange.send() }
        } catch {
            #if DEBUG
            print("Agenda reload error:", error)
            #endif
        }
    }

    func key(for date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // Clave por semana (año-semana), usando calendario ISO (lunes como inicio)
    func weekKey(for date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = comps.yearForWeekOfYear ?? 0
        let w = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", y, w)
    }

    func entry(for date: Date) -> DayEntry? { entries[key(for: date)] }

    func update(date: Date, text: String?, drawingData: Data?) {
        let k = key(for: date)
        var e = entries[k] ?? DayEntry()
        e.text = (text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : text
        e.drawingData = drawingData
        entries[k] = e
    }

    // Overload to set reminder date (nil clears)
    func update(date: Date, text: String?, drawingData: Data?, reminder: Date?) {
        let k = key(for: date)
        var e = entries[k] ?? DayEntry()
        e.text = (text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : text
        e.drawingData = drawingData
        e.reminder = reminder
        entries[k] = e
    }

    func addNote(on date: Date, text: String, category: NoteCategory, reminder: Date?) {
        let k = key(for: date)
        var e = entries[k] ?? DayEntry()
        var list = e.notes ?? []
        list.append(NoteItem(text: text, category: category, createdAt: Date(), reminder: reminder))
        e.notes = list
        // Keep day-level reminder if any note has one (earliest)
        if let r = reminder { e.reminder = min(e.reminder ?? r, r) }
        entries[k] = e
        // Refresca desde disco para reflejar la persistencia inmediatamente
        reloadFromDisk()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    func notes(for date: Date) -> [NoteItem] { entries[key(for: date)]?.notes ?? [] }

    // MARK: - Hourly notes
    func hourlyText(on date: Date, hour: Int) -> String? {
        entries[key(for: date)]?.hourly?[hour]
    }

    func setHourly(on date: Date, hour: Int, text: String?) {
        let k = key(for: date)
        var e = entries[k] ?? DayEntry()
        var dict = e.hourly ?? [:]
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            dict.removeValue(forKey: hour)
        } else {
            dict[hour] = trimmed
        }
        e.hourly = dict.isEmpty ? nil : dict
        entries[k] = e
        reloadFromDisk()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    // MARK: - Period delay flags
    func setPeriodDelay(on date: Date, delayed: Bool) {
        let k = key(for: date)
        var e = entries[k] ?? DayEntry()
        e.periodDelayed = delayed ? true : nil
        entries[k] = e
        reloadFromDisk()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    func isPeriodDelayed(on date: Date) -> Bool {
        entries[key(for: date)]?.periodDelayed ?? false
    }

    func deleteNote(on date: Date, id: UUID) {
        let k = key(for: date)
        guard var e = entries[k], var list = e.notes else { return }
        list.removeAll { $0.id == id }
        e.notes = list.isEmpty ? nil : list
        // Recompute day-level reminder
        e.reminder = (list.compactMap { $0.reminder }.min())
        entries[k] = e
        reloadFromDisk()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    func updateNote(on date: Date, id: UUID, text: String, category: NoteCategory, reminder: Date?) {
        let k = key(for: date)
        guard var e = entries[k], var list = e.notes else { return }
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].text = text
            list[idx].category = category
            list[idx].reminder = reminder
            e.notes = list
            e.reminder = (list.compactMap { $0.reminder }.min())
            entries[k] = e
            reloadFromDisk()
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    // MARK: - Week notes helpers
    func weekNote(for date: Date) -> String? {
        weekNotes[weekKey(for: date)]
    }

    func setWeekNote(for date: Date, text: String?) {
        let k = weekKey(for: date)
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            weekNotes.removeValue(forKey: k)
        } else {
            weekNotes[k] = trimmed
        }
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    private func save() {
        if loading { return }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("Agenda save error:", error)
            #endif
        }
    }

    private func saveWeekNotes() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(weekNotes)
            try data.write(to: weekUrl, options: .atomic)
        } catch {
            #if DEBUG
            print("Week notes save error:", error)
            #endif
        }
    }
}
