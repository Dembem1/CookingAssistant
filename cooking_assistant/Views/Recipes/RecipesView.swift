import SwiftUI
import FirebaseAuth


enum RecipeSortOption: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case quickest = "Quickest"
    case alphabetical = "A–Z"

    var id: String {
        rawValue
    }
}

struct RecipesView: View {
    @Binding var searchQuery: String
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]

    @State private var spoonacularRecipes: [Recipe] = []
    @State private var communityRecipes: [Recipe] = []
    @State private var isLoadingCommunity = false
    @State private var communityErrorMessage: String?
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var selectedSort: RecipeSortOption = .recommended
    @EnvironmentObject var authService: AuthService

    @State private var dietaryPreferences: DietaryPreferences = .empty
    @State private var showingFilters = false
    
    
    @State private var currentOffset = 0
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var searchRequestID = UUID()
    
    // MARK: Active Dietary Filters
    @State private var activeDiets: Set<String> = []

    private let availableDiets = [
        "Vegetarian",
        "Vegan",
        "Pescatarian",
        "Gluten-Free",
        "Dairy-Free",
        "Keto",
        "Low-Carb",
        "Low-Fat"
    ]
    
    @State private var hasLoadedPreferences = false
    @State private var preferencesLoadFailed = false
    @State private var selectedMaxCookingTime: Int? = nil

    private let cookingTimeOptions: [(title: String, minutes: Int?)] = [
        ("Any time", nil),
        ("Up to 15 min", 15),
        ("Up to 30 min", 30),
        ("Up to 45 min", 45),
        ("Up to 60 min", 60)
    ]
    
    private var displayedRecipes: [Recipe] {
        guard hasLoadedPreferences && !preferencesLoadFailed else {
            return []
        }

        // MARK: External Recipes
        let externalRecipes: [Recipe]

        if !spoonacularRecipes.isEmpty {
            externalRecipes = spoonacularRecipes
        } else {
            externalRecipes = RecipeSearch.filter(
                SampleRecipes.all,
                query: searchQuery
            )
        }

        // MARK: Community Recipes
        let matchingCommunityRecipes = RecipeSearch.filter(
            communityRecipes,
            query: searchQuery
        )

        // MARK: Combine Recipes
        let combinedRecipes = matchingCommunityRecipes + externalRecipes

        // Prevent duplicate recipe IDs.
        var seenIDs = Set<Int>()

        let recipes = combinedRecipes.filter { recipe in
            seenIDs.insert(recipe.id).inserted
        }

        // Personal restrictions apply only when browsing,
        // not when searching for a specific recipe.
        let recipesAfterPersonalRestrictions: [Recipe]

        if searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            recipesAfterPersonalRestrictions = recipes.filter { recipe in
                RecipeIngredientFilter.matches(
                    recipe,
                    preferences: dietaryPreferences
                )
            }
        } else {
            recipesAfterPersonalRestrictions = recipes
        }

        // Manually selected dietary filters always apply.
        let filteredRecipes = recipesAfterPersonalRestrictions.filter { recipe in
            RecipeDietFilter.matches(
                recipe,
                selectedDiets: activeDiets
            )
        }

        // Cooking time filter.
        let timeFilteredRecipes = filteredRecipes.filter { recipe in
            guard let maxTime = selectedMaxCookingTime else {
                return true
            }

            return recipe.readyInMinutes <= maxTime
        }

        // MARK: Sorting
        switch selectedSort {

        case .recommended:
            return timeFilteredRecipes

        case .quickest:
            return timeFilteredRecipes.sorted {
                $0.readyInMinutes < $1.readyInMinutes
            }

        case .alphabetical:
            return timeFilteredRecipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title)
                    == .orderedAscending
            }
        }
    }
    
    private struct SearchParameters: Equatable {
        let query: String
        let diets: Set<String>
    }

    private var searchParameters: SearchParameters {
        SearchParameters(query: searchQuery, diets: activeDiets)
    }
    
    @FocusState private var isSearchFocused: Bool

    private var activeFilterCount: Int {
        (selectedMaxCookingTime == nil ? 0 : 1) + activeDiets.count
    }

    // MARK: Body
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading,spacing: 20) {
                        Color.clear
                            .frame(height: 1)
                            .id("recipesTop")

                        headerSection
                        searchSection
                        createRecipeButton
                        sortingSection
                        filtersSection
                        resultsSection
                        messagesSection
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.vertical, 16)
                    .padding(.bottom, 60)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {await refreshRecipes()}

                Button {
                    withAnimation(.smooth) {

                        proxy.scrollTo(
                            "recipesTop",
                            anchor: .top
                        )
                    }

                } label: {
                    Image(systemName: "arrow.up")
                        .font(
                            .system(size: 18, weight: .semibold)
                        )
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            AppTheme.buttonBackground,
                            in: Circle()
                        )
                        .shadow(
                            color: .black.opacity(0.12),
                            radius: 5,
                            y: 3
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .accessibilityLabel("Back to top")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {await refreshRecipes()}
        }
        .task(id: searchParameters) {
            do {
                try await Task.sleep(
                    for: .milliseconds(500)
                )

                guard !Task.isCancelled,
                      hasLoadedPreferences,
                      !preferencesLoadFailed else {
                    return
                }

                await loadRecipes()

            } catch {
                // A newer search has replaced this task.
                return
            }
        }
    }
    
    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text("Discover Recipes")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)

            Text("Find your favourite dish")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: Recipe Search
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)

            TextField(
                "Search recipes...",
                text: $searchQuery
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isSearchFocused)
            .submitLabel(.search)
            .onSubmit {isSearchFocused = false}

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.secondaryText)
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
    }

    // MARK: Create Recipe
    private var createRecipeButton: some View {
        NavigationLink {
            CreateRecipeView()
        } label: {
            Label(
                "Create Recipe",
                systemImage: "plus"
            )
        }
        .buttonStyle(CookWisePrimaryButtonStyle())
    }
    
    // MARK: Sorting
    private var sortingSection: some View {
        HStack {
            Text("Sort by")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Picker("Sort by", selection: $selectedSort) {
                ForEach(RecipeSortOption.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.primary)
        }
    }
    
    // MARK: Recipe Filters
    private var filtersSection: some View {
        DisclosureGroup(isExpanded: $showingFilters) {
            VStack(alignment: .leading, spacing: 18) {
                cookingTimeFilters

                Divider()

                dietaryFilters

                Divider()

                HStack {
                    Button("Reset filters") {
                        selectedMaxCookingTime = nil
                        activeDiets = []
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)

                    Spacer()

                    Button("Done") {
                        withAnimation {
                            showingFilters = false
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
            
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(AppTheme.primary)

                Text("Filters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.forest)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            AppTheme.sage,
                            in: Capsule()
                        )
                }

                Spacer()
            }
        }
        .tint(AppTheme.primary)
        .cookWiseCard()
    }

    // MARK: Cooking Time Filters
    private var cookingTimeFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cooking Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {

                ForEach(cookingTimeOptions, id: \.minutes) { option in
                    Button {
                        selectedMaxCookingTime = option.minutes

                    } label: {
                        filterOption(
                            title: option.title,
                            isSelected:
                                selectedMaxCookingTime == option.minutes
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selectedMaxCookingTime == option.minutes
                            ? .isSelected
                            : []
                    )
                }
            }
        }
    }

    // MARK: Dietary Filters
    private var dietaryFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dietary Preferences")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                ForEach(availableDiets, id: \.self) { diet in
                    Button {
                        if activeDiets.contains(diet) {
                            activeDiets.remove(diet)
                        } else {
                            activeDiets.insert(diet)
                        }

                    } label: {
                        filterOption(
                            title: diet,
                            isSelected: activeDiets.contains(diet)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        activeDiets.contains(diet)
                            ? .isSelected
                            : []
                    )
                }
            }
        }
    }

    // MARK: Shared Filter Option
    private func filterOption(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
            }

            Text(title)
                .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 42)
        .padding(.horizontal, 4)
        .foregroundStyle(
            isSelected ? AppTheme.forest : AppTheme.secondaryText
        )
        .background(
            isSelected ? AppTheme.sage : AppTheme.surface
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.smallCornerRadius
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AppTheme.smallCornerRadius
            )
            .strokeBorder(
                isSelected ? AppTheme.primary : AppTheme.border,
                lineWidth: 1
            )
        }
    }
    
    // MARK: Recipe Results
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading || isLoadingCommunity {
                ProgressView("Loading recipes...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                
            } else if preferencesLoadFailed {
                emptyState(
                    title: "Couldn’t load recipes",
                    message: "Please try loading your preferences again.",
                    symbol: "wifi.exclamationmark"
                )

                Button("Try Again") {
                    Task {await refreshRecipes()}
                }
                .buttonStyle(CookWisePrimaryButtonStyle())

            } else if displayedRecipes.isEmpty {
                emptyState(
                    title: "No recipes found",
                    message: "Try another search or adjust your filters.",
                    symbol: "magnifyingglass"
                )

            } else {
                Text("Recipes")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.text)
                    .accessibilityAddTraits(.isHeader)

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
            }

            // Additional pages may contain matching recipes
            // even when the current page is filtered out.
            if !isLoading,
               !isLoadingCommunity,
               hasLoadedPreferences,
               !preferencesLoadFailed,
               canLoadMore,
               !spoonacularRecipes.isEmpty {

                loadMoreButton
            }
        }
    }

    // MARK: Empty State
    private func emptyState(title: String, message: String, symbol: String ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.primary)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .cookWiseCard()
    }

    // MARK: Pagination
    private var loadMoreButton: some View {
        Button {
            Task {await loadMoreRecipes()}
        } label: {
            HStack(spacing: 10) {
                if isLoadingMore {
                    ProgressView()
                        .tint(.white)
                }

                Text(
                    isLoadingMore
                        ? "Loading..."
                        : "Load More Recipes"
                )
            }
        }
        .buttonStyle(CookWisePrimaryButtonStyle())
        .disabled(isLoadingMore)
    }

    // MARK: Loading Messages
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if let communityErrorMessage {
                Text(communityErrorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    
    // MARK: Refresh Recipe Catalogue
    @MainActor
    private func refreshRecipes() async {
        hasLoadedPreferences = false
        preferencesLoadFailed = false
        errorMessage = nil

        await loadDietaryPreferences()

        guard hasLoadedPreferences,
              !preferencesLoadFailed,
              !Task.isCancelled else {
            return
        }

        await loadCommunityRecipes()
        await loadRecipes()
    }
    
    // MARK: Load Community Recipes
    @MainActor
    private func loadCommunityRecipes() async {
        guard !isLoadingCommunity else { return }

        isLoadingCommunity = true
        communityErrorMessage = nil

        defer {
            isLoadingCommunity = false
        }

        let result: Result<[Recipe], Error> =
            await withCheckedContinuation { continuation in
                FirestoreService.shared.fetchCommunityRecipes { result in
                    continuation.resume(returning: result)
                }
            }

        switch result {
        case .success(let recipes):
            communityRecipes = recipes

        case .failure(let error):
            communityErrorMessage = "Could not load community recipes. Please try again."
            print("Community recipes error:", error)
        }
    }

    // MARK: Load Recipes
    @MainActor
    private func loadRecipes() async {

        guard hasLoadedPreferences,
              !Task.isCancelled else {
            return
        }

        // Identify the latest search request.
        let requestID = UUID()
        searchRequestID = requestID

        // Capture the search parameters.
        let query = searchQuery
        let preferences = dietaryPreferences
        let diets = activeDiets

        isLoadingMore = false
        currentOffset = 0
        canLoadMore = true
        spoonacularRecipes = []
        isLoading = true
        errorMessage = nil

        defer {
            if searchRequestID == requestID {
                isLoading = false
            }
        }
        do {
            let results = try await SpoonacularService()
                .searchRecipes(
                    query: query,
                    preferences: preferences,
                    activeDiets: diets,
                    applyPersonalRestrictions: false,
                    offset: 0
                )

            // Ignore outdated or cancelled search results.
            guard searchRequestID == requestID,
                  !Task.isCancelled,
                  searchQuery == query,
                  activeDiets == diets else {
                return
            }

            canLoadMore = results.count >= 20

            spoonacularRecipes = results.map {
                $0.toRecipe()
            }

            if results.isEmpty {
                errorMessage = "No recipes returned by Spoonacular. Showing available recipes."
            }

        } catch {
            guard searchRequestID == requestID,
                  !Task.isCancelled,
                  searchQuery == query,
                  activeDiets == diets else {
                return
            }

            spoonacularRecipes = []
            canLoadMore = false
            errorMessage = "Could not load recipes from Spoonacular. Showing available recipes."

            print("Spoonacular error:", error)
        }
    }
    
    // MARK: Load More Recipes
    @MainActor
    private func loadMoreRecipes() async {
        guard !isLoading,
              !isLoadingMore,
              canLoadMore,
              !spoonacularRecipes.isEmpty else {
            return
        }

        let requestID = searchRequestID
        let query = searchQuery
        let preferences = dietaryPreferences
        let diets = activeDiets
        let nextOffset = currentOffset + 20

        isLoadingMore = true
        errorMessage = nil

        defer {
            if searchRequestID == requestID {
                isLoadingMore = false
            }
        }

        do {
            let results = try await SpoonacularService()
                .searchRecipes(
                    query: query,
                    preferences: preferences,
                    activeDiets: diets,
                    applyPersonalRestrictions: false,
                    offset: nextOffset
                )

            // Prevent results from an outdated search
            // being appended to the current recipe list.
            guard searchRequestID == requestID,
                  !Task.isCancelled,
                  searchQuery == query,
                  activeDiets == diets else {
                return
            }

            let newRecipes = results.map {
                $0.toRecipe()
            }

            var existingIDs = Set(
                spoonacularRecipes.map { $0.id }
            )

            let uniqueNewRecipes = newRecipes.filter {
                existingIDs.insert($0.id).inserted
            }

            spoonacularRecipes.append(contentsOf: uniqueNewRecipes)
            currentOffset = nextOffset
            canLoadMore = results.count >= 20

        } catch {
            guard searchRequestID == requestID,
                  !Task.isCancelled,
                  searchQuery == query,
                  activeDiets == diets else {
                return
            }

            errorMessage = "Could not load more recipes. Please try again."
            print("Spoonacular pagination error:", error)
        }
    }

    @MainActor
    private func loadDietaryPreferences() async {

        guard let userID = authService.user?.uid else {
            preferencesLoadFailed = true
            errorMessage = "Please log in to load your dietary preferences."
            return
        }

        let firestoreService = FirestoreService.shared

        let result: Result<DietaryPreferences, Error> = await withCheckedContinuation { continuation in
                firestoreService.fetchDietaryPreferences(for: userID) {
                    result in
                    continuation.resume(returning: result)
                }
            }

        switch result {
            case .success(let preferences):
                dietaryPreferences = preferences

                activeDiets = Set(preferences.selectedDiets)
                hasLoadedPreferences = true
                preferencesLoadFailed = false

            case .failure(let error):
                preferencesLoadFailed = true
                errorMessage = "Could not load dietary preferences: \(error.localizedDescription)"
        }
    }
}
