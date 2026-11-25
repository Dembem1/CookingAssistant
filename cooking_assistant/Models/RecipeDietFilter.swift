import Foundation

struct RecipeDietFilter {

    static func matches(
        _ recipe: Recipe,
        selectedDiets: Set<String>
    ) -> Bool {

        guard !selectedDiets.isEmpty else {
            return true
        }

        let ingredients = recipe.ingredients.map {
            $0.name.lowercased()
        }

        // Alternative diets: OR logic
        let alternativeDiets = selectedDiets.filter {
            ["Vegetarian", "Vegan", "Pescatarian", "Keto"]
                .contains($0)
        }

        if !alternativeDiets.isEmpty {
            let recipeDiets = Set(
                recipe.diets.map { $0.lowercased() }
            )

            let dietMapping: [String: String] = [
                "Vegetarian": "vegetarian",
                "Vegan": "vegan",
                "Pescatarian": "pescetarian",
                "Keto": "ketogenic"
            ]

            let matchesAlternative = alternativeDiets.contains {
                diet in
                guard let expected = dietMapping[diet] else {
                    return false
                }

                return recipeDiets.contains(expected)
            }

            if !matchesAlternative {
                return false
            }
        }

        // Restrictions: AND logic
        if selectedDiets.contains("Gluten-Free") {
            let glutenIngredients = [
                "wheat", "flour", "pasta", "bread",
                "barley", "rye", "couscous", "seitan"
            ]

            if ingredients.contains(where: { ingredient in
                glutenIngredients.contains {
                    ingredient.contains($0)
                }
            }) {
                return false
            }
        }

        if selectedDiets.contains("Dairy-Free") {
            let dairyIngredients = [
                "milk", "cream", "cheese", "butter",
                "yogurt", "yoghurt", "parmesan",
                "mozzarella", "cheddar", "whey"
            ]

            if ingredients.contains(where: { ingredient in
                dairyIngredients.contains {
                    ingredient.contains($0)
                }
            }) {
                return false
            }
        }

        // Do not claim nutritional suitability without nutrition data.
        if selectedDiets.contains("Low-Carb") ||
            selectedDiets.contains("Low-Fat") {
            return false
        }

        return true
    }
}
