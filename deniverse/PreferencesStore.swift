import Foundation
import SwiftUI
import Combine

enum ThemeColor: String, CaseIterable, Identifiable, Codable {
    case mint, peach, lavender, sky, lime, coral, rose

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
        }
    }

    func darken(_ amount: Double) -> Color {
        let c = rgb
        let f = max(0, min(1, 1 - amount))
        return Color(red: c.r * f, green: c.g * f, blue: c.b * f)
    }

    // Accents and surfaces derived from the base pastel
    func accent(for tone: ThemeTone) -> Color {
        switch tone {
        case .white: return darken(0.25)
        case .dark:  return darken(0.40)
        }
    }

    func surface(for tone: ThemeTone) -> Color {
        switch tone {
        case .white: return darken(0.30)
        case .dark:  return darken(0.55)
        }
    }

    func stroke(for tone: ThemeTone) -> Color {
        switch tone {
        case .white: return darken(0.45).opacity(0.28)
        case .dark:  return darken(0.75).opacity(0.35)
        }
    }

    var themeDarkSurface: Color { darken(0.55) }
}

enum ThemeTone: String, CaseIterable, Identifiable, Codable {
    case white, dark
    var id: String { rawValue }
    var displayName: String { self == .dark ? "Obscuro" : "Blanco" }
}

private struct PreferencesDTO: Codable {
    var showFinance: Bool
    var hideWelcomeCard: Bool
    var theme: ThemeColor
    var preferredCurrency: String
    var notificationsEnabled: Bool
    var tone: ThemeTone
}

final class PreferencesStore: ObservableObject {
    @Published var showFinance: Bool { didSet { save() } }
    @Published var hideWelcomeCard: Bool { didSet { save() } }
    @Published var theme: ThemeColor { didSet { save() } }
    @Published var preferredCurrency: String { didSet { save() } }
    @Published var notificationsEnabled: Bool { didSet { save() } }
    @Published var tone: ThemeTone { didSet { save() } }

    private let url: URL
    private var loading = false

    init(filename: String = "Preferences.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.url = dir.appendingPathComponent(filename)
        self.showFinance = false
        self.hideWelcomeCard = false
        self.theme = .mint
        self.preferredCurrency = Locale.current.currency?.identifier ?? Locale.current.currency?.identifier ?? "MXN"
        self.notificationsEnabled = true
        self.tone = .white
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
            tone: tone
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
