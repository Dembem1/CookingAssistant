import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

// MARK: Draft Ingredient
struct DraftIngredient: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var unit = "g"
}

// MARK: Draft Instruction
struct DraftInstruction: Identifiable {

    let id: UUID
    var text: String
    var selectedPhoto: PhotosPickerItem?
    var image: UIImage?
    var existingImageURL: String?
    var isLoadingPhoto = false
    var photoError: String?

    init(
        id: UUID = UUID(),
        text: String = "",
        existingImageURL: String? = nil
    ) {
        self.id = id
        self.text = text
        self.existingImageURL = existingImageURL
    }
}

// MARK: Create Recipe View
struct CreateRecipeView: View {
    private let editingRecord: FirestoreService.CreatedRecipeRecord?
    private var isEditing: Bool {
        editingRecord != nil
    }

    // MARK: Recipe Details
    @State private var recipeName = ""
    @State private var cookingTime = 30
    @State private var servings = 2
    @State private var selectedDiets: Set<String> = []
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recipeImage: UIImage?
    @State private var existingImageURL: String?
    @State private var isLoadingMainPhoto = false
    @State private var mainPhotoError: String? = nil
    @State private var instructions: [DraftInstruction] = [DraftInstruction()]
    
    @State private var isPublishing = false
    @State private var showPublishError = false
    @State private var publishErrorMessage = ""
    @State private var showCleanupWarning = false
    @State private var showDiscardConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: Nutrition
    @State private var caloriesInput = ""
    @State private var proteinInput = ""
    @State private var fatInput = ""
    @State private var carbsInput = ""

    // MARK: Ingredients
    @State private var ingredients: [DraftIngredient] = [
        DraftIngredient()
    ]

    // MARK: Initialisation
    init(editingRecord: FirestoreService.CreatedRecipeRecord? = nil ) {
        self.editingRecord = editingRecord
        guard let recipe = editingRecord?.recipe else {
            return
        }
        // Basic recipe information.
        _recipeName = State(initialValue: recipe.title)
        _cookingTime = State(initialValue: recipe.readyInMinutes)
        _servings = State(initialValue: recipe.servings)
        _selectedDiets = State(initialValue: Set(recipe.diets))
        _existingImageURL = State(initialValue: recipe.imageURL)
        // Nutrition information.
        _caloriesInput = State(
            initialValue: recipe.nutrition?.calories.map {
                String($0)
            } ?? ""
        )
        _proteinInput = State(
            initialValue: recipe.nutrition?.protein.map {
                String($0)
            } ?? ""
        )
        _fatInput = State(
            initialValue: recipe.nutrition?.fat.map {
                String($0)
            } ?? ""
        )
        _carbsInput = State(
            initialValue: recipe.nutrition?.carbs.map {
                String($0)
            } ?? ""
        )
        // Ingredients.
        let draftIngredients = recipe.ingredients.map {
            ingredient in
            DraftIngredient(
                name: ingredient.name,
                amount: String(ingredient.amount),
                unit: ingredient.unit
            )
        }
        _ingredients = State(
            initialValue: draftIngredients.isEmpty
                ? [DraftIngredient()]
                : draftIngredients
        )
        // Instructions.
        let draftInstructions: [DraftInstruction]
        if let steps = recipe.instructionSteps,
           !steps.isEmpty {
            draftInstructions = steps.map { step in
                DraftInstruction(
                    id: step.id,
                    text: step.text,
                    existingImageURL: step.imageURL
                )
            }
        } else {
            // Support older recipes with text-only instructions.
            draftInstructions = recipe.instructions.map {
                text in
                DraftInstruction(text: text)
            }
        }
        _instructions = State(
            initialValue: draftInstructions.isEmpty
                ? [DraftInstruction()]
                : draftInstructions
        )
    }

    // MARK: Validation
    private var isLoadingInstructionPhotos: Bool {
        instructions.contains {
            $0.isLoadingPhoto
        }
    }
    private var areInstructionPhotosValid: Bool {
        instructions.allSatisfy { step in
            guard step.photoError == nil else {
                return false
            }
            if step.image != nil ||
                step.existingImageURL != nil {
                return !step.text.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }
            return true
        }
    }
    private var isFormValid: Bool {
        let hasValidName = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidCookingTime = (1...300).contains(cookingTime)
        let hasValidServings = (1...20).contains(servings)
        let filledIngredients = ingredients.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !$0.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let hasValidIngredients =
            !filledIngredients.isEmpty &&
            filledIngredients.allSatisfy { ingredient in
                let name = ingredient.name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let amount = Double(
                    ingredient.amount.replacingOccurrences(
                        of: ",",
                        with: "."
                    )
                ) ?? 0
                return !name.isEmpty &&
                    amount.isFinite &&
                    amount > 0
            }
        let hasInstructions = instructions.contains {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasValidName &&
            hasValidCookingTime &&
            hasValidServings &&
            hasValidIngredients &&
            hasInstructions &&
            isNutritionInputValid &&
            !isLoadingInstructionPhotos &&
            areInstructionPhotosValid &&
            !isLoadingMainPhoto &&
            mainPhotoError == nil
    }
    private func nutritionValue(from input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
    private var isNutritionInputValid: Bool {
        let inputs = [
            caloriesInput,
            proteinInput,
            fatInput,
            carbsInput
        ]
        return inputs.allSatisfy { input in
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return true
            }
            guard let value = nutritionValue(from: trimmed) else {
                return false
            }
            return value.isFinite && value >= 0
        }
    }
    private var recipeNutrition: NutritionInfo? {
        let nutrition = NutritionInfo(
            calories: nutritionValue(from: caloriesInput),
            protein: nutritionValue(from: proteinInput),
            fat: nutritionValue(from: fatInput),
            carbs: nutritionValue(from: carbsInput)
        )
        let hasValues = [
            nutrition.calories,
            nutrition.protein,
            nutrition.fat,
            nutrition.carbs
        ].contains { $0 != nil }
        return hasValues ? nutrition : nil
    }
    private let ingredientUnits = [
        "g",
        "kg",
        "ml",
        "l",
        "tsp",
        "tbsp",
        "cup",
        "piece",
        "clove",
        "pinch",
        "oz",
        "lb"
    ]
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

    // MARK: Load Main Recipe Photo
    @MainActor
    private func loadSelectedPhoto(_ photo: PhotosPickerItem) async {
        do {
            guard let imageData = try await photo
                .loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                throw StorageServiceError.imageConversionFailed
            }
            guard selectedPhoto == photo else {
                return
            }
            recipeImage = image
            isLoadingMainPhoto = false
            mainPhotoError = nil
        } catch {
            guard selectedPhoto == photo else {
                return
            }
            isLoadingMainPhoto = false
            mainPhotoError = "Could not load the selected photo."
            print("Main photo error:", error)
        }
    }

    // MARK: Load Instruction Photo
    @MainActor
    private func loadInstructionPhoto(
        for instructionID: UUID,
        selectedPhoto: PhotosPickerItem
    ) async {
        do {
            guard let imageData = try await selectedPhoto
                .loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                throw StorageServiceError.imageConversionFailed
            }
            guard let index = instructions.firstIndex(
                where: { $0.id == instructionID }
            ),
            instructions[index].selectedPhoto == selectedPhoto else {
                return
            }
            instructions[index].image = image
            instructions[index].isLoadingPhoto = false
            instructions[index].photoError = nil
        } catch {
            guard let index = instructions.firstIndex(
                where: { $0.id == instructionID }
            ),
            instructions[index].selectedPhoto == selectedPhoto else {
                return
            }
            instructions[index].isLoadingPhoto = false
            instructions[index].photoError = "Could not load the selected photo."
            print("Instruction photo error:", error)
        }
    }

    // MARK: Collect Recipe Image URLs
    private func imageURLs(for recipe: Recipe) -> Set<String> {
        var urls = Set<String>()
        if let imageURL = recipe.imageURL {
            urls.insert(imageURL)
        }
        for step in recipe.instructionSteps ?? [] {
            if let imageURL = step.imageURL {
                urls.insert(imageURL)
            }
        }
        return urls
    }

    // MARK: Publish or Update Recipe
    @MainActor
    private func publishRecipe() {
        guard !isPublishing else {
            return
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            publishErrorMessage = "You must be logged in to save a recipe."
            showPublishError = true
            return
        }
        guard isFormValid else {
            publishErrorMessage = "Please complete all required fields and correct invalid values."
            showPublishError = true
            return
        }
        isPublishing = true
        // Preserve existing IDs when editing.
        let documentID =
            editingRecord?.documentID ?? UUID().uuidString
        let recipeID =
            editingRecord?.recipe.id ??
            Int.random(in: 1_000_000_000...Int.max)
        let originalRecipe = editingRecord?.recipe
    
    // MARK: Prepare Ingredients
        let recipeIngredients = ingredients.compactMap {
            ingredient -> Ingredient? in
            let name = ingredient.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let amountText = ingredient.amount
                .replacingOccurrences(of: ",", with: ".")
            let amount = Double(amountText) ?? 0
            guard !name.isEmpty,
                  amount.isFinite,
                  amount > 0 else {
                return nil
            }
            return Ingredient(
                name: name,
                amount: amount,
                unit: ingredient.unit
            )
        }
    
    // MARK: Prepare Instructions
        let validDraftInstructions = instructions.filter {
            !$0.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
        let validInstructions = validDraftInstructions.map {
            $0.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        // Capture form values before uploading.
        let title = recipeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let recipeCookingTime = cookingTime
        let recipeServings = servings
        let recipeDiets = availableDiets.filter {selectedDiets.contains($0)}
        let nutrition = recipeNutrition
        let selectedImage = recipeImage
        let previousMainImageURL = existingImageURL
        Task { @MainActor in
            var uploadedImageURLs: [String] = []
            var mainImageURL = previousMainImageURL
            var recipeInstructionSteps: [RecipeInstruction] = []
            defer {
                isPublishing = false
            }
            do {
            
    // MARK: Upload New Main Photo
                if let selectedImage {
                    let imageURL = try await StorageService.shared
                        .uploadRecipeImage(
                            selectedImage,
                            userID: userID,
                            recipeDocumentID: documentID
                        )
                    mainImageURL = imageURL
                    uploadedImageURLs.append(imageURL)
                }
            
    // MARK: Prepare Instruction Steps
                for draftStep in validDraftInstructions {
                    // Keep the existing photo unless replaced.
                    var stepImageURL = draftStep.existingImageURL
                    if let stepImage = draftStep.image {
                        let imageURL = try await StorageService.shared
                            .uploadRecipeImage(
                                stepImage,
                                userID: userID,
                                recipeDocumentID: documentID,
                                instructionID: draftStep.id
                            )
                        stepImageURL = imageURL
                        uploadedImageURLs.append(imageURL)
                    }
                    let instructionStep = RecipeInstruction(
                        id: draftStep.id,
                        text: draftStep.text.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        imageURL: stepImageURL
                    )
                    recipeInstructionSteps.append(
                        instructionStep
                    )
                }
            
    // MARK: Build Recipe
                let updatedRecipe = Recipe(
                    id: recipeID,
                    title: title,
                    readyInMinutes: recipeCookingTime,
                    diets: recipeDiets,
                    imageURL: mainImageURL,
                    servings: recipeServings,
                    ingredients: recipeIngredients,
                    instructions: validInstructions,
                    nutrition: nutrition,
                    instructionSteps: recipeInstructionSteps
                )
            
    // MARK: Save to Firestore
                let publicationError: Error? =
                    await withCheckedContinuation { continuation in
                        if isEditing {
                            FirestoreService.shared.updateCreatedRecipe(
                                updatedRecipe,
                                documentID: documentID,
                                for: userID
                            ) { error in
                                continuation.resume(returning: error)
                            }
                        } else {
                            FirestoreService.shared.publishRecipe(
                                updatedRecipe,
                                for: userID,
                                documentID: documentID
                            ) { error in
                                continuation.resume(returning: error)
                            }
                        }
                    }
                if let publicationError {
                    throw publicationError
                }
            
    // MARK: Remove Old Unused Images
                // Firestore has been updated successfully.
                // Only now is it safe to delete old images.
                var cleanupFailed = false
                if let originalRecipe {
                    let originalURLs = imageURLs(
                        for: originalRecipe
                    )
                    let updatedURLs = imageURLs(
                        for: updatedRecipe
                    )
                    let unusedURLs = originalURLs.subtracting(
                        updatedURLs
                    )
                    for imageURL in unusedURLs {
                        do {
                            try await StorageService.shared.deleteImage(
                                at: imageURL
                            )
                        } catch {
                            cleanupFailed = true
                            print("Old image cleanup failed:", error)
                        }
                    }
                }
                if cleanupFailed {
                    showCleanupWarning = true
                } else {
                    dismiss()
                }
            } catch {
                // Remove only images uploaded during this attempt.
                // Existing recipe images remain untouched.
                for imageURL in uploadedImageURLs {
                    do {
                        try await StorageService.shared.deleteImage(
                            at: imageURL
                        )
                    } catch {
                        print("Image cleanup failed:", error)
                    }
                }
                publishErrorMessage = error.localizedDescription
                showPublishError = true
                print("Recipe save failed:", error)
            }
        }
    }

    // MARK: Body
    var body: some View {
        Form {
            basicInformationSection
            dietarySection
            nutritionSection
            photoSection
            ingredientsSection
            instructionsSection
            publicationSection
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .tint(AppTheme.primary)
        .scrollDismissesKeyboard(.interactively)
        .disabled(isPublishing || showCleanupWarning)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showDiscardConfirmation = true
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(isPublishing || showCleanupWarning)
            }
        }
        .confirmationDialog(
            "Leave this recipe?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Any unsaved changes will be lost.")
        }
        .navigationTitle(
            isEditing ? "Edit Recipe" : "Create Recipe"
        )
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            isEditing ? "Couldn't Save Changes" : "Publication Failed",
            isPresented: $showPublishError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(publishErrorMessage)
        }
        .alert(
            "Recipe Saved",
            isPresented: $showCleanupWarning
        ) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(
                "Your changes were saved, but some old photos could not be removed."
            )
        }
    }

    // MARK: Basic Information
    private var basicInformationSection: some View {
        Section("Recipe Information") {
            TextField("Recipe name", text: $recipeName)
            HStack {
                Text("Cooking Time")
                Spacer()
                Stepper("", value: $cookingTime, in: 1...300)
                    .labelsHidden()
                TextField(
                    "Min",
                    value: $cookingTime,
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 45)
                Text("min")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            HStack {
                Text("Servings")
                Spacer()
                Stepper("", value: $servings, in: 1...20)
                    .labelsHidden()
                TextField(
                    "Servings",
                    value: $servings,
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 45)
            }
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Dietary Options
    private var dietarySection: some View {
        Section {
            Text("Select all diets that apply to your recipe. You can leave this empty.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 10
            ) {
                ForEach(availableDiets, id: \.self) { diet in
                    Button {
                        if selectedDiets.contains(diet) {
                            selectedDiets.remove(diet)
                        } else {
                            selectedDiets.insert(diet)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(
                                systemName: selectedDiets.contains(diet)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            Text(diet)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(
                            selectedDiets.contains(diet)
                                ? AppTheme.primary
                                : AppTheme.text
                        )
                        .background(
                            selectedDiets.contains(diet)
                                ? AppTheme.sage
                                : AppTheme.surface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !selectedDiets.isEmpty {
                Button("Clear selection") {
                    selectedDiets.removeAll()
                }
                .font(.caption)
            }
        } header: {
            Text("Dietary Options")
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Nutrition Information
    private var nutritionSection: some View {
        Section {
            Text("Enter nutritional information per serving. All fields are optional.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            nutritionField(
                title: "Calories",
                unit: "kcal",
                value: $caloriesInput
            )
            nutritionField(
                title: "Protein",
                unit: "g",
                value: $proteinInput
            )
            nutritionField(
                title: "Fat",
                unit: "g",
                value: $fatInput
            )
            nutritionField(
                title: "Carbs",
                unit: "g",
                value: $carbsInput
            )
            if !isNutritionInputValid {
                Text("Enter valid non-negative numbers.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Nutrition Information")
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Recipe Photo
    private var photoSection: some View {
        Section("Recipe Photo") {
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label(
                    recipeImage != nil || existingImageURL != nil
                        ? "Change Photo"
                        : "Choose Photo",
                    systemImage: "photo"
                )
            }
            .disabled(isLoadingMainPhoto)
            .onChange(of: selectedPhoto) { _, newPhoto in
                guard let newPhoto else {
                    return
                }
                isLoadingMainPhoto = true
                mainPhotoError = nil
                Task {
                    await loadSelectedPhoto(newPhoto)
                }
            }
            if isLoadingMainPhoto {
                ProgressView("Loading photo...")
                    .font(.caption)
            }
            // Show newly selected photo first.
            if let recipeImage {
                Image(uiImage: recipeImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
            } else if let existingImageURL {
                // Show the photo already stored in Supabase.
                existingPhotoPreview(
                    imageURL: existingImageURL,
                    height: 200
                )
            }
            if recipeImage != nil || existingImageURL != nil {
                Button(role: .destructive) {
                    selectedPhoto = nil
                    recipeImage = nil
                    existingImageURL = nil
                    isLoadingMainPhoto = false
                    mainPhotoError = nil
                } label: {
                    Label(
                        "Remove Photo",
                        systemImage: "trash"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
            if let error = mainPhotoError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Cancel Photo Selection") {
                    selectedPhoto = nil
                    mainPhotoError = nil
                    isLoadingMainPhoto = false
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Ingredients
    private var ingredientsSection: some View {
        Section {
            ForEach($ingredients) { $ingredient in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        TextField(
                            "Ingredient name",
                            text: $ingredient.name
                        )
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(width: 1, height: 35)
                        TextField(
                            "Amount",
                            text: $ingredient.amount
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 65)
                        Picker("Unit", selection: $ingredient.unit) {
                            ForEach(ingredientUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    if ingredients.count > 1 {
                        Button(role: .destructive) {
                            ingredients.removeAll {
                                $0.id == ingredient.id
                            }
                        } label: {
                            Label(
                                "Remove ingredient",
                                systemImage: "trash"
                            )
                            .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            Button {
                ingredients.append(DraftIngredient())
            } label: {
                Label(
                    "Add Ingredient",
                    systemImage: "plus.circle"
                )
            }
        } header: {
            Text("Ingredients")
        } footer: {
            Text("Add each ingredient with its quantity and unit.")
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Cooking Instructions
    private var instructionsSection: some View {
        Section {
            ForEach($instructions) { $step in
                VStack(alignment: .leading, spacing: 12) {
                    // Step number and delete button.
                    HStack {
                        let stepNumber = (
                            instructions.firstIndex {
                                $0.id == step.id
                            } ?? 0
                        ) + 1
                        Text("Step \(stepNumber)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            let stepID = step.id
                            if let index = instructions.firstIndex(
                                where: { $0.id == stepID }
                            ), index > 0 {
                                instructions.swapAt(
                                    index,
                                    index - 1
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(stepNumber == 1)
                        .accessibilityLabel("Move step up")
                        Button {
                            let stepID = step.id
                            if let index = instructions.firstIndex(
                                where: { $0.id == stepID }
                            ), index < instructions.count - 1 {
                                instructions.swapAt(
                                    index,
                                    index + 1
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(stepNumber == instructions.count)
                        .accessibilityLabel("Move step down")
                        if instructions.count > 1 {
                            Button(role: .destructive) {
                                instructions.removeAll {
                                    $0.id == step.id
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    // Instruction text.
                    TextEditor(text: $step.text)
                        .frame(minHeight: 90)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    AppTheme.border
                                )
                        }
                    // Optional instruction photo.
                    PhotosPicker(
                        selection: $step.selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            step.image != nil || step.existingImageURL != nil
                                ? "Change Step Photo"
                                : "Add Step Photo",
                            systemImage: "photo"
                        )
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .disabled(step.isLoadingPhoto)
                    .onChange(of: step.selectedPhoto) { _, newPhoto in
                        guard let newPhoto else {
                            return
                        }
                        let instructionID = step.id
                        step.isLoadingPhoto = true
                        step.photoError = nil
                        Task {
                            await loadInstructionPhoto(
                                for: instructionID,
                                selectedPhoto: newPhoto
                            )
                        }
                    }
                    // Photo loading indicator.
                    if step.isLoadingPhoto {
                        ProgressView("Loading photo...")
                            .font(.caption)
                    }
                    // Selected or existing photo preview.
                    if let image = step.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )
                    } else if let imageURL = step.existingImageURL {
                        existingPhotoPreview(
                            imageURL: imageURL,
                            height: 180
                        )
                    }
                    // Remove selected or existing photo.
                    if step.image != nil || step.existingImageURL != nil {
                        Button(role: .destructive) {
                            step.selectedPhoto = nil
                            step.image = nil
                            step.existingImageURL = nil
                            step.isLoadingPhoto = false
                            step.photoError = nil
                        } label: {
                            Label(
                                "Remove Photo",
                                systemImage: "trash"
                            )
                            .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    // Photo loading error.
                    if let error = step.photoError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if step.photoError != nil {
                        Button("Cancel Photo Selection") {
                            step.selectedPhoto = nil
                            step.photoError = nil
                            step.isLoadingPhoto = false
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 6)
            }
            if !areInstructionPhotosValid {
                Text(
                    "Complete the text for each step with a photo and resolve any photo errors."
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
            Button {
                instructions.append(DraftInstruction())
            } label: {
                Label(
                    "Add Instruction Step",
                    systemImage: "plus.circle"
                )
            }
        } header: {
            Text("Cooking Instructions")
        } footer: {
            Text(
                "Describe the preparation process step by step. Photos are optional."
            )
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Publish Recipe
    private var publicationSection: some View {
        Section {
            if !isFormValid {
                Text("Complete all required fields. Cooking time must be 1–300 minutes and servings 1–20.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Button {
                publishRecipe()
            } label: {
                HStack {
                    Spacer()
                    if isPublishing {
                        ProgressView()
                            .tint(.white)
                        Text(isEditing ? "Saving..." : "Publishing...")
                            .fontWeight(.semibold)
                    } else {
                        Label(
                            isEditing ? "Save Changes" : "Publish Recipe",
                            systemImage: isEditing ? "checkmark.circle.fill" : "paperplane.fill"
                        )
                        .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .buttonStyle(CookWisePrimaryButtonStyle())
            .disabled(!isFormValid || isPublishing)
        } footer: {
            Text(
                isEditing
                    ? "Your changes will be updated in My Recipes and the CookWise community."
                    : "Your recipe will be saved to My Recipes and shared with the CookWise community."
            )
        }
        .listRowBackground(AppTheme.surface)
    }

    // MARK: Existing Photo Preview
    private func existingPhotoPreview(imageURL: String, height: CGFloat) -> some View {
        RecipeImageView(
            imageURL: imageURL,
            height: height,
            cornerRadius: AppTheme.smallCornerRadius,
            placeholderSymbol: "photo"
        )
    }

    // MARK: Nutrition Field
    private func nutritionField(
        title: String,
        unit: String,
        value: Binding<String>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Optional", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(unit)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 40, alignment: .leading)
        }
    }
}
