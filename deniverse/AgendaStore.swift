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
}

final class AgendaStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var entries: [String: DayEntry] { didSet { save() } }

    private let url: URL
    private var loading = false

    init(filename: String = "Agenda.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = dir.appendingPathComponent(filename)

        // Prepare initial values without using self
        let initialEntries: [String: DayEntry]
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? JSONDecoder().decode([String: DayEntry].self, from: data) {
            initialEntries = dict
        } else {
            initialEntries = [:]
        }

        // Now initialize stored properties
        self.url = fileURL
        self.entries = initialEntries
    }

    func key(for date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
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
    }

    func notes(for date: Date) -> [NoteItem] { entries[key(for: date)]?.notes ?? [] }

    func deleteNote(on date: Date, id: UUID) {
        let k = key(for: date)
        guard var e = entries[k], var list = e.notes else { return }
        list.removeAll { $0.id == id }
        e.notes = list.isEmpty ? nil : list
        // Recompute day-level reminder
        e.reminder = (list.compactMap { $0.reminder }.min())
        entries[k] = e
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
        }
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
}
