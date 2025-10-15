import SwiftUI

// Adapter to bridge your custom TypographyDesign to SwiftUI's Font.Design
extension TypographyDesign {
    var asFontDesign: Font.Design {
        switch self {
        case .rounded:
            return .rounded
        case .serif:
            return .serif
        case .system:
            return .default
        @unknown default:
            // Fallback for any other or future cases in TypographyDesign
            return .default
        }
    }
}
