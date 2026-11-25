import SwiftUI
import FirebaseAuth

struct ContentView: View {

    @StateObject private var authService = AuthService()
    @StateObject private var savedRecipesManager = SavedRecipesManager()
    
    private let firestoreService = FirestoreService.shared
    
    @State private var selectedTab = 0
    @State private var recipeSearchQuery = ""
    
    @State private var pantryItems: [PantryItem] = []
    @State private var shoppingListItems: [ShoppingListItem] = []

    @State private var showingPantryError = false
    @State private var pantryErrorMessage = ""
    
    var body: some View {

        Group {

            if authService.isCheckingAuth {

                ProgressView("Loading CookWise...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if authService.user != nil {

                mainTabView
                    .onAppear {
                        selectedTab = 0

                        if let userID = authService.user?.uid {
                            loadPantryItems(for: userID)
                            loadShoppingListItems(for: userID)
                            savedRecipesManager.loadSavedRecipes(for: userID)
                        }
                    }

            } else {

                NavigationStack {
                    LogInView()
                }
                .onAppear {
                    pantryItems = []
                    shoppingListItems = []
                    recipeSearchQuery = ""
                    savedRecipesManager.clear()
                }
            }
        }
        .environmentObject(authService)
        .environmentObject(savedRecipesManager)
        .tint(AppTheme.primary)
        .alert(
            "Couldn't Load Ingredients",
            isPresented: $showingPantryError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(pantryErrorMessage)
        }
    }

    // MARK: Load Pantry from Firestore
    private func loadPantryItems(for userID: String) {
        firestoreService.fetchPantryItems(for: userID) { result in
           
            DispatchQueue.main.async {
                // Make sure the same user is still logged in.
                guard authService.user?.uid == userID else {
                    return
                }

                switch result {
                case .success(let items):
                    pantryItems = items

                case .failure(let error):
                    pantryErrorMessage = error.localizedDescription
                    showingPantryError = true
                }
            }
        }
    }
    
    // MARK: Load Shopping List from Firestore
    private func loadShoppingListItems(for userID: String) {
        firestoreService.fetchShoppingListItems(for: userID) { result in

            DispatchQueue.main.async {
                // Make sure the same user is still logged in.
                guard authService.user?.uid == userID else {
                    return
                }

                switch result {
                case .success(let items):
                    shoppingListItems = items

                case .failure(let error):
                    pantryErrorMessage = error.localizedDescription
                    showingPantryError = true
                }
            }
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    pantryItems: $pantryItems,
                    shoppingListItems: $shoppingListItems,
                    onFindRecipes: { query in
                        recipeSearchQuery = query
                        selectedTab = 1
                    },
                    onShowIngredients: {
                        selectedTab = 2
                    },
                    onShowProfile: {
                            selectedTab = 3
                    }
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            NavigationStack {
                RecipesView(
                    searchQuery: $recipeSearchQuery,
                    pantryItems: $pantryItems,
                    shoppingListItems: $shoppingListItems
                )
            }
            .tabItem {
                Label("Recipes", systemImage: "book")
            }
            .tag(1)

            NavigationStack {
                MyIngredientsView(
                    pantryItems: $pantryItems,
                    shoppingListItems: $shoppingListItems
                )
            }
            .tabItem {
                Label("My Ingredients", systemImage: "basket")
            }
            .tag(2)

            NavigationStack {
                ProfileView(
                    pantryItems: $pantryItems,
                    shoppingListItems: $shoppingListItems
                )
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(3)
        }
    }
}
