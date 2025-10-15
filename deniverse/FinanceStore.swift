import Foundation
import SwiftUI
import Combine

struct FinanceDTO: Codable {
    var walletBalance: Double
    var transactions: [TransactionDTO]
}

final class FinanceStore: ObservableObject {
    @Published var transactions: [Transaction] { didSet { save() } }
    @Published var walletBalance: Double { didSet { save() } }
    private let url: URL
    private var loading = false

    init(filename: String = "Finance.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.url = dir.appendingPathComponent(filename)
        self.transactions = []
        self.walletBalance = 0
        load()
    }

    private func load() {
        loading = true; defer { loading = false }
        guard let data = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        if let dto = try? dec.decode(FinanceDTO.self, from: data) {
            self.walletBalance = dto.walletBalance
            self.transactions = dto.transactions.map { $0.asModel }
        } else if let list = try? dec.decode([TransactionDTO].self, from: data) { // backwards compatibility
            self.transactions = list.map { $0.asModel }
            self.walletBalance = 0
        }
    }

    private func save() {
        if loading { return }
        let dto = FinanceDTO(walletBalance: walletBalance, transactions: transactions.map { TransactionDTO(from: $0) })
        if let data = try? JSONEncoder.pretty.encode(dto) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// Codable helper to persist Transaction
struct TransactionDTO: Codable {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    var category: String?

    init(from t: Transaction) {
        id = t.id; title = t.title; amount = t.amount; date = t.date; category = t.category.rawValue
    }
    var asModel: Transaction {
        let cat = FinanceCategory(rawValue: category ?? FinanceCategory.other.rawValue) ?? .other
        return Transaction(id: id, title: title, amount: amount, date: date, category: cat)
    }
}

private extension JSONEncoder { static var pretty: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e } }
