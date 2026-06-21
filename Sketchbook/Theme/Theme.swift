import SwiftUI

/// Brand design tokens. Reference these everywhere instead of raw `Color` literals
/// so a re-theme is a one-file change (see mobile-ios-design skill).
enum Theme {
    static let primary = Color(red: 0.40, green: 0.34, blue: 0.86)   // indigo
    static let secondary = Color(red: 0.18, green: 0.72, blue: 0.72) // teal
    static let highlight = Color(red: 0.98, green: 0.62, blue: 0.20) // amber
    static let background = Color(red: 0.98, green: 0.97, blue: 0.95) // warm off-white
    static let surface = Color.white
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.16)       // explicit dark for AA contrast
    static let mutedInk = Color(red: 0.42, green: 0.42, blue: 0.48)

    static let cornerRadius: CGFloat = 18
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
