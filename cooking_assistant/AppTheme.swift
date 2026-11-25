import SwiftUI
import UIKit

/// Shared design tokens for a consistent appearance across CookWise.
enum AppTheme {

    // MARK: Brand Colours
    static let primary = adaptive(
        light: 0x597454,
        dark: 0xA4C39C
    )

    static let forest = adaptive(
        light: 0x30452F,
        dark: 0xDCE8D8
    )

    static let sage = adaptive(
        light: 0xEAF0E8,
        dark: 0x28382A
    )

    static let accent = Color(hex: 0xD6A475)

    // MARK: Backgrounds
    static let background = adaptive(
        light: 0xFFFFFF,
        dark: 0x121512
    )

    static let surface = adaptive(
        light: 0xF5F7F5,
        dark: 0x1D231E
    )

    static let border = adaptive(
        light: 0xE3E8E2,
        dark: 0x364037
    )

    // MARK: Text Colours
    static let text = adaptive(
        light: 0x242B25,
        dark: 0xF0F3EF
    )

    static let secondaryText = adaptive(
        light: 0x68736B,
        dark: 0xABB5AC
    )

    static let buttonBackground = Color(hex: 0x597454)

    // MARK: Layout
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 12

    // MARK: Adaptive Colours
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {

        Color(uiColor: UIColor { traits in
            UIColor(
                hex: traits.userInterfaceStyle == .dark
                    ? dark
                    : light
            )
        })
    }
}

// MARK: Hex Colour Support
extension Color {
    fileprivate init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: 1
        )
    }
}

// MARK: Shared Card Style
extension View {

    func cookWiseCard(padding: CGFloat = AppTheme.cardPadding) -> some View {

        self
            .padding(padding)
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
}

// MARK: Primary Button Style
struct CookWisePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration
    ) -> some View {

        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isEnabled
                    ? AppTheme.buttonBackground
                    : Color.gray
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.smallCornerRadius
                )
            )
            .opacity(
                configuration.isPressed ? 0.85 : 1
            )
    }
}
