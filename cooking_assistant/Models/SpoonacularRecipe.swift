import Foundation

struct SpoonacularRecipeResponse: Decodable {
    let results: [SpoonacularRecipe]
}

struct SpoonacularRecipe: Decodable, Identifiable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let diets: [String]?
    let nutrition: SpoonacularNutrition?
    

    func toRecipe() -> Recipe {
        Recipe(
            id: id,
            title: title,
            readyInMinutes: readyInMinutes ?? 0,
            diets: diets ?? [],
            imageURL: image,
            servings: servings ?? 1,
            ingredients: [],
            instructions: [],
            nutrition: nutrition?.toNutritionInfo()
        )
    }
}

struct SpoonacularRecipeInformation: Decodable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let diets: [String]?
    let nutrition: SpoonacularNutrition?
    let extendedIngredients: [SpoonacularIngredient]?
    let analyzedInstructions: [SpoonacularInstructionGroup]?
    let instructions: String?

    func toRecipe() -> Recipe {
        let ingredients = (extendedIngredients ?? []).map { item in
            Ingredient(
                name: item.originalName ?? item.name ?? "Unknown ingredient",
                amount: item.amount,
                unit: item.unit
            )
        }

        let steps = analyzedInstructions?
            .flatMap { $0.steps }
            .sorted { $0.number < $1.number }
            .map { $0.step } ?? []

        let finalInstructions: [String]

        if !steps.isEmpty {
            finalInstructions = steps
        } else if let instructions, !instructions.isEmpty {
            finalInstructions = [
                instructions.replacingOccurrences(
                    of: "<[^>]+>",
                    with: "",
                    options: .regularExpression
                )
            ]
        } else {
            finalInstructions = []
        }

        return Recipe(
            id: id,
            title: title,
            readyInMinutes: readyInMinutes ?? 0,
            diets: diets ?? [],
            imageURL: image,
            servings: max(servings ?? 1, 1),
            ingredients: ingredients,
            instructions: finalInstructions,
            nutrition: nutrition?.toNutritionInfo()
        )
    }
}

struct SpoonacularIngredient: Decodable {
    let amount: Double
    let unit: String
    let name: String?
    let originalName: String?
}

struct SpoonacularInstructionGroup: Decodable {
    let steps: [SpoonacularInstructionStep]
}

struct SpoonacularInstructionStep: Decodable {
    let number: Int
    let step: String
}

struct SpoonacularRandomRecipeResponse: Decodable {
    let recipes: [SpoonacularRecipeInformation]
}

struct SpoonacularNutrition: Decodable {
    let nutrients: [SpoonacularNutrient]?
}

struct SpoonacularNutrient: Decodable {
    let name: String
    let amount: Double
    let unit: String
}

extension SpoonacularNutrition {
    func toNutritionInfo() -> NutritionInfo {
        func amount(for nutrientName: String) -> Double? {
            nutrients?.first {
                $0.name.caseInsensitiveCompare(nutrientName) == .orderedSame
            }?.amount
        }

        return NutritionInfo(
            calories: amount(for: "Calories"),
            protein: amount(for: "Protein"),
            fat: amount(for: "Fat"),
            carbs: amount(for: "Carbohydrates")
        )
    }
}
