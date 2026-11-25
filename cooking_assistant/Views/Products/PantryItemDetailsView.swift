import SwiftUI
import FirebaseAuth

struct PantryItemDetailsView: View {

    let itemID: UUID

    @Binding var pantryItems: [PantryItem]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    private let firestoreService = FirestoreService.shared

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isUpdating = false

    private var itemIndex: Int? {
        pantryItems.firstIndex { $0.id == itemID }
    }

    private var item: PantryItem? {
        guard let index = itemIndex else {
            return nil
        }

        return pantryItems[index]
    }

    // MARK: Ingredient Details
    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        VStack(spacing: 12) {
                            Image(systemName: "basket")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 70, height: 70)
                                .background(AppTheme.sage, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            Text(item.name.capitalized)
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text(item.category.title)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.forest)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.sage, in: Capsule())
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredient details")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            detailRow("Name", value: item.name.capitalized)
                            Divider()
                            detailRow("Amount", value: "\(item.amount.formatted()) \(item.unit)")
                            Divider()
                            detailRow("Category", value: item.category.title)
                        }
                        .cookWiseCard()

                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit Ingredient", systemImage: "pencil")
                        }
                        .buttonStyle(CookWisePrimaryButtonStyle())
                        .disabled(isUpdating)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Ingredient", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdating)

                        if isUpdating {
                            ProgressView("Updating ingredient...")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(AppTheme.screenPadding)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Ingredient not found", systemImage: "exclamationmark.circle")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle("Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            if let item {
                EditPantryItemView(item: item) { name, amount, unit, category in
                    updateIngredient(name: name, amount: amount, unit: unit, category: category)
                }
            }
        }
        .confirmationDialog("Delete Ingredient?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteIngredient() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This ingredient will be permanently removed from your list.")
        }
        .alert("Something Went Wrong", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    // MARK: Delete Ingredient
    private func deleteIngredient() {
        guard !isUpdating, itemIndex != nil,
              let userID = authService.user?.uid else { return }
        isUpdating = true
        firestoreService.deletePantryItem(withID: itemID, for: userID) { error in
            DispatchQueue.main.async {
                isUpdating = false
                guard authService.user?.uid == userID else { return }
                if let error {
                    errorMessage = error.localizedDescription
                    showingError = true
                } else {
                    pantryItems.removeAll { $0.id == itemID }
                    dismiss()
                }
            }
        }
    }

    // MARK: Update Ingredient
    private func updateIngredient(name: String, amount: Double, unit: String, category: PantryCategory) {
        guard !isUpdating, let index = itemIndex,
              let userID = authService.user?.uid else { return }

        let oldItem = pantryItems[index]
        var updatedItem = oldItem
        updatedItem.name = name
        updatedItem.amount = amount
        updatedItem.unit = unit
        updatedItem.category = category

        // Update locally and restore the previous values if Firestore rejects the write.
        pantryItems[index] = updatedItem
        isUpdating = true
        firestoreService.savePantryItem(updatedItem, for: userID) { error in
            DispatchQueue.main.async {
                isUpdating = false
                guard authService.user?.uid == userID else { return }
                if let error {
                    if let currentIndex = itemIndex {
                        pantryItems[currentIndex] = oldItem
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
