import SwiftUI

/// Displays recipe images with consistent loading and fallback states.
struct RecipeImageView: View {
    let imageURL: String?

    var height: CGFloat = 120
    var cornerRadius: CGFloat = 12
    var placeholderSymbol: String = "fork.knife"

    var body: some View {
        Group {
            if let imageURL,
               let url = URL(string: imageURL) {
               
                AsyncImage(url: url) { phase in

                    switch phase {
                    case .empty:
                        ZStack {
                            AppTheme.surface
                            ProgressView()
                                .tint(AppTheme.primary)
                        }

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        placeholder

                    @unknown default:
                        placeholder
                    }
                }
            } else {

                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius)
        )
    }

    // MARK: Image Placeholder
    private var placeholder: some View {
        ZStack {
            AppTheme.sage

            Image(systemName: placeholderSymbol)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.primary)
        }
        .accessibilityLabel("Recipe image unavailable")
    }
}
