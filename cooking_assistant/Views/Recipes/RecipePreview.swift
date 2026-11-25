import SwiftUI
import FirebaseAuth

struct RecipePreview: View {
    let recipe: Recipe
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]

    @EnvironmentObject var savedRecipesManager: SavedRecipesManager
    @EnvironmentObject var authService: AuthService

    private let green = Color(red: 0.35, green: 0.48, blue: 0.34)

    private var isSaved: Bool {
        savedRecipesManager.isSaved(recipe.id)
    }

    // MARK: Body
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {

                RecipeDetailsView(
                    recipe: recipe,
                    pantryItems: $pantryItems,
                    shoppingListItems: $shoppingListItems
                )
            } label: {
                recipeCard
            }
            .buttonStyle(.plain)

            bookmarkButton
                .padding(12)
        }
    }

    // MARK: Recipe Card
    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            recipeImage

            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                HStack(spacing: 8) {
                    Label(
                        "\(recipe.readyInMinutes) min",
                        systemImage: "clock"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)

                    Spacer(minLength: 4)

                    if let diet = recipe.diets.first {
                        Text(diet.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.forest)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                AppTheme.sage,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.cornerRadius
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AppTheme.cornerRadius
            )
            .strokeBorder(
                AppTheme.border,
                lineWidth: 1
            )
        }
    }

    // MARK: Recipe Image
    private var recipeImage: some View {

        RecipeImageView(
            imageURL: recipe.imageURL,
            height: 180,
            cornerRadius: 0,
            placeholderSymbol: recipe.diets.contains {
                $0.caseInsensitiveCompare("vegan") == .orderedSame
            }
            ? "leaf"
            : "fork.knife"
        )
    }
    
    // MARK: Bookmark Action
    private var bookmarkButton: some View {
        Button {
            guard let userID = authService.user?.uid else {
                return
            }

            savedRecipesManager.toggleSaved(
                recipe,
                for: userID
            )
        } label: {
            
            Image(
                systemName: isSaved
                    ? "bookmark.fill"
                    : "bookmark"
            )
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(
                isSaved ? Color.white : AppTheme.forest
            )
            .frame(width: 44, height: 44)
            .background(
                isSaved
                    ? AppTheme.buttonBackground
                    : AppTheme.background,
                in: Circle()
            )
            .shadow(
                color: .black.opacity(0.08),
                radius: 4,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .disabled(savedRecipesManager.isLoading)
        .accessibilityLabel(
            isSaved ? "Remove saved recipe" : "Save recipe"
        )
    }
}
