import Foundation

nonisolated struct NutritionInfo: Codable, Sendable {

    var calories: Double?
    var protein: Double?
    var fat: Double?
    var carbs: Double?

    static let empty = NutritionInfo(
        calories: nil,
        protein: nil,
        fat: nil,
        carbs: nil
    )
}
