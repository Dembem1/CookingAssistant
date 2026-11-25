import Foundation
import Combine

class SavedRecipesManager: ObservableObject {

    @Published private(set) var savedRecipes: [Int: Recipe] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService()

    private var currentUserID: String?
    private var pendingRecipeIDs = Set<Int>()
    
    private var loadRequestID = UUID()
    private var sessionID = UUID()

    // MARK: Check Saved State
    func isSaved(_ recipeID: Int) -> Bool {
        savedRecipes[recipeID] != nil
    }

    // MARK: Load Saved Recipes
    func loadSavedRecipes(for userID: String) {

        guard pendingRecipeIDs.isEmpty else {
            return
        }

        if currentUserID != userID {
            clear()
            currentUserID = userID
        }

        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        errorMessage = nil

        firestoreService.fetchLatestSavedRecipes(for: userID) { [weak self] result in
            DispatchQueue.main.async {

                guard let self = self,
                      self.currentUserID == userID,
                      self.loadRequestID == requestID else {
                    return
                }

                self.isLoading = false
                
                switch result {
                case .success(let recipes):
                    self.savedRecipes = Dictionary(
                        recipes.map {
                            ($0.id, $0)
                        },
                        uniquingKeysWith: { first, _ in first }
                    )

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: Toggle Saved Recipe
    func toggleSaved(_ recipe: Recipe, for userID: String) {

        guard currentUserID == userID,
              !isLoading,
              !pendingRecipeIDs.contains(recipe.id) else {
            return
        }

        let activeSessionID = sessionID
        pendingRecipeIDs.insert(recipe.id)
        errorMessage = nil

        if isSaved(recipe.id) {
            // Optimistically remove the recipe from the interface.

            let removedRecipe = savedRecipes.removeValue(
                forKey: recipe.id
            )

            firestoreService.deleteSavedRecipe(withID: recipe.id, for: userID) { [weak self] error in
                DispatchQueue.main.async {

                    guard let self = self,
                          self.currentUserID == userID,
                          self.sessionID == activeSessionID else {

                        return
                    }

                    self.pendingRecipeIDs.remove(recipe.id)

                    if let error = error {
                        // Restore the recipe if deletion failed.
                        if let removedRecipe {
                            self.savedRecipes[recipe.id] = removedRecipe
                        }

                        self.errorMessage = error.localizedDescription
                    }
                }
            }

        } else {
            // Optimistically save the recipe in the interface.
            savedRecipes[recipe.id] = recipe
            
            firestoreService.saveRecipe(recipe, for: userID) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self,
                          self.currentUserID == userID,
                          self.sessionID == activeSessionID else {

                        return
                    }
                    
                    self.pendingRecipeIDs.remove(recipe.id)
                    if let error = error {
                        // Roll back the local change if saving failed.
                        self.savedRecipes.removeValue(
                            forKey: recipe.id
                        )

                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: Clear Data on Logout
    func clear() {
        // Invalidate callbacks from previous requests and sessions.
        loadRequestID = UUID()
        sessionID = UUID()
        currentUserID = nil
        savedRecipes = [:]
        isLoading = false
        errorMessage = nil
        pendingRecipeIDs = []
    }
}
