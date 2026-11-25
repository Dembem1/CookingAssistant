import Foundation

enum ShoppingListManager {

    static func addOrMerge(
        _ newItem: ShoppingListItem,
        into items: inout [ShoppingListItem]
    ) {
        let normalizedName = newItem.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Find all entries with the same name and compatible units.
        let matchingIndices = items.indices.filter { index in
            let existingName = items[index].name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return existingName == normalizedName
                && IngredientUnit.canConvert(items[index].unit, newItem.unit)
        }

        guard let firstIndex = matchingIndices.first else {
            items.append(newItem)
            return
        }

        let targetUnit = items[firstIndex].unit
        var totalAmount = items[firstIndex].amount

        // Merge any compatible duplicates already in the list.
        for index in matchingIndices.dropFirst() {
            if let convertedAmount = IngredientUnit.convert(
                items[index].amount,
                from: items[index].unit,
                to: targetUnit
            ) {
                totalAmount += convertedAmount
            }
        }

        // Add the new amount, converted to the existing unit.
        if let convertedNewAmount = IngredientUnit.convert(
            newItem.amount,
            from: newItem.unit,
            to: targetUnit
        ) {
            totalAmount += convertedNewAmount
        }

        items[firstIndex].amount = totalAmount
        items[firstIndex].isPurchased = false

        // Use the new category if it is meaningful.
        // Otherwise, preserve the category already selected by the user.
        if newItem.category != .other || items[firstIndex].category == .other {
            items[firstIndex].category = newItem.category
        }

        // Remove the merged duplicate entries.
        for index in matchingIndices.dropFirst().reversed() {
            items.remove(at: index)
        }
    }
}
