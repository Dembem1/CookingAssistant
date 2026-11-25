import Foundation

nonisolated struct Recipe: Identifiable, Codable, Sendable {
    let id: Int
    let title: String
    let readyInMinutes: Int
    let diets: [String]
    let imageURL: String?
    let servings: Int
    let ingredients: [Ingredient]
    let instructions: [String]
    let nutrition: NutritionInfo?
    let instructionSteps: [RecipeInstruction]? // Optional detailed instructions with photos

    
    init(
        id: Int,
        title: String,
        readyInMinutes: Int,
        diets: [String],
        imageURL: String?,
        servings: Int,
        ingredients: [Ingredient],
        instructions: [String],
        nutrition: NutritionInfo? = nil,
        instructionSteps: [RecipeInstruction]? = nil
    ) {
        self.id = id
        self.title = title
        self.readyInMinutes = readyInMinutes
        self.diets = diets
        self.imageURL = imageURL
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.nutrition = nutrition
        self.instructionSteps = instructionSteps
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case readyInMinutes
        case diets
        case imageURL
        case servings
        case ingredients
        case instructions
        case instructionSteps
        case nutrition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        readyInMinutes = try container.decode(Int.self, forKey: .readyInMinutes)
        diets = try container.decode([String].self, forKey: .diets)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        servings = try container.decode(Int.self, forKey: .servings)
        ingredients = try container.decode([Ingredient].self, forKey: .ingredients)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
        instructionSteps = try container.decodeIfPresent([RecipeInstruction].self, forKey: .instructionSteps)
        nutrition = try container.decodeIfPresent(NutritionInfo.self, forKey: .nutrition)
    }
}

