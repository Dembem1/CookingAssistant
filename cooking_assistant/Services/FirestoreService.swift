import Foundation
import FirebaseFirestore

class FirestoreService {
    
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    
    struct CreatedRecipeRecord: Identifiable {

        let documentID: String
        let recipe: Recipe

        var id: String {
            documentID
        }
    }

    // MARK: Pantry Collection
    private func pantryCollection(for userID: String) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("pantry")
    }
    
    // MARK: Shopping List Collection
    private func shoppingListCollection(for userID: String) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("shoppingList")
    }
    
    
    // MARK: Saved Recipes Collection
    private func savedRecipesCollection(for userID: String) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("savedRecipes")
    }
    
    // MARK: Created Recipes Collection

    private func createdRecipesCollection(
        for userID: String
    ) -> CollectionReference {

        db.collection("users")
            .document(userID)
            .collection("createdRecipes")
    }

    // MARK: Community Recipes Collection

    private func communityRecipesCollection() -> CollectionReference {

        db.collection("communityRecipes")
    }
    
    // MARK: Dietary Preferences Collection
    private func dietaryPreferencesCollection(
        for userID: String
    ) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("preferences")
    }

    // MARK: Fetch Pantry Items
    func fetchPantryItems(
        for userID: String,
        completion: @escaping (Result<[PantryItem], Error>) -> Void
    ) {
        pantryCollection(for: userID).getDocuments { snapshot, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let items = documents.compactMap { document -> PantryItem? in
                let data = document.data()

                guard
                    let idString = data["id"] as? String,
                    let id = UUID(uuidString: idString),
                    let name = data["name"] as? String,
                    let amount = data["amount"] as? Double,
                    let unit = data["unit"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = PantryCategory(rawValue: categoryRawValue)
                else {
                    return nil
                }

                return PantryItem(
                    id: id,
                    name: name,
                    amount: amount,
                    unit: unit,
                    category: category
                )
            }

            completion(.success(items))
        }
    }
    
    // MARK: Fetch Shopping List Items
    func fetchShoppingListItems(
        for userID: String,
        completion: @escaping (Result<[ShoppingListItem], Error>) -> Void
    ) {
        shoppingListCollection(for: userID).getDocuments { snapshot, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let items = documents.compactMap { document -> ShoppingListItem? in
                let data = document.data()

                guard
                    let idString = data["id"] as? String,
                    let id = UUID(uuidString: idString),
                    let name = data["name"] as? String,
                    let amount = data["amount"] as? Double,
                    let unit = data["unit"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = PantryCategory(rawValue: categoryRawValue),
                    let isPurchased = data["isPurchased"] as? Bool
                else {
                    return nil
                }

                return ShoppingListItem(
                    id: id,
                    name: name,
                    amount: amount,
                    unit: unit,
                    category: category,
                    isPurchased: isPurchased
                )
            }

            completion(.success(items))
        }
    }

    // MARK: Add or Update Pantry Item
    func savePantryItem(
        _ item: PantryItem,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let data: [String: Any] = [
            "id": item.id.uuidString,
            "name": item.name,
            "amount": item.amount,
            "unit": item.unit,
            "category": item.category.rawValue
        ]

        pantryCollection(for: userID)
            .document(item.id.uuidString)
            .setData(data, merge: true) { error in
                completion?(error)
            }
    }
    
    // MARK: Add or Update Shopping List Item
    func saveShoppingListItem(
        _ item: ShoppingListItem,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let data: [String: Any] = [
            "id": item.id.uuidString,
            "name": item.name,
            "amount": item.amount,
            "unit": item.unit,
            "category": item.category.rawValue,
            "isPurchased": item.isPurchased
        ]

        shoppingListCollection(for: userID)
            .document(item.id.uuidString)
            .setData(data, merge: true) { error in
                completion?(error)
            }
    }
    
    // MARK: Delete Pantry Item
    func deletePantryItem(
        withID id: UUID,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        pantryCollection(for: userID)
            .document(id.uuidString)
            .delete { error in
                completion?(error)
            }
    }
    
    // MARK: Delete Shopping List Item
    func deleteShoppingListItem(
        withID id: UUID,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        shoppingListCollection(for: userID)
            .document(id.uuidString)
            .delete { error in
                completion?(error)
            }
    }
    
    // MARK: Save Recipe
    func saveRecipe(
        _ recipe: Recipe,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {

        do {
            let encodedRecipe = try JSONEncoder().encode(recipe)

            guard let recipeData = try JSONSerialization.jsonObject(
                with: encodedRecipe
            ) as? [String: Any] else {

                completion?(NSError(
                    domain: "FirestoreService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not encode recipe data."
                    ]
                ))
                return
            }

            savedRecipesCollection(for: userID)
                .document(String(recipe.id))
                .setData(recipeData) { error in
                    completion?(error)
                }

        } catch {
            completion?(error)
        }
    }
    
    // MARK: Publish Created Recipe
    func publishRecipe(
        _ recipe: Recipe,
        for userID: String,
        documentID: String = UUID().uuidString,
        completion: ((Error?) -> Void)? = nil
    ) {

        do {
            let encodedRecipe = try JSONEncoder().encode(recipe)

            guard var recipeData = try JSONSerialization.jsonObject(
                with: encodedRecipe
            ) as? [String: Any] else {

                completion?(NSError(
                    domain: "FirestoreService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not encode recipe data."
                    ]
                ))

                return
            }

            recipeData["creatorID"] = userID
            recipeData["createdAt"] = FieldValue.serverTimestamp()

            let batch = db.batch()

            let personalDocument = createdRecipesCollection(for: userID)
                .document(documentID)

            let communityDocument = communityRecipesCollection()
                .document(documentID)

            batch.setData(recipeData, forDocument: personalDocument)
            batch.setData(recipeData, forDocument: communityDocument)

            batch.commit { error in
                completion?(error)
            }

        } catch {
            completion?(error)
        }
    }
    
    // MARK: Update Created Recipe
    func updateCreatedRecipe(
        _ recipe: Recipe,
        documentID: String,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {

        do {

            let encodedRecipe = try JSONEncoder().encode(recipe)

            guard var recipeData = try JSONSerialization.jsonObject(
                with: encodedRecipe
            ) as? [String: Any] else {

                completion?(NSError(
                    domain: "FirestoreService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not encode updated recipe."
                    ]
                ))

                return
            }

            // Explicitly remove optional fields when needed.

            if recipe.imageURL == nil {
                recipeData["imageURL"] = FieldValue.delete()
            }

            if recipe.nutrition == nil {
                recipeData["nutrition"] = FieldValue.delete()
            }

            if recipe.instructionSteps == nil {
                recipeData["instructionSteps"] = FieldValue.delete()
            }

            recipeData["updatedAt"] = FieldValue.serverTimestamp()

            let personalDocument = createdRecipesCollection(
                for: userID
            )
            .document(documentID)

            let communityDocument = communityRecipesCollection()
                .document(documentID)

            let batch = db.batch()

            batch.updateData(
                recipeData,
                forDocument: personalDocument
            )

            batch.updateData(
                recipeData,
                forDocument: communityDocument
            )

            batch.commit { error in

                completion?(error)
            }

        } catch {

            completion?(error)
        }
    }
    
    // MARK: Delete Saved Recipe
    func deleteSavedRecipe(
        withID recipeID: Int,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {

        savedRecipesCollection(for: userID)
            .document(String(recipeID))
            .delete { error in
                completion?(error)
            }
    }

    // MARK: Check Whether Recipe Is Saved
    func isRecipeSaved(
        withID recipeID: Int,
        for userID: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {

        savedRecipesCollection(for: userID)
            .document(String(recipeID))
            .getDocument { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.exists ?? false))
            }
    }
    
    // MARK: Delete Created Recipe
    func deleteCreatedRecipe(
        documentID: String,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {

        let batch = db.batch()

        let personalDocument = createdRecipesCollection(for: userID)
            .document(documentID)

        let communityDocument = communityRecipesCollection()
            .document(documentID)

        batch.deleteDocument(personalDocument)
        batch.deleteDocument(communityDocument)

        batch.commit { error in
            completion?(error)
        }
    }

    // MARK: Fetch Saved Recipes
    func fetchSavedRecipes(
        for userID: String,
        completion: @escaping (Result<[Recipe], Error>) -> Void
    ) {

        savedRecipesCollection(for: userID)
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let recipes = documents.compactMap { document -> Recipe? in

                    do {

                        var data = document.data()

                        data.removeValue(forKey: "creatorID")
                        data.removeValue(forKey: "createdAt")
                        data.removeValue(forKey: "updatedAt")

                        guard JSONSerialization.isValidJSONObject(data) else {

                            print(
                                "Invalid saved recipe data:",
                                document.documentID
                            )

                            return nil
                        }

                        let jsonData = try JSONSerialization.data(
                            withJSONObject: data
                        )

                        return try JSONDecoder().decode(
                            Recipe.self,
                            from: jsonData
                        )
                    } catch {

                        print(
                            "Could not decode saved recipe:",
                            document.documentID,
                            error
                        )
                        return nil
                    }
                }
                completion(.success(recipes))
            }
    }
    
    // MARK: Compare Recipe Snapshots
    private func recipesAreEqual(
        _ first: Recipe,
        _ second: Recipe
    ) -> Bool {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let firstData = try? encoder.encode(first),
              let secondData = try? encoder.encode(second) else {
            return false
        }

        return firstData == secondData
    }
    
    // MARK: Refresh Saved Recipe Snapshot
    private func refreshSavedRecipeSnapshot(
        _ recipe: Recipe,
        for userID: String
    ) {

        do {
            let encodedRecipe = try JSONEncoder().encode(recipe)

            guard var recipeData = try JSONSerialization.jsonObject(
                with: encodedRecipe
            ) as? [String: Any] else {
                return
            }

            // Remove optional fields that no longer exist.
            if recipe.imageURL == nil {
                recipeData["imageURL"] = FieldValue.delete()
            }

            if recipe.nutrition == nil {
                recipeData["nutrition"] = FieldValue.delete()
            }

            if recipe.instructionSteps == nil {
                recipeData["instructionSteps"] = FieldValue.delete()
            }

            // Update an existing bookmark without recreating
            // a recipe that the user has already removed.
            savedRecipesCollection(for: userID)
                .document(String(recipe.id))
                .updateData(recipeData) { error in
                    if let error {
                        print("Saved recipe refresh failed:", error)
                    }
                }
        } catch {
            print("Could not encode updated saved recipe:", error)
        }
    }
    
    // MARK: Fetch Latest Saved Recipes
    func fetchLatestSavedRecipes(
        for userID: String,
        completion: @escaping (Result<[Recipe], Error>) -> Void
    ) {

        fetchSavedRecipes(for: userID) { result in

            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let savedRecipes):
                guard !savedRecipes.isEmpty else {
                    completion(.success([]))
                    return
                }

                // Community recipes use a separate numeric ID range.
                let hasCommunityRecipes = savedRecipes.contains {
                    $0.id >= 1_000_000_000
                }

                guard hasCommunityRecipes else {
                    completion(.success(savedRecipes))
                    return
                }

                self.fetchCommunityRecipes { communityResult in
                    switch communityResult {
                    case .success(let communityRecipes):
                        let communityByID = Dictionary(
                            communityRecipes.map {
                                ($0.id, $0)
                            },
                            uniquingKeysWith: { first, _ in first }
                        )

                        let updatedRecipes = savedRecipes.map { recipe in
                            // External and sample recipes retain their saved copies.
                            guard recipe.id >= 1_000_000_000,
                                  let latestRecipe = communityByID[recipe.id] else {
                                return recipe
                            }

                            // Persist the latest version only when its content changes.
                            if !self.recipesAreEqual(recipe, latestRecipe) {
                                self.refreshSavedRecipeSnapshot(
                                    latestRecipe,
                                    for: userID
                                )
                            }
                            return latestRecipe
                        }
                        completion(.success(updatedRecipes))

                    case .failure(let error):
                        // Preserve access to saved copies if
                        // the community collection cannot be loaded.
                        print(
                            "Could not refresh saved community recipes:",
                            error
                        )
                        completion(.success(savedRecipes))
                    }
                }
            }
        }
    }
    
    // MARK: Fetch Created Recipes

    func fetchCreatedRecipes(
        for userID: String,
        completion: @escaping (Result<[Recipe], Error>) -> Void
    ) {

        createdRecipesCollection(for: userID).getDocuments {
            snapshot, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let recipes = documents.compactMap { document -> Recipe? in

                do {
                    var data = document.data()

                    // Remove Firestore metadata before decoding Recipe.
                    data.removeValue(forKey: "creatorID")
                    data.removeValue(forKey: "createdAt")
                    data.removeValue(forKey: "updatedAt")
                    
                    // Skip malformed documents before JSON serialisation.
                    guard JSONSerialization.isValidJSONObject(data) else {
                        print("Invalid recipe data:", document.documentID)
                        return nil
                    }
                    
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data
                    )

                    return try JSONDecoder().decode(
                        Recipe.self,
                        from: jsonData
                    )

                } catch {
                    print(
                        "Could not decode created recipe:",
                        document.documentID,
                        error
                    )

                    return nil
                }
            }

            completion(.success(recipes))
        }
    }
    
    // MARK: Fetch Community Recipes
    func fetchCommunityRecipes(
        completion: @escaping (Result<[Recipe], Error>) -> Void
    ) {
        communityRecipesCollection()
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let recipes = documents.compactMap { document -> Recipe? in
                    do {
                        var data = document.data()

                        // Remove Firestore metadata before decoding.
                        data.removeValue(forKey: "creatorID")
                        data.removeValue(forKey: "createdAt")
                        data.removeValue(forKey: "updatedAt")
                        
                        // Skip malformed documents before JSON serialisation.
                        guard JSONSerialization.isValidJSONObject(data) else {
                            print("Invalid recipe data:", document.documentID)
                            return nil
                        }
                        
                        let jsonData = try JSONSerialization.data(
                            withJSONObject: data
                        )

                        return try JSONDecoder().decode(
                            Recipe.self,
                            from: jsonData
                        )

                    } catch {
                        print(
                            "Could not decode community recipe:",
                            document.documentID,
                            error
                        )

                        return nil
                    }
                }

                completion(.success(recipes))
            }
    }
    
    // MARK: Fetch Created Recipe Records
    func fetchCreatedRecipeRecords(
        for userID: String,
        completion: @escaping (Result<[CreatedRecipeRecord], Error>) -> Void
    ) {

        createdRecipesCollection(for: userID).getDocuments {
            snapshot, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let records = documents.compactMap { document -> CreatedRecipeRecord? in

                do {
                    var data = document.data()

                    data.removeValue(forKey: "creatorID")
                    data.removeValue(forKey: "createdAt")
                    data.removeValue(forKey: "updatedAt")
                    
                    // Skip malformed documents before JSON serialisation.
                    guard JSONSerialization.isValidJSONObject(data) else {
                        print("Invalid recipe data:", document.documentID)
                        return nil
                    }

                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data
                    )

                    let recipe = try JSONDecoder().decode(
                        Recipe.self,
                        from: jsonData
                    )

                    return CreatedRecipeRecord(
                        documentID: document.documentID,
                        recipe: recipe
                    )

                } catch {

                    print(
                        "Could not decode created recipe:",
                        document.documentID,
                        error
                    )

                    return nil
                }
            }

            completion(.success(records))
        }
    }
    
    // MARK: Save Dietary Preferences
    func saveDietaryPreferences(
        _ preferences: DietaryPreferences,
        for userID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let data: [String: Any] = [
            "selectedDiets": preferences.selectedDiets,
            "allergies": preferences.allergies,
            "dislikedIngredients": preferences.dislikedIngredients
        ]

        dietaryPreferencesCollection(for: userID)
            .document("dietary")
            .setData(data, merge: true) { error in
                completion?(error)
            }
    }

    // MARK: Fetch Dietary Preferences
    func fetchDietaryPreferences(
        for userID: String,
        completion: @escaping (Result<DietaryPreferences, Error>) -> Void
    ) {
        dietaryPreferencesCollection(for: userID)
            .document("dietary")
            .getDocument { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = snapshot?.data() else {
                    completion(.success(.empty))
                    return
                }

                let preferences = DietaryPreferences(
                    selectedDiets: data["selectedDiets"] as? [String] ?? [],
                    allergies: data["allergies"] as? String ?? "",
                    dislikedIngredients: data["dislikedIngredients"] as? String ?? ""
                )

                completion(.success(preferences))
            }
    }

}
