import Foundation

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = .current
    return f
}()

public func currencyString(_ value: Double) -> String {
    // Ensure we always get a string; fall back to manual formatting if needed
    if let s = currencyFormatter.string(from: NSNumber(value: value)) {
        return s
    }
    return String(format: "%0.2f", value)
}
