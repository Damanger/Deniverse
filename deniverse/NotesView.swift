import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var prefs: PreferencesStore

    @Binding var searchText: String
    let filteredItems: [RecentItem]

    let onNew: () -> Void
    let onIncome: () -> Void
    let onExpense: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchBar
            quickActions
            recentSection
        }
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
                ActionButton(title: "Nuevo", systemImage: "plus", tint: .orange, action: onNew, useWhiteBackground: true)
                ActionButton(title: "Ingreso", systemImage: "plus", tint: .green, action: onIncome, useWhiteBackground: true)
                ActionButton(title: "Gasto", systemImage: "minus", tint: .red, action: onExpense, useWhiteBackground: true)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recientes").font(.headline)
            VStack(spacing: 10) {
                ForEach(filteredItems.indices, id: \.self) { index in
                    let item = filteredItems[index]
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .frame(width: 28)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(contentForeground)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.subtitle).font(.footnote).foregroundStyle(subtleForeground)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(subtleForeground)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(appStroke, lineWidth: 1))
                }
            }
            .padding(.top, 2)
        }
    }

    // Estilo derivado del tema
    private var appSurface: Color { prefs.theme.surface(for: prefs.tone) }
    private var appStroke: Color { prefs.theme.stroke(for: prefs.tone) }
    private var contentForeground: Color { prefs.tone == .white ? .black : .white }
    private var subtleForeground: Color { prefs.tone == .white ? .black.opacity(0.7) : .white.opacity(0.85) }
}

