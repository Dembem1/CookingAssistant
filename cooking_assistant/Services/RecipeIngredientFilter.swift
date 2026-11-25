import Foundation

struct RecipeIngredientFilter {
    static func matches(_ recipe: Recipe, preferences: DietaryPreferences) -> Bool {

        let restrictedIngredients = (
            preferences.allergies + "," +
            preferences.dislikedIngredients
        )
        .split(separator: ",")
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        .filter { !$0.isEmpty }

        // No restrictions: allow the recipe.
        guard !restrictedIngredients.isEmpty else {
            return true
        }
        
        // Without ingredient data, restrictions cannot be checked.
        guard !recipe.ingredients.isEmpty else {
            return false
        }

        let recipeIngredients = recipe.ingredients.map {
            $0.name.lowercased()
        }

        // Exclude recipes containing restricted ingredients.
        let containsRestrictedIngredient = recipeIngredients.contains {
            ingredient in

            restrictedIngredients.contains { restricted in
                ingredient.contains(restricted)
            }
        }

        return !containsRestrictedIngredient
    }
}
