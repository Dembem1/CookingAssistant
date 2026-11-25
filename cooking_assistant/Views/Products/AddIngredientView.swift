import SwiftUI

struct AddIngredientView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var category: PantryCategory = .other
    @State private var unit = "g"

    let onSave: (PantryItem) -> Void

    private let units = ["g", "kg", "ml", "l", "pieces", "tbsp", "tsp"]

    private var availableUnits: [String] {
        units.contains(unit) ? units : units + [unit]
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Accept a decimal point or comma, but reject non-finite quantities.
    private var validAmount: Double? {
        guard let value = Double(amount.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ingredient name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(PantryCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(availableUnits, id: \.self) { option in
                            Text(option.isEmpty ? "No unit" : option).tag(option)
                        }
                    }
                } header: {
                    Text("Ingredient details")
                } footer: {
                    Text("Enter a name and a quantity greater than zero.")
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(cleanName.isEmpty || validAmount == nil)
                }
            }
        }
        .tint(AppTheme.primary)
    }

    private func saveItem() {
        guard !cleanName.isEmpty, let value = validAmount else { return }
        onSave(PantryItem(name: cleanName, amount: value, unit: unit, category: category))
        dismiss()
    }
}
