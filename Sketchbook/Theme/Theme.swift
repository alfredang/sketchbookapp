import SwiftUI
import UIKit

/// Brand design tokens. Reference these everywhere instead of raw `Color` literals
/// so a re-theme is a one-file change (see mobile-ios-design skill).
enum Theme {
    // Brand accents — consistent across light & dark.
    static let primary = Color(red: 0.40, green: 0.34, blue: 0.86)   // indigo
    static let secondary = Color(red: 0.18, green: 0.72, blue: 0.72) // teal
    static let highlight = Color(red: 0.98, green: 0.62, blue: 0.20) // amber

    // Adaptive surfaces/text so Light, Dark and System themes all read correctly.
    static let background = dyn(light: (0.98, 0.97, 0.95), dark: (0.07, 0.07, 0.09))
    static let surface    = dyn(light: (1.00, 1.00, 1.00), dark: (0.14, 0.14, 0.17))
    static let ink        = dyn(light: (0.12, 0.12, 0.16), dark: (0.95, 0.95, 0.97))
    static let mutedInk   = dyn(light: (0.42, 0.42, 0.48), dark: (0.65, 0.65, 0.70))

    static let cornerRadius: CGFloat = 18

    private static func dyn(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// Reusable elevated card surface modifier.
struct AppCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View { modifier(AppCard(padding: padding)) }
}
