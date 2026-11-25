import Foundation

struct ShoppingListItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var unit: String
    var category: PantryCategory
    var isPurchased: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        unit: String,
        category: PantryCategory = .other,
        isPurchased: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.category = category
        self.isPurchased = isPurchased
    }
}
