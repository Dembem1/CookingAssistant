import Foundation

nonisolated struct Ingredient: Identifiable, Codable, Sendable {
    let name: String
    let amount: Double
    let unit: String

    var id: String {
        name
    }
}
