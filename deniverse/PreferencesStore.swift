import Foundation
import SwiftUI
import Combine

enum ThemeColor: String, CaseIterable, Identifiable, Codable {
    case mint, peach, lavender, sky, lime, coral, rose, yellow, red, white, black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mint: return "Menta"
        case .peach: return "Durazno"
        case .lavender: return "Lavanda"
        case .sky: return "Cielo"
        case .lime: return "Lima"
        case .coral: return "Coral"
        case .rose: return "Rosa"
        case .yellow: return "Amarillo"
        case .red: return "Rojo"
        case .white: return "Blanco"
        case .black: return "Negro"
        }
    }

    var color: Color {
        switch self {
        case .mint: return Color(red: 0.70, green: 0.90, blue: 0.83)
        case .peach: return Color(red: 1.00, green: 0.82, blue: 0.73)
        case .lavender: return Color(red: 0.80, green: 0.77, blue: 0.95)
        case .sky: return Color(red: 0.72, green: 0.86, blue: 0.98)
        case .lime: return Color(red: 0.82, green: 0.92, blue: 0.68)
        case .coral: return Color(red: 1.00, green: 0.76, blue: 0.73)
        case .rose: return Color(red: 1.00, green: 0.78, blue: 0.86)
        case .yellow: return Color(red: 1.00, green: 0.94, blue: 0.60)
        case .red: return Color(red: 0.98, green: 0.66, blue: 0.66)
        case .white: return .white
        case .black: return .black
        }
    }

    var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .mint: return (0.70, 0.90, 0.83)
        case .peach: return (1.00, 0.82, 0.73)
        case .lavender: return (0.80, 0.77, 0.95)
        case .sky: return (0.72, 0.86, 0.98)
        case .lime: return (0.82, 0.92, 0.68)
        case .coral: return (1.00, 0.76, 0.73)
        case .rose: return (1.00, 0.78, 0.86)
        case .yellow: return (1.00, 0.94, 0.60)
        case .red: return (0.98, 0.66, 0.66)
        case .white: return (1.00, 1.00, 1.00)
        case .black: return (0.00, 0.00, 0.00)
        }
    }

    func darken(_ amount: Double) -> Color {
        let c = rgb
        let f = max(0, min(1, 1 - amount))
        return Color(red: c.r * f, green: c.g * f, blue: c.b * f)
    }

    // Accents and surfaces derived from the base pastel
    func accent(for tone: ThemeTone) -> Color {
        switch (self, tone) {
        case (.white, .white): return Color.gray
        case (.white, .dark):  return .white
        case (.black, .dark):  return .white
        case (.black, .white): return .black
        case (_, .white):      return darken(0.25)
        case (_, .dark):       return darken(0.40)
        }
    }

    func surface(for tone: ThemeTone) -> Color {
        switch (self, tone) {
        // Neutros aún más claros
        case (.white, .white): return Color(white: 0.98)
        case (.white, .dark):  return Color(white: 0.20)
        case (.black, .white): return Color(white: 0.95)
        case (.black, .dark):  return Color(white: 0.18)
        // Pasteles: aclara más la superficie para mejorar legibilidad
        case (_, .white):      return darken(0.07)
        case (_, .dark):       return darken(0.25)
        }
    }

    func stroke(for tone: ThemeTone) -> Color {
        switch (self, tone) {
        case (.white, .white): return Color.gray.opacity(0.14)
        case (.white, .dark):  return Color.white.opacity(0.18)
        case (.black, .white): return Color.black.opacity(0.14)
        case (.black, .dark):  return Color.white.opacity(0.20)
        case (_, .white):      return darken(0.25).opacity(0.18)
        case (_, .dark):       return darken(0.45).opacity(0.24)
        }
    }

    var themeDarkSurface: Color { darken(0.55) }
}

enum ThemeTone: String, CaseIterable, Identifiable, Codable {
    case white, dark
    var id: String { rawValue }
    var displayName: String { self == .dark ? "Obscuro" : "Blanco" }
}

enum TypographyDesign: String, CaseIterable, Identifiable, Codable {
    case system, serif, rounded
    var id: String { rawValue }
    var displayName: String {
        switch self { case .system: return "Sistema"; case .serif: return "Serif"; case .rounded: return "Redondeada" }
    }
}

private struct PreferencesDTO: Codable {
    var showFinance: Bool
    var hideWelcomeCard: Bool
    var theme: ThemeColor
    var preferredCurrency: String
    var notificationsEnabled: Bool
    var tone: ThemeTone
    var isWoman: Bool
    var lastPeriodStart: Date
    var cycleLength: Int
    var periodLength: Int
    var useItalic: Bool
    var fontDesign: TypographyDesign
    var dailySpendLimit: Double?
    var agendaStartHour: Int?
    var agendaEndHour: Int?
    var lastCycleAlertDayKey: String?
}

final class PreferencesStore: ObservableObject {
    @Published var showFinance: Bool { didSet { save() } }
    @Published var hideWelcomeCard: Bool { didSet { save() } }
    @Published var theme: ThemeColor { didSet { save() } }
    @Published var preferredCurrency: String { didSet { save() } }
    @Published var notificationsEnabled: Bool { didSet { save() } }
    @Published var tone: ThemeTone { didSet { save() } }
    // Health / cycle tracking
    @Published var isWoman: Bool { didSet { save() } }
    @Published var lastPeriodStart: Date { didSet { save() } }
    @Published var cycleLength: Int { didSet { save() } }
    @Published var periodLength: Int { didSet { save() } }
    @Published var useItalic: Bool { didSet { save() } }
    @Published var fontDesign: TypographyDesign { didSet { save() } }
    @Published var dailySpendLimit: Double? { didSet { save() } }
    @Published var agendaStartHour: Int { didSet { save() } }
    @Published var agendaEndHour: Int { didSet { save() } }
    @Published var lastCycleAlertDayKey: String? { didSet { save() } }

    private let url: URL
    private var loading = false

    init(filename: String = "Preferences.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.url = dir.appendingPathComponent(filename)
        self.showFinance = false
        self.hideWelcomeCard = false
        self.theme = .mint
        // Default currency is MXN; user changes persist in Preferences.json
        self.preferredCurrency = "MXN"
        self.notificationsEnabled = true
        self.tone = .white
        self.isWoman = false
        self.lastPeriodStart = Date()
        self.cycleLength = 28
        self.periodLength = 5
        self.useItalic = true
        self.fontDesign = .serif
        self.dailySpendLimit = nil
        self.agendaStartHour = 6
        self.agendaEndHour = 21
        self.lastCycleAlertDayKey = nil
        load()
    }

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: url) else { return }
        if let dto = try? JSONDecoder().decode(PreferencesDTO.self, from: data) {
            self.showFinance = dto.showFinance
            self.hideWelcomeCard = dto.hideWelcomeCard
            self.theme = dto.theme
            self.preferredCurrency = dto.preferredCurrency
            self.notificationsEnabled = dto.notificationsEnabled
            self.tone = dto.tone
            self.isWoman = dto.isWoman
            self.lastPeriodStart = dto.lastPeriodStart
            self.cycleLength = dto.cycleLength
            self.periodLength = dto.periodLength
            self.useItalic = dto.useItalic
            self.fontDesign = dto.fontDesign
            self.dailySpendLimit = dto.dailySpendLimit
            if let sh = dto.agendaStartHour { self.agendaStartHour = sh }
            if let eh = dto.agendaEndHour { self.agendaEndHour = eh }
            self.lastCycleAlertDayKey = dto.lastCycleAlertDayKey
        }
    }

    private func save() {
        if loading { return }
        let dto = PreferencesDTO(
            showFinance: showFinance,
            hideWelcomeCard: hideWelcomeCard,
            theme: theme,
            preferredCurrency: preferredCurrency,
            notificationsEnabled: notificationsEnabled,
            tone: tone,
            isWoman: isWoman,
            lastPeriodStart: lastPeriodStart,
            cycleLength: cycleLength,
            periodLength: periodLength,
            useItalic: useItalic,
            fontDesign: fontDesign,
            dailySpendLimit: dailySpendLimit,
            agendaStartHour: agendaStartHour,
            agendaEndHour: agendaEndHour,
            lastCycleAlertDayKey: lastCycleAlertDayKey
        )
        do {
            let data = try JSONEncoder.pretty.encode(dto)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("Preferences save error:", error)
            #endif
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }
}

// MARK: - Helpers
extension PreferencesStore {
    func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = preferredCurrency
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
