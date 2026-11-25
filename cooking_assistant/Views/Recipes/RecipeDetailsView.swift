import SwiftUI
import FirebaseAuth

struct RecipeDetailsView: View {
    // MARK: State and Dependencies
    let recipe: Recipe

    @State private var detailedRecipe: Recipe
    @State private var selectedServings: Int
    @State private var servingsInput: String
    @State private var isLoadingDetails = false
    @State private var errorMessage: String?

    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]
    @EnvironmentObject private var savedRecipesManager: SavedRecipesManager
    @EnvironmentObject private var authService: AuthService
    @FocusState private var isServingsFocused: Bool

    // MARK: Initialisation
    init(
        recipe: Recipe,
        pantryItems: Binding<[PantryItem]>,
        shoppingListItems: Binding<[ShoppingListItem]>
    ) {

        self.recipe = recipe
        self._pantryItems = pantryItems
        self._shoppingListItems = shoppingListItems

        let initialServings = min(max(recipe.servings, 1), 100)

        _detailedRecipe = State(initialValue: recipe)
        _selectedServings = State(initialValue: initialServings)
        _servingsInput = State(
            initialValue: String(initialServings)
        )
    }

    // MARK: Computed Properties
    private var isSaved: Bool {
        savedRecipesManager.isSaved(detailedRecipe.id)
    }

    private var hasRecipeDetails: Bool {
        !detailedRecipe.ingredients.isEmpty ||
        !detailedRecipe.instructions.isEmpty ||
        !(detailedRecipe.instructionSteps?.isEmpty ?? true)
    }

    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppTheme.sectionSpacing
            ) {
                headerSection
                nutritionSection
                loadingSection
                ingredientsSection
                Divider()
                instructionsSection
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                bookmarkButton
            }
        }
        .task {
            await loadRecipeDetails()
        }
    }

    // MARK: Recipe Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RecipeImageView(
                imageURL: detailedRecipe.imageURL,
                height: 250,
                cornerRadius: AppTheme.cornerRadius
            )

            Text(detailedRecipe.title)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.text)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 10) {
                recipeBadge(
                    title: "\(detailedRecipe.readyInMinutes) min",
                    symbol: "clock"
                )

                if let diet = detailedRecipe.diets.first {
                    recipeBadge(
                        title: diet.capitalized,
                        symbol: "leaf"
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func recipeBadge(title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.forest)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                AppTheme.sage,
                in: Capsule()
            )
    }

    // MARK: Bookmark
    private var bookmarkButton: some View {
        Button {
            guard let userID = authService.user?.uid else {
                return
            }
            
            savedRecipesManager.toggleSaved(
                detailedRecipe,
                for: userID
            )

        } label: {
            Image(
                systemName: isSaved
                    ? "bookmark.fill"
                    : "bookmark"
            )
            .foregroundStyle(AppTheme.primary)
        }
        .disabled(
            isLoadingDetails ||
            savedRecipesManager.isLoading ||
            (!hasRecipeDetails && !isSaved)
        )
        .accessibilityLabel(
            isSaved ? "Remove saved recipe" : "Save recipe"
        )
    }

    // MARK: Nutrition
    @ViewBuilder
    private var nutritionSection: some View {
        if let nutrition = detailedRecipe.nutrition,
           [
                nutrition.calories,
                nutrition.protein,
                nutrition.fat,
                nutrition.carbs
           ].contains(where: { $0 != nil }) {
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.pie")
                        .foregroundStyle(AppTheme.primary)

                    Text("Nutrition per serving")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {

                    nutritionItem(
                        title: "Calories",
                        value: nutrition.calories,
                        unit: "kcal"
                    )

                    nutritionItem(
                        title: "Protein",
                        value: nutrition.protein,
                        unit: "g"
                    )

                    nutritionItem(
                        title: "Fat",
                        value: nutrition.fat,
                        unit: "g"
                    )

                    nutritionItem(
                        title: "Carbs",
                        value: nutrition.carbs,
                        unit: "g"
                    )
                }

                Text(
                    "Values are approximate and shown per serving."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.cornerRadius
                )
            )
        }
    }

    private func nutritionItem(title: String, value: Double?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text(
                value.map {
                    "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
                } ?? "Not available"
            )
            .font(.headline)
            .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.smallCornerRadius
            )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Loading and Error States
    @ViewBuilder
    private var loadingSection: some View {
        if isLoadingDetails {
            ProgressView("Loading recipe details...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }

        if let errorMessage {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    errorMessage,
                    systemImage: "exclamationmark.circle"
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                
                Button("Try Again") {
                    Task {
                        await loadRecipeDetails()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cookWiseCard()
        }
    }

    // MARK: Ingredients
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ingredients")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)
            servingsSelector

            if detailedRecipe.ingredients.isEmpty {
                Text("No ingredients available.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(detailedRecipe.ingredients.enumerated()),
                        id: \.offset
                    ) { index, ingredient in
                        ingredientRow(ingredient)
                        if index < detailedRecipe.ingredients.count - 1 {
                            Divider()
                        }
                    }
                }
                .cookWiseCard(padding: 14)

                NavigationLink {
                    CompareIngredientsView(
                        recipe: detailedRecipe,
                        selectedServings: selectedServings,
                        pantryItems: $pantryItems,
                        shoppingListItems: $shoppingListItems
                    )
                } label: {
                    Label(
                        "Compare Ingredients",
                        systemImage: "checklist"
                    )
                }
                .buttonStyle(CookWisePrimaryButtonStyle())
            }
        }
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        // Scale quantities relative to the original recipe servings.
        let adjustedAmount =
            ingredient.amount *
            Double(selectedServings) /
            Double(max(detailedRecipe.servings, 1))

        return HStack(alignment: .firstTextBaseline, spacing: 12) {

            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(AppTheme.primary)
            
            Text(ingredient.name.capitalized)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(
                "\(adjustedAmount.formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unit)"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Servings Selector
    private var servingsSelector: some View {
        HStack(spacing: 12) {
            Label(
                "Servings",
                systemImage: "person.2"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.text)

            Spacer(minLength: 4)
            
            HStack(spacing: 8) {

                servingsButton(
                    symbol: "minus",
                    disabled: selectedServings <= 1
                ) {
                    updateServings(selectedServings - 1)
                }

                TextField(
                    "2",
                    text: $servingsInput
                )
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($isServingsFocused)
                .frame(width: 42)
                .accessibilityLabel("Number of servings")
                .onChange(of: servingsInput) { _, newValue in

                    let digits = newValue.filter {
                        $0.isNumber
                    }

                    if digits != newValue {
                        servingsInput = digits
                        return
                    }

                    if let value = Int(digits) {
                        selectedServings = min(
                            max(value, 1),
                            100
                        )

                        if value > 100 {
                            servingsInput = "100"
                        }
                    }
                }
                .onChange(of: isServingsFocused) { _, focused in
                    if !focused {servingsInput = String(selectedServings)}
                }
                servingsButton(
                    symbol: "plus",
                    disabled: selectedServings >= 100
                ) {
                    updateServings(selectedServings + 1)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.smallCornerRadius
            )
        )
    }

    private func servingsButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    disabled
                        ? AppTheme.secondaryText
                        : AppTheme.primary
                )
                .frame(width: 44, height: 44)
                .background(
                    AppTheme.background,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(
            symbol == "plus"
                ? "Increase servings"
                : "Decrease servings"
        )
    }

    private func updateServings(_ value: Int) {
        let newValue = min(max(value, 1), 100)
        selectedServings = newValue
        servingsInput = String(newValue)
    }

    // MARK: Cooking Instructions
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {

            Text("Cooking Instructions")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)

            if let steps = detailedRecipe.instructionSteps,
               !steps.isEmpty {
                ForEach(
                    Array(steps.enumerated()),
                    id: \.element.id
                ) { index, step in
                    instructionRow(
                        number: index + 1,
                        text: step.text,
                        imageURL: step.imageURL
                    )
                }
            } else if !detailedRecipe.instructions.isEmpty {
                // Support external and older text-only recipes.
                ForEach(
                    Array(
                        detailedRecipe.instructions.enumerated()
                    ),
                    id: \.offset
                ) { index, instruction in
                    instructionRow(
                        number: index + 1,
                        text: instruction,
                        imageURL: nil
                    )
                }
            } else {
                Text("No instructions available.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func instructionRow(number: Int, text: String, imageURL: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        AppTheme.buttonBackground,
                        in: Circle()
                    )

                Text("Step \(number)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if let imageURL {
                RecipeImageView(
                    imageURL: imageURL,
                    height: 200,
                    cornerRadius: AppTheme.smallCornerRadius,
                    placeholderSymbol: "photo"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cookWiseCard()
    }

    // MARK: Load Recipe Details
    @MainActor
    private func loadRecipeDetails() async {
        // Community and sample recipes already contain their details.
        // Only request additional data for incomplete recipes.

        guard !hasRecipeDetails,
              !isLoadingDetails,
              !Task.isCancelled else {
            return
        }

        isLoadingDetails = true
        errorMessage = nil

        defer {isLoadingDetails = false}

        do {
            let result = try await SpoonacularService()
                .getRecipeInformation(id: recipe.id)

            guard !Task.isCancelled else {
                return
            }

            detailedRecipe = result
            updateServings(result.servings)

        } catch {
            guard !Task.isCancelled else {
                return
            }

            errorMessage = "Could not load full recipe details. Please try again."
            print("Recipe details error:", error)
        }
    }
}
