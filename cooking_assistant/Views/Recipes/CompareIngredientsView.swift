import SwiftUI
import FirebaseAuth

enum IngredientUnit {

    // Converts supported units into a common base unit.
    // Volume -> ml, weight -> g, count -> pieces.

    private static let units: [String: (type: String, factor: Double)] = [
        // Volume
        "ml": ("volume", 1),
        "milliliter": ("volume", 1),
        "milliliters": ("volume", 1),

        "l": ("volume", 1000),
        "liter": ("volume", 1000),
        "liters": ("volume", 1000),
        "litre": ("volume", 1000),
        "litres": ("volume", 1000),

        "tsp": ("volume", 5),
        "teaspoon": ("volume", 5),
        "teaspoons": ("volume", 5),

        "tbsp": ("volume", 15),
        "tablespoon": ("volume", 15),
        "tablespoons": ("volume", 15),

        // Weight
        "g": ("weight", 1),
        "gram": ("weight", 1),
        "grams": ("weight", 1),

        "kg": ("weight", 1000),
        "kilogram": ("weight", 1000),
        "kilograms": ("weight", 1000),

        // Count
        "piece": ("count", 1),
        "pieces": ("count", 1),
        "pc": ("count", 1),
        "pcs": ("count", 1)
    ]

    private static func normalized(_ unit: String) -> String {
        unit.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func canConvert(_ first: String, _ second: String) -> Bool {
        let firstUnit = normalized(first)
        let secondUnit = normalized(second)

        // In sample recipes, an empty unit means a countable ingredient.
        let firstUnitToCheck = firstUnit.isEmpty ? "pieces" : firstUnit
        let secondUnitToCheck = secondUnit.isEmpty ? "pieces" : secondUnit

        guard let firstInfo = units[firstUnitToCheck],
              let secondInfo = units[secondUnitToCheck] else {
            return firstUnitToCheck == secondUnitToCheck
        }
        return firstInfo.type == secondInfo.type
    }

    static func convert(_ amount: Double, from sourceUnit: String, to targetUnit: String) -> Double? {
        let source = normalized(sourceUnit)
        let target = normalized(targetUnit)

        let sourceToCheck = source.isEmpty ? "pieces" : source
        let targetToCheck = target.isEmpty ? "pieces" : target

        if sourceToCheck == targetToCheck {
            return amount
        }

        guard let sourceInfo = units[sourceToCheck],
              let targetInfo = units[targetToCheck],
              sourceInfo.type == targetInfo.type else {
            return nil
        }

        let baseAmount = amount * sourceInfo.factor
        return baseAmount / targetInfo.factor
    }
}

struct CompareIngredientsView: View {

    @EnvironmentObject var authService: AuthService
    private let firestoreService = FirestoreService()
    
    let recipe: Recipe
    let selectedServings: Int
    
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]
    
    @State private var showingError = false
    @State private var errorMessage = ""

    // Calculate the required amount for the selected servings
    private func requiredAmount(for ingredient: Ingredient) -> Double {
        ingredient.amount
            * Double(selectedServings)
            / Double(recipe.servings)
    }

    // Calculate how much of an ingredient is available
    private func availableAmount(for ingredient: Ingredient) -> Double {

        let recipeName = ingredient.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let compatibleItems = pantryItems.filter { item in

            let pantryName = item.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return pantryName == recipeName
                && IngredientUnit.canConvert(item.unit, ingredient.unit)
        }

        let totalAmount = compatibleItems.reduce(0.0) { total, item in

            let convertedAmount = IngredientUnit.convert(
                item.amount,
                from: item.unit,
                to: ingredient.unit
            ) ?? 0

            return total + convertedAmount
        }

        return min(totalAmount, requiredAmount(for: ingredient))
    }

    // Calculate how much is missing
    private func missingAmount(for ingredient: Ingredient) -> Double {
        requiredAmount(for: ingredient)
            - availableAmount(for: ingredient)
    }

    private var availableIngredients: [Ingredient] {
        recipe.ingredients.filter { ingredient in
            missingAmount(for: ingredient) == 0
        }
    }

    private var missingIngredients: [Ingredient] {
        recipe.ingredients.filter { ingredient in
            missingAmount(for: ingredient) > 0
        }
    }
    
    
    private func addMissingIngredientsToShoppingList() {
        guard let userID = authService.user?.uid else {
            errorMessage = "You need to be logged in to update your Shopping List."
            showingError = true
            return
        }
        // Remember existing document IDs before merging.
        let previousIDs = Set(shoppingListItems.map { $0.id })
        // Remember the names of ingredients being added.
        var affectedNames = Set<String>()
        for ingredient in missingIngredients {
            let amountToAdd = missingAmount(for: ingredient)
            let normalizedName = ingredient.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            affectedNames.insert(normalizedName)
            // Find the ingredient in Pantry to reuse its category.
            let pantryItem = pantryItems.first { item in
                let pantryName = item.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return pantryName == normalizedName
                    && IngredientUnit.canConvert(item.unit, ingredient.unit)
            }
            let newItem = ShoppingListItem(
                name: ingredient.name,
                amount: amountToAdd,
                unit: ingredient.unit,
                category: pantryItem?.category ?? .other
            )
            // Preserve the existing merging and unit conversion logic.
            ShoppingListManager.addOrMerge(
                newItem,
                into: &shoppingListItems
            )
        }
        // Find the final versions of all affected items.
        let affectedItems = shoppingListItems.filter { item in
            let normalizedName = item.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return affectedNames.contains(normalizedName)
        }
        // Save the new or updated items to Firestore.
        for item in affectedItems {
            firestoreService.saveShoppingListItem(
                item,
                for: userID
            ) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
        // Delete duplicate documents removed by addOrMerge.
        let currentIDs = Set(shoppingListItems.map { $0.id })
        let removedIDs = previousIDs.subtracting(currentIDs)
        for id in removedIDs {
            firestoreService.deleteShoppingListItem(
                withID: id,
                for: userID
            ) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    // MARK: Comparison Screen
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.text)
                    Label("\(selectedServings) servings", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                summaryCard
                comparisonSection(title: "Ingredients you already have", items: availableIngredients, isAvailable: true)
                comparisonSection(title: "Ingredients to buy", items: missingIngredients, isAvailable: false)
                Button {
                    addMissingIngredientsToShoppingList()
                } label: {
                    Label("Add missing ingredients to Shopping List", systemImage: "cart.badge.plus")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(CookWisePrimaryButtonStyle())
                .disabled(missingIngredients.isEmpty)
            }
            .padding(AppTheme.screenPadding)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
        .navigationTitle("Compare Ingredients")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't Update Shopping List", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kitchen check")
                .font(.headline)
                .foregroundStyle(AppTheme.forest)
            Text("\(availableIngredients.count) of \(recipe.ingredients.count) ingredients available in full")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
            ProgressView(value: Double(availableIngredients.count), total: Double(max(recipe.ingredients.count, 1)))
                .tint(AppTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.sage, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func comparisonSection(title: String, items: [Ingredient], isAvailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Text(isAvailable ? "You don't have any of these ingredients in full yet." : "You have everything you need!")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, ingredient in
                        ingredientRow(ingredient, amount: isAvailable ? requiredAmount(for: ingredient) : missingAmount(for: ingredient), isAvailable: isAvailable)
                        if index < items.count - 1 { Divider() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cookWiseCard()
        }
    }

    private func ingredientRow(_ ingredient: Ingredient, amount: Double, isAvailable: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "cart")
                .foregroundStyle(isAvailable ? AppTheme.primary : AppTheme.secondaryText)
                .accessibilityHidden(true)
            Text(ingredient.name.capitalized)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(amount.formatted(.number.precision(.fractionLength(0...4)))) \(ingredient.unit)")
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
