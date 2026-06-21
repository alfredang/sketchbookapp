import SwiftUI

/// Graphite pencil hardness grades. Harder (H) leaves a lighter, thinner line;
/// softer (B) leaves a darker, broader line. Selecting a grade configures the
/// pencil ink with the matching darkness and width.
enum PencilGrade: String, CaseIterable, Identifiable {
    case h2, h, hb, b2, b4, b6

    var id: String { rawValue }

    var title: String {
        switch self {
        case .h2: return "2H"
        case .h:  return "H"
        case .hb: return "HB"
        case .b2: return "2B"
        case .b4: return "4B"
        case .b6: return "6B"
        }
    }

    /// Stroke width in points.
    var width: CGFloat {
        switch self {
        case .h2: return 3
        case .h:  return 3.5
        case .hb: return 4
        case .b2: return 6
        case .b4: return 8
        case .b6: return 10
        }
    }

    /// Graphite darkness as a white level (0 = black, 1 = white).
    var graphiteWhite: Double {
        switch self {
        case .h2: return 0.55
        case .h:  return 0.45
        case .hb: return 0.32
        case .b2: return 0.18
        case .b4: return 0.08
        case .b6: return 0.0
        }
    }

    var color: Color { Color(white: graphiteWhite) }
}
