import SwiftUI
import FirebaseAuth

enum ProductsSection: String, CaseIterable {
    case myIngredients = "My Ingredients"
    case shoppingList = "Shopping List"
}

struct MyIngredientsView: View {
    @EnvironmentObject var authService: AuthService
    private let firestoreService = FirestoreService.shared
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]

    @State private var showingAddShoppingListItem = false
    @State private var selectedSection: ProductsSection = .myIngredients
    @State private var showingAddIngredient = false
    @State private var showingDuplicateWarning = false
    @State private var duplicateMessage = ""

    private func addIngredient(_ newItem: PantryItem) {
        guard let userID = authService.user?.uid else {
            return
        }
        let newName = newItem.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let newUnit = newItem.unit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let existingIndex = pantryItems.firstIndex { item in
            item.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == newName
            && item.unit
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == newUnit
        }

        let itemToSave: PantryItem
        if let index = existingIndex {
            if pantryItems[index].category == newItem.category {
                pantryItems[index].amount += newItem.amount
                itemToSave = pantryItems[index]
            } else {
                duplicateMessage = """
                \(newItem.name.capitalized) already exists in the \
                \(pantryItems[index].category.title) category.
                Please select the same category or check the existing ingredient.
                """
                showingDuplicateWarning = true
                return
            }
        } else {
            pantryItems.append(newItem)
            itemToSave = newItem
        }
        // Save the ingredient to the current user's Firestore pantry.
        firestoreService.savePantryItem(itemToSave, for: userID) { error in
            if let error = error {
                DispatchQueue.main.async {
                    duplicateMessage = error.localizedDescription
                    showingDuplicateWarning = true
                }
            }
        }
    }

    // MARK: Add Shopping List Item
    private func addShoppingListItem(_ newItem: ShoppingListItem) {
        guard let userID = authService.user?.uid else {
            return
        }
        // Remember existing document IDs before merging.
        let previousIDs = Set(shoppingListItems.map { $0.id })
        // Preserve the existing merging and unit conversion logic.
        ShoppingListManager.addOrMerge(
            newItem,
            into: &shoppingListItems
        )
        // Find all items with the same name and compatible units.
        let normalizedName = newItem.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let affectedItems = shoppingListItems.filter { item in
            let existingName = item.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return existingName == normalizedName
                && IngredientUnit.canConvert(item.unit, newItem.unit)
        }
        // Save the new or updated item.
        for item in affectedItems {
            firestoreService.saveShoppingListItem(
                item,
                for: userID
            ) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        duplicateMessage = error.localizedDescription
                        showingDuplicateWarning = true
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
                        duplicateMessage = error.localizedDescription
                        showingDuplicateWarning = true
                    }
                }
            }
        }
    }
    
    // MARK: Toggle Shopping List Item
    private func toggleShoppingListItem(_ item: ShoppingListItem) {
        guard let userID = authService.user?.uid else {
            return
        }
        guard let index = shoppingListItems.firstIndex(where: {
            $0.id == item.id
        }) else {
            return
        }
        // Update the local state.
        shoppingListItems[index].isPurchased.toggle()
        let updatedItem = shoppingListItems[index]
        // Save the updated item to Firestore.
        firestoreService.saveShoppingListItem(
            updatedItem,
            for: userID
        ) { error in
            if let error = error {
                DispatchQueue.main.async {
                    duplicateMessage = error.localizedDescription
                    showingDuplicateWarning = true
                }
            }
        }
    }
    
    // MARK: Delete Shopping List Item
    private func deleteShoppingListItem(_ item: ShoppingListItem) {
        guard let userID = authService.user?.uid else {
            return
        }
        // Remove the item from the local list.
        shoppingListItems.removeAll {
            $0.id == item.id
        }
        // Delete the item from Firestore.
        firestoreService.deleteShoppingListItem(
            withID: item.id,
            for: userID
        ) { error in
            if let error = error {
                DispatchQueue.main.async {
                    duplicateMessage = error.localizedDescription
                    showingDuplicateWarning = true
                }
            }
        }
    }
    
    // MARK: Transfer Purchased Items to Pantry
    private func transferPurchasedItemsToPantry() {
        guard let userID = authService.user?.uid else {
            return
        }
        let purchasedItems = shoppingListItems.filter {
            $0.isPurchased
        }
        guard !purchasedItems.isEmpty else {
            return
        }

        // Keep track of Pantry items that were added or updated.
        var changedPantryIDs = Set<UUID>()
        for shoppingItem in purchasedItems {
            let normalizedName = shoppingItem.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            // Look for the same ingredient in the Pantry.
            let existingIndex = pantryItems.firstIndex { item in
                let pantryName = item.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return pantryName == normalizedName
                    && IngredientUnit.canConvert(item.unit, shoppingItem.unit)
            }
            if let index = existingIndex {
                // Convert the purchased amount to the Pantry item's unit.
                if let convertedAmount = IngredientUnit.convert(
                    shoppingItem.amount,
                    from: shoppingItem.unit,
                    to: pantryItems[index].unit
                ) {
                    pantryItems[index].amount += convertedAmount
                    changedPantryIDs.insert(pantryItems[index].id)
                } else {
                    // If conversion is not possible, add a separate item.
                    let newItem = PantryItem(
                        name: shoppingItem.name,
                        amount: shoppingItem.amount,
                        unit: shoppingItem.unit,
                        category: shoppingItem.category
                    )
                    pantryItems.append(newItem)
                    changedPantryIDs.insert(newItem.id)
                }
            } else {
                // Add a new ingredient with its Shopping List category.
                let newItem = PantryItem(
                    name: shoppingItem.name,
                    amount: shoppingItem.amount,
                    unit: shoppingItem.unit,
                    category: shoppingItem.category
                )
                pantryItems.append(newItem)
                changedPantryIDs.insert(newItem.id)
            }
        }
        
        // Remove only the purchased items from the local Shopping List.
        shoppingListItems.removeAll {
            $0.isPurchased
        }
        
        // Save all added or updated Pantry items to Firestore.
        let updatedPantryItems = pantryItems.filter {
            changedPantryIDs.contains($0.id)
        }
        
        for item in updatedPantryItems {
            firestoreService.savePantryItem(
                item,
                for: userID
            ) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        duplicateMessage = error.localizedDescription
                        showingDuplicateWarning = true
                    }
                }
            }
        }
        // Delete transferred items from the Firestore Shopping List.
        for item in purchasedItems {
            firestoreService.deleteShoppingListItem(
                withID: item.id,
                for: userID
            ) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        duplicateMessage = error.localizedDescription
                        showingDuplicateWarning = true
                    }
                }
            }
        }
    }
    
    // MARK: Products Screen
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
                .padding(.horizontal, AppTheme.screenPadding)
            Picker("Products", selection: $selectedSection) {
                ForEach(ProductsSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.screenPadding)

            List {
                if selectedSection == .myIngredients {
                    pantryContent
                } else {
                    shoppingContent
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
        }
        .padding(.top, 12)
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if selectedSection == .shoppingList && shoppingListItems.contains(where: { $0.isPurchased }) {
                    Button {
                        transferPurchasedItemsToPantry()
                    } label: {
                        Label("Add to Pantry", systemImage: "tray.and.arrow.down")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selectedSection == .myIngredients {
                        showingAddIngredient = true
                    } else {
                        showingAddShoppingListItem = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(selectedSection == .myIngredients ? "Add ingredient" : "Add shopping item")
            }
        }
        .alert("Couldn't Complete Action", isPresented: $showingDuplicateWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(duplicateMessage)
        }
        .sheet(isPresented: $showingAddIngredient) {
            AddIngredientView { addIngredient($0) }
        }
        .sheet(isPresented: $showingAddShoppingListItem) {
            AddShoppingListItemView { addShoppingListItem($0) }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedSection == .myIngredients ? "Your pantry" : "Shopping list")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text(selectedSection == .myIngredients
                 ? "Keep track of what you have at home."
                 : "\(shoppingListItems.filter { !$0.isPurchased }.count) items left to buy")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: Pantry
    @ViewBuilder
    private var pantryContent: some View {
        if pantryItems.isEmpty {
            ContentUnavailableView("No Ingredients Yet", systemImage: "carrot",
                                   description: Text("Add ingredients to your pantry."))
                .listRowBackground(AppTheme.background)
        } else {
            ForEach(PantryCategory.allCases) { category in
                let items = pantryItems.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            NavigationLink {
                                PantryItemDetailsView(itemID: item.id, pantryItems: $pantryItems)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "leaf")
                                        .foregroundStyle(AppTheme.primary)
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.sage, in: RoundedRectangle(cornerRadius: 10))
                                    Text(item.name.capitalized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Spacer(minLength: 4)
                                    Text("\(item.amount.formatted()) \(item.unit)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                    } header: {
                        Text(category.title).foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: Shopping List
    @ViewBuilder
    private var shoppingContent: some View {
        if shoppingListItems.isEmpty {
            ContentUnavailableView("Your Shopping List Is Empty", systemImage: "cart",
                                   description: Text("Missing ingredients from your recipes will appear here."))
                .listRowBackground(AppTheme.background)
        } else {
            ForEach(PantryCategory.allCases) { category in
                let items = shoppingListItems.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            Button {
                                toggleShoppingListItem(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(item.isPurchased ? AppTheme.primary : AppTheme.secondaryText)
                                        .frame(width: 44, height: 44)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name.capitalized)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(item.isPurchased ? AppTheme.secondaryText : AppTheme.text)
                                            .strikethrough(item.isPurchased)
                                        Text("\(item.amount.formatted()) \(item.unit)")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(item.isPurchased ? "Purchased" : "Not purchased")
                            .accessibilityHint("Double tap to change purchase status")
                            .listRowBackground(AppTheme.surface)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteShoppingListItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(category.title).foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
    }
}
