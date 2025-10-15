import Foundation
import SwiftUI

// Formatea valores de moneda respetando la configuración local
func currencyString(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    if #available(iOS 16.0, *) {
        formatter.currencyCode = Locale.current.currency?.identifier ?? Locale.current.currencyCode ?? "MXN"
    } else {
        formatter.currencyCode = Locale.current.currencyCode ?? "MXN"
    }
    formatter.locale = Locale.current
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}

