import SwiftUI

extension View {
    @ViewBuilder
    func appItalic(enabled: Bool) -> some View {
        if enabled { self.italic() } else { self }
    }

    @ViewBuilder
    func appFontDesign(_ design: TypographyDesign) -> some View {
        switch design {
        case .system: self
        case .serif: self.fontDesign(.serif)
        case .rounded: self.fontDesign(.rounded)
        }
    }
}
