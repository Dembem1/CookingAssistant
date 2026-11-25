import SwiftUI
import FirebaseAuth

struct DietaryPreferencesView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    private let firestoreService = FirestoreService.shared

    @State private var selectedDiets: Set<String> = []
    @State private var allergies = ""
    @State private var dislikedIngredients = ""

    @State private var isLoading = true
    @State private var hasLoadedPreferences = false
    @State private var isSaving = false

    @State private var showingError = false
    @State private var errorMessage = ""

    private let diets = [
        "Vegetarian",
        "Vegan",
        "Pescatarian",
        "Gluten-Free",
        "Dairy-Free",
        "Keto",
        "Low-Carb",
        "Low-Fat"
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading preferences...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasLoadedPreferences {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(AppTheme.primary)
                    Text("Couldn’t load preferences").font(.headline).foregroundStyle(AppTheme.text)
                    Button("Try Again", action: loadPreferences).buttonStyle(CookWisePrimaryButtonStyle())
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                preferencesForm
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Dietary Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSaving)
        .task { loadPreferences() }
        .alert("Something Went Wrong", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    // MARK: Preferences Form

    private var preferencesForm: some View {
        Form {
            Section {
                Text("Choose the dietary preferences that apply to you.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                ForEach(diets, id: \.self) { diet in
                    Toggle(diet, isOn: Binding(
                        get: { selectedDiets.contains(diet) },
                        set: { selected in
                            if selected { selectedDiets.insert(diet) }
                            else { selectedDiets.remove(diet) }
                        }
                    ))
                    .tint(AppTheme.primary)
                }
            } header: { Text("Diet Preferences") }
            .listRowBackground(AppTheme.surface)

            Section {
                TextField("e.g. Peanuts, shellfish, eggs", text: $allergies, axis: .vertical)
                    .lineLimit(2...4).accessibilityLabel("Allergies")
            } header: { Text("Allergies") }
            footer: {
                Text("Separate ingredients with commas. Recipe filters may miss allergens; always check ingredients and product labels yourself.")
            }
            .listRowBackground(AppTheme.surface)

            Section {
                TextField("e.g. Mushrooms, olives, onions", text: $dislikedIngredients, axis: .vertical)
                    .lineLimit(2...4).accessibilityLabel("Disliked ingredients")
            } header: { Text("Disliked Ingredients") }
            footer: { Text("List ingredients you prefer to avoid, separated by commas.") }
            .listRowBackground(AppTheme.surface)

            Section {
                Button(action: savePreferences) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving..." : "Save Preferences")
                    }
                }
                .buttonStyle(CookWisePrimaryButtonStyle())
                .disabled(isSaving)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
    }
    
    // MARK: Load Dietary Preferences
    private func loadPreferences() {
        isLoading = true
        hasLoadedPreferences = false
        guard let userID = authService.user?.uid else {
            isLoading = false
            errorMessage = "You must be logged in to load your preferences."
            showingError = true
            return
        }
        firestoreService.fetchDietaryPreferences(for: userID) { result in
            DispatchQueue.main.async {
                guard authService.user?.uid == userID else { return }
                isLoading = false
                switch result {
                case .success(let preferences):
                    selectedDiets = Set(preferences.selectedDiets)
                    allergies = preferences.allergies
                    dislikedIngredients = preferences.dislikedIngredients
                    hasLoadedPreferences = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // MARK: Save Dietary Preferences
    private func savePreferences() {
        // Do not overwrite existing preferences if the initial load failed.
        guard hasLoadedPreferences, !isSaving else { return }
        guard let userID = authService.user?.uid else {
            errorMessage = "You must be logged in to save your preferences."
            showingError = true
            return
        }
        let preferences = DietaryPreferences(
            selectedDiets: selectedDiets.sorted(),
            allergies: allergies.trimmingCharacters(in: .whitespacesAndNewlines),
            dislikedIngredients: dislikedIngredients.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSaving = true
        firestoreService.saveDietaryPreferences(preferences, for: userID) { error in
            DispatchQueue.main.async {
                guard authService.user?.uid == userID else { return }
                isSaving = false
                if let error {
                    errorMessage = error.localizedDescription
                    showingError = true
                } else { dismiss() }
            }
        }
    }
}
