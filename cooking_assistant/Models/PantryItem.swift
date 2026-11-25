import Foundation

struct PantryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var unit: String
    var category: PantryCategory

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        unit: String,
        category: PantryCategory = .other
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.category = category
    }
}
