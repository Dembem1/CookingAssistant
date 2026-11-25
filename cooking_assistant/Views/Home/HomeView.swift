import SwiftUI
import FirebaseAuth

struct HomeView: View {

    // MARK: State and Dependencies
    @State private var searchText = ""

    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var savedRecipesManager: SavedRecipesManager

    @State private var recommendedRecipes: [Recipe] = []
    @State private var isLoadingRecommendations = false
    @State private var recommendationError: String?

    @State private var dietaryPreferences: DietaryPreferences = .empty
    @State private var hasLoadedPreferences = false
    @State private var preferencesLoadFailed = false

    @FocusState private var isSearchFocused: Bool

    let onFindRecipes: (String) -> Void
    let onShowIngredients: () -> Void

    var onShowProfile: (() -> Void)? = nil

    // MARK: Computed Properties
    private var greeting: String {
        guard let name = authService.user?.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return "Welcome!"
        }

        let firstName = name.split(separator: " ").first
            .map(String.init) ?? name
        return "Hello, \(firstName)"
    }

    private var displayedRecipes: [Recipe] {
        guard hasLoadedPreferences,
              !preferencesLoadFailed else {
            return []
        }

        let recipes = recommendedRecipes.isEmpty
            ? SampleRecipes.all
            : recommendedRecipes
        
        return recipes.filter { recipe in
            RecipeIngredientFilter.matches(recipe, preferences: dietaryPreferences)
        }
    }

    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppTheme.sectionSpacing
            ) {
                
                headerSection
                searchSection
                ingredientsSection
                personalRecipesSection
                recommendationsSection
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRecommendedRecipes()
        }
        .refreshable {
            await loadRecommendedRecipes()
        }
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {

                Text("Cooking Assistant")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.primary)

                Text(greeting)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.text)
                    .accessibilityAddTraits(.isHeader)

                Text("What’s cooking today?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 8)

            if let onShowProfile {
                Button(action: onShowProfile) {
                    profileIcon
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")

            } else {
                profileIcon
                    .accessibilityHidden(true)
            }
        }
    }

    private var profileIcon: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 27, weight: .medium))
            .foregroundStyle(AppTheme.primary)
            .frame(width: 48, height: 48)
            .background(AppTheme.sage, in: Circle())
    }

    // MARK: Recipe Search
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)

                TextField(
                    "Search recipes...",
                    text: $searchText
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    findRecipes()
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(
                                AppTheme.secondaryText
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(15)
            .background(AppTheme.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.smallCornerRadius
                )
            )

            Button {
                findRecipes()
            } label: {
                Label(
                    "Find Recipes",
                    systemImage: "magnifyingglass"
                )
            }
            .buttonStyle(CookWisePrimaryButtonStyle())
        }
    }

    private func findRecipes() {
        isSearchFocused = false
        
        onFindRecipes(
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }

    // MARK: Ingredients Shortcut
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "basket")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 48, height: 48)
                    .background(
                        AppTheme.background,
                        in: RoundedRectangle(
                            cornerRadius: 14
                        )
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("What’s in your kitchen?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.forest)
                    Text("Keep track of your ingredients and discover what you can make.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                ingredientCounter(
                    title: "In your pantry",
                    count: pantryItems.count,
                    symbol: "shippingbox"
                )
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 32)
                ingredientCounter(
                    title: "To buy",
                    count: shoppingListItems.filter {
                        !$0.isPurchased
                    }.count,
                    symbol: "cart"
                )
            }

            Divider()

            Button(action: onShowIngredients) {
                HStack {
                    Text("View My Ingredients")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.sage)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.cornerRadius
            )
        )
    }

    private func ingredientCounter(title: String, count: Int, symbol: String
    ) -> some View {

        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text(count.formatted())
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Personal Recipes
    private var personalRecipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your recipes")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 12) {
                NavigationLink {

                    MyRecipesView(
                        initialSection: .saved,
                        pantryItems: $pantryItems,
                        shoppingListItems: $shoppingListItems
                    )
                } label: {
                    HomeShortcut(
                        title: "Saved Recipes",
                        subtitle: "Your favourites",
                        symbol: "bookmark"
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    MyRecipesView(
                        initialSection: .created,
                        pantryItems: $pantryItems,
                        shoppingListItems: $shoppingListItems
                    )
                } label: {
                    HomeShortcut(
                        title: "My Recipes",
                        subtitle: "Your creations",
                        symbol: "book.closed"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Recommendations
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    
                    Text("Recommended for you")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.text)
                        .accessibilityAddTraits(.isHeader)

                    Text("Ideas based on your preferences")
                        .font(.caption)
                        .foregroundStyle(
                            AppTheme.secondaryText
                        )
                }

                Spacer(minLength: 8)

                Button {
                    onFindRecipes("")
                } label: {
                    Text("See all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }

            if isLoadingRecommendations {
                ProgressView("Loading recommendations...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                if displayedRecipes.isEmpty {
                    recommendationEmptyState
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: 280),
                                spacing: 16
                            )
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(displayedRecipes) { recipe in

                            RecipePreview(
                                recipe: recipe,
                                pantryItems: $pantryItems,
                                shoppingListItems: $shoppingListItems
                            )
                        }
                    }

                    if let recommendationError {
                        Text(recommendationError)
                            .font(.caption)
                            .foregroundStyle(
                                AppTheme.secondaryText
                            )
                    }
                }
            }
        }
    }

    private var recommendationEmptyState: some View {
        VStack(spacing: 12) {
            Image(
                systemName: preferencesLoadFailed
                    ? "wifi.exclamationmark"
                    : "fork.knife"
            )
            .font(.system(size: 30))
            .foregroundStyle(AppTheme.primary)

            Text(
                preferencesLoadFailed
                    ? "Couldn’t load recommendations"
                    : "No matching recipes"
            )
            .font(.headline)
            .foregroundStyle(AppTheme.text)

            Text(
                recommendationError ??
                "Try adjusting your dietary preferences."
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await loadRecommendedRecipes()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.primary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .cookWiseCard()
    }

    // MARK: Load Recommendations
    @MainActor
    private func loadRecommendedRecipes() async {
        guard !isLoadingRecommendations,
              !Task.isCancelled else {
            return
        }

        isLoadingRecommendations = true
        recommendationError = nil

        defer {
            isLoadingRecommendations = false
        }

        // Reload dietary preferences before requesting recipes.
        await loadDietaryPreferences()

        guard hasLoadedPreferences,
              !preferencesLoadFailed,
              !Task.isCancelled else {
            return
        }

        do {
            let recipes = try await SpoonacularService()
                .getRandomRecipes(
                    number: 6,
                    preferences: dietaryPreferences
                )
            
            guard !Task.isCancelled else {
                return
            }

            recommendedRecipes = recipes

            if recipes.isEmpty {
                recommendationError = "No matching recommendations available. Showing suitable sample recipes."
            }

        } catch {
            guard !Task.isCancelled else {
                return
            }

            recommendedRecipes = []

            // Keep the dietary filter applied to fallback recipes.
            recommendationError = "Could not load recommendations. Showing suitable sample recipes."
            print("Spoonacular recommendations error:", error)
        }
    }

    // MARK: Load Dietary Preferences
    @MainActor
    private func loadDietaryPreferences() async {
        hasLoadedPreferences = false
        preferencesLoadFailed = false

        guard let userID = authService.user?.uid else {
            preferencesLoadFailed = true
            recommendationError = "Please log in to load your dietary preferences."
            return
        }

        let result: Result<DietaryPreferences, Error> =
            await withCheckedContinuation { continuation in
                FirestoreService.shared.fetchDietaryPreferences(for: userID ) { result in
                    continuation.resume(returning: result)
                }
            }

        guard authService.user?.uid == userID,
              !Task.isCancelled else {
            return
        }

        switch result {
        case .success(let preferences):
            dietaryPreferences = preferences
            hasLoadedPreferences = true

        case .failure(let error):
            preferencesLoadFailed = true
            recommendationError = "Could not load dietary preferences."

            print("Dietary preferences error:", error)
        }
    }
}

// MARK: Home Shortcut Card
struct HomeShortcut: View {
    
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.sage)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cookWiseCard()
        .contentShape(Rectangle())
    }
}
