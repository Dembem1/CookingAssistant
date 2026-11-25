import Foundation

struct DietaryPreferences: Codable {

    var selectedDiets: [String]
    var allergies: String
    var dislikedIngredients: String

    static let empty = DietaryPreferences(
        selectedDiets: [],
        allergies: "",
        dislikedIngredients: ""
    )
}
