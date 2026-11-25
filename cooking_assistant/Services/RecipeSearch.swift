import Foundation

enum RecipeSearch {
    static func filter(
        _ recipes: [Recipe],
        query: String
    ) -> [Recipe] {
        let searchText = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !searchText.isEmpty else {
            return recipes
        }

        return recipes.filter { recipe in
            recipe.title.lowercased().contains(searchText)
            || recipe.diets.contains {
                $0.lowercased().contains(searchText)
            }
        }
    }
}
