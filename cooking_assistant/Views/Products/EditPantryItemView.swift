import SwiftUI

struct EditPantryItemView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amount: String
    @State private var category: PantryCategory
    @State private var unit: String

    let onSave: (String, Double, String, PantryCategory) -> Void

    private let units = ["g", "kg", "ml", "l", "pieces", "tbsp", "tsp"]

    init(item: PantryItem, onSave: @escaping (String, Double, String, PantryCategory) -> Void) {

        _name = State(initialValue: item.name)
        _amount = State(initialValue: item.amount.formatted())
        _category = State(initialValue: item.category)
        _unit = State(initialValue: item.unit)

        self.onSave = onSave
    }
    
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
            .navigationTitle("Edit Ingredient")
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
        onSave(cleanName, value, unit, category)
        dismiss()
    }
}
