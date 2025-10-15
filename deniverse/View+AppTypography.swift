import SwiftUI

public extension View {
    /// Conditionally applies italic styling to the view.
    /// - Parameter active: When true, applies `.italic()`; otherwise leaves the view unchanged.
    @inlinable
    @ViewBuilder
    func appItalicIf(_ active: Bool) -> some View {
        if active {
            self.italic()
        } else {
            self
        }
    }

    /// Applies a font design to the view's font.
    /// - Parameter design: The `Font.Design` to apply.
    @inlinable
    func appFontDesign(_ design: Font.Design) -> some View {
        self.fontDesign(design)
    }
}
