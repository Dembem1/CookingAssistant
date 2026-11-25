import Foundation

struct SpoonacularService {
    private let apiKey = Secrets.spoonacularAPIKey
    private let baseURL = "https://api.spoonacular.com"

    func searchRecipes(
        query: String,
        preferences: DietaryPreferences,
        activeDiets: Set<String>,
        applyPersonalRestrictions: Bool = true,
        offset: Int = 0
    ) async throws -> [SpoonacularRecipe] {

        let dietMapping: [String: String] = [
            "Vegetarian": "vegetarian",
            "Vegan": "vegan",
            "Pescatarian": "pescetarian",
            "Keto": "ketogenic"
        ]

        let intoleranceMapping: [String: String] = [
            "Gluten-Free": "gluten",
            "Dairy-Free": "dairy"
        ]

        var intolerances: [String] = []
        var excludedIngredients: [String] = []

        if applyPersonalRestrictions {

            intolerances = activeDiets.compactMap {
                intoleranceMapping[$0]
            }

            let allergyNames = preferences.allergies
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }

            let dislikedNames = preferences.dislikedIngredients
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }

            let knownIntolerances = [
                "peanut", "egg", "gluten", "dairy", "sesame",
                "seafood", "shellfish", "soy", "sulfite",
                "tree nut", "wheat"
            ]

            for allergy in allergyNames {
                let normalised = allergy.lowercased()

                if knownIntolerances.contains(normalised) {
                    intolerances.append(normalised)
                }
            }

            intolerances = Array(Set(intolerances))

            excludedIngredients = Array(
                Set(allergyNames + dislikedNames)
            )
        }

        let selectedApiDiets = activeDiets.compactMap {
            dietMapping[$0]
        }

        // No alternative diet selected: make one general search.
        let dietsToSearch: [String?] =
            selectedApiDiets.isEmpty
            ? [nil]
            : selectedApiDiets.map { Optional($0) }

        var allRecipes: [SpoonacularRecipe] = []

        for diet in dietsToSearch {
            let recipes = try await fetchRecipes(
                query: query,
                diet: diet,
                intolerances: intolerances,
                excludedIngredients: excludedIngredients,
                offset: offset
            )

            allRecipes.append(contentsOf: recipes)
        }

        // Remove duplicates using the recipe ID.
        var seenIDs = Set<Int>()

        let uniqueRecipes = allRecipes.filter { recipe in
            seenIDs.insert(recipe.id).inserted
        }

        return uniqueRecipes
    }

    private func fetchRecipes(
        query: String,
        diet: String?,
        intolerances: [String],
        excludedIngredients: [String],
        offset: Int
    ) async throws -> [SpoonacularRecipe] {

        var components = URLComponents(
            string: "\(baseURL)/recipes/complexSearch"
        )

        var queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: "20"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "addRecipeNutrition", value: "true")
        ]

        if let diet {
            queryItems.append(
                URLQueryItem(name: "diet", value: diet)
            )
        }

        if !intolerances.isEmpty {
            queryItems.append(
                URLQueryItem(
                    name: "intolerances",
                    value: intolerances.joined(separator: ",")
                )
            )
        }

        if !excludedIngredients.isEmpty {
            queryItems.append(
                URLQueryItem(
                    name: "excludeIngredients",
                    value: excludedIngredients.joined(separator: ",")
                )
            )
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            print(
                "Spoonacular HTTP Status:",
                httpResponse.statusCode
            )

            throw NSError(
                domain: "SpoonacularService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not load recipes. Please try again later."
                ]
            )
        }

        let decodedResponse = try JSONDecoder().decode(
            SpoonacularRecipeResponse.self,
            from: data
        )

        return decodedResponse.results
    }

    
    func getRandomRecipes(number: Int = 6, preferences: DietaryPreferences) async throws -> [Recipe] {
        var components = URLComponents(
            string: "\(baseURL)/recipes/random"
        )

        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "includeNutrition", value: "true")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decodedResponse = try JSONDecoder().decode(
            SpoonacularRandomRecipeResponse.self,
            from: data
        )

        let recipes = decodedResponse.recipes.map {
            $0.toRecipe()
        }

        return recipes.filter { recipe in
            RecipeIngredientFilter.matches(
                recipe,
                preferences: preferences
            )
        }
    }
    
    func getRecipeInformation(id: Int) async throws -> Recipe {
        var components = URLComponents(
            string: "\(baseURL)/recipes/\(id)/information"
        )

        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "includeNutrition", value: "true")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let details = try JSONDecoder().decode(
            SpoonacularRecipeInformation.self,
            from: data
        )

        return details.toRecipe()
    }

}
