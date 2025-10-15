import SwiftUI

private struct AppItalicModifier: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.italic()
        } else {
            content
        }
    }
}

public extension View {
    func appItalic(_ enabled: Bool) -> some View {
        modifier(AppItalicModifier(enabled: enabled))
    }
}
