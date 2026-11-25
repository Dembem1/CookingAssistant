import SwiftUI
import FirebaseAuth

enum MyRecipesSection: String, CaseIterable {
    case saved = "Saved Recipes"
    case created = "Created Recipes"
}

struct MyRecipesView: View {
    let initialSection: MyRecipesSection
    @State private var selectedSection: MyRecipesSection
    
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]

    @EnvironmentObject var savedRecipesManager: SavedRecipesManager
    @EnvironmentObject var authService: AuthService
    
    @State private var createdRecipes: [FirestoreService.CreatedRecipeRecord] = []
    @State private var isManagingRecipes = false
    @State private var recipeToDelete: FirestoreService.CreatedRecipeRecord?
    
    @State private var deleteError: String?
    @State private var isDeletingRecipe = false
    @State private var isLoadingCreated = false
    @State private var createdRecipesError: String?

    init(
        initialSection: MyRecipesSection = .saved,
        pantryItems: Binding<[PantryItem]>,
        shoppingListItems: Binding<[ShoppingListItem]>
    ) {
        self.initialSection = initialSection
        self._selectedSection = State(initialValue: initialSection)
        self._pantryItems = pantryItems
        self._shoppingListItems = shoppingListItems
    }

    private var savedRecipes: [Recipe] {
        savedRecipesManager.savedRecipes.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 20) {

            Picker("Recipe section", selection: $selectedSection) {
                ForEach(MyRecipesSection.allCases, id: \.self) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isDeletingRecipe)
            
            if selectedSection == .saved {
                savedRecipesContent
            } else {
                createdRecipesContent
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 16)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("My Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
        .onChange(of: selectedSection) { _, newSection in
            if newSection == .created {
                loadCreatedRecipes()
            } else {
                refreshSavedRecipes()
            }
        }
        .onAppear {
            if selectedSection == .created {
                loadCreatedRecipes()
            } else {
                refreshSavedRecipes()
            }
        }    }

    // MARK: Saved Recipes
    @ViewBuilder
    private var savedRecipesContent: some View {
        if savedRecipesManager.isLoading {
            Spacer()
            ProgressView("Loading saved recipes...")
            Spacer()

        } else if let error = savedRecipesManager.errorMessage, savedRecipes.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load saved recipes", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { refreshSavedRecipes() }
            }
        } else if savedRecipes.isEmpty {
            emptyState(
                symbol: "bookmark",
                title: "No saved recipes yet",
                message: "Recipes you save will appear here."
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 280), spacing: 16)
                    ],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(savedRecipes) { recipe in
                        RecipePreview(
                            recipe: recipe,
                            pantryItems: $pantryItems,
                            shoppingListItems: $shoppingListItems
                        )
                    }
                }
            }
            .refreshable {
                refreshSavedRecipes()
                while savedRecipesManager.isLoading && !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { break }
                }
            }
        }
    }
    
    // MARK: Refresh Saved Recipes
    private func refreshSavedRecipes() {
        guard let userID = authService.user?.uid else {
            return
        }
        savedRecipesManager.loadSavedRecipes(
            for: userID
        )
    }
    
    // MARK: Load Created Recipe
    private func loadCreatedRecipes() {
        guard let userID = authService.user?.uid else {
            createdRecipes = []
            return
        }
        guard !isLoadingCreated, !isDeletingRecipe else { return }
        isLoadingCreated = true
        createdRecipesError = nil
        FirestoreService.shared.fetchCreatedRecipeRecords(
            for: userID
        ) { result in
            DispatchQueue.main.async {
                isLoadingCreated = false
                guard authService.user?.uid == userID else { return }
                switch result {
                case .success(let records):
                    createdRecipes = records.sorted {
                        $0.recipe.title.localizedCaseInsensitiveCompare(
                            $1.recipe.title
                        ) == .orderedAscending
                    }
                case .failure(let error):
                    createdRecipesError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: Empty State
    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(
                    AppTheme.primary
                )
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: Created Recipes
    private var createdRecipesContent: some View {
        VStack(spacing: 12) {
            // Create Recipe
            NavigationLink {
                CreateRecipeView()
            } label: {
                Label("Create Recipe", systemImage: "plus")
            }
            .buttonStyle(CookWisePrimaryButtonStyle())
            .disabled(isDeletingRecipe)
            // Manage Recipes
            Button {
                withAnimation(.easeInOut) {
                    isManagingRecipes.toggle()
                }
            } label: {
                HStack {
                    Image(
                        systemName: isManagingRecipes
                            ? "checkmark.circle.fill"
                            : "slider.horizontal.3"
                    )
                    Text(isManagingRecipes ? "Done" : "Manage Recipes")
                    Spacer()
                    Text(
                        isManagingRecipes
                            ? "Finish editing"
                            : "Edit or delete"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isDeletingRecipe)
            // Recipes
            Group {
                if isLoadingCreated && createdRecipes.isEmpty {
                    ProgressView("Loading your recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = createdRecipesError {
                    ContentUnavailableView {
                        Label(
                            "Couldn't Load Recipes",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            loadCreatedRecipes()
                        }
                    }
                } else if createdRecipes.isEmpty {
                    emptyState(
                        symbol: "book.closed",
                        title: "No created recipes yet",
                        message: "Recipes you publish will appear here."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(createdRecipes) { record in
                                VStack(spacing: 10) {
                                    RecipePreview(
                                        recipe: record.recipe,
                                        pantryItems: $pantryItems,
                                        shoppingListItems: $shoppingListItems
                                    )
                                    .disabled(isManagingRecipes)
                                    if isManagingRecipes {
                                        HStack(spacing: 12) {
                                            NavigationLink {
                                                CreateRecipeView(
                                                    editingRecord: record
                                                )
                                            } label: {
                                                editButtonLabel
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isDeletingRecipe)
                                            Button(role: .destructive) {
                                                recipeToDelete = record
                                            } label: {
                                                deleteButtonLabel
                                            }
                                            .disabled(isDeletingRecipe)
                                        }
                                        .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .refreshable {
                        loadCreatedRecipes()
                        while isLoadingCreated && !Task.isCancelled {
                            do { try await Task.sleep(for: .milliseconds(100)) }
                            catch { break }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: Binding(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Recipe", role: .destructive) {
                if let record = recipeToDelete {
                    deleteRecipe(record)
                }
            }
            Button("Cancel", role: .cancel) {
                recipeToDelete = nil
            }
        } message: {
            Text("This recipe will be permanently removed from My Recipes and the CookWise community.")
        }
        .alert(
            "Recipe Deletion Notice",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                deleteError = nil
            }
        } message: {
            Text(deleteError ?? "")
        }
    }
    
    // MARK: Delete Recipe
    @MainActor
    private func deleteRecipe(_ record: FirestoreService.CreatedRecipeRecord ) {
        guard let userID = authService.user?.uid else {
            deleteError = "You must be logged in to delete a recipe."
            return
        }
        guard !isDeletingRecipe else {
            return
        }
        isDeletingRecipe = true
        Task { @MainActor in
            defer {
                isDeletingRecipe = false
            }
            // Delete both Firestore documents first.
            let firestoreError: Error? =
                await withCheckedContinuation { continuation in
                    FirestoreService.shared.deleteCreatedRecipe(
                        documentID: record.documentID,
                        for: userID
                    ) { error in
                        continuation.resume(returning: error)
                    }
                }
            if let firestoreError {
                deleteError = firestoreError.localizedDescription
                print("Recipe deletion failed:", firestoreError)
                return
            }
            // Remove the recipe from the interface.
            createdRecipes.removeAll {
                $0.documentID == record.documentID
            }
            recipeToDelete = nil
            // Delete the associated Supabase images.
            let failedURLs = await StorageService.shared
                .deleteRecipeImages(for: record.recipe)
            if !failedURLs.isEmpty {
                deleteError = "The recipe was deleted, but some photos could not be removed."
                print(
                    "Failed image deletions:",
                    failedURLs.count
                )
            }
        }
    }
    
    // MARK: Management Actions
    private var editButtonLabel: some View {
        HStack {
            Image(systemName: "pencil")
            Text("Edit")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.sage)
        .foregroundStyle(AppTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var deleteButtonLabel: some View {
        HStack {
            Image(systemName: "trash")
            Text("Delete")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.10))
        .foregroundStyle(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
