import PencilKit
import SwiftUI

/// The brush palette. Maps onto PencilKit ink types where possible.
enum BrushType: String, CaseIterable, Codable, Identifiable {
    case pen
    case pencil
    case marker
    case crayon
    case fountain
    case monoline
    case watercolor

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .crayon: return "scribble"
        case .fountain: return "pencil.and.outline"
        case .monoline: return "line.diagonal"
        case .watercolor: return "drop"
        }
    }

    /// PencilKit ink type backing this brush.
    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen, .fountain, .monoline: return .pen
        case .pencil, .crayon: return .pencil
        case .marker, .watercolor: return .marker
        }
    }

    /// A reasonable default width for the brush (points).
    var defaultWidth: CGFloat {
        switch self {
        case .pen, .monoline: return 5
        case .fountain: return 7
        case .pencil: return 4
        case .crayon: return 12
        case .marker: return 18
        case .watercolor: return 24
        }
    }

    func tool(color: UIColor, width: CGFloat) -> PKInkingTool {
        PKInkingTool(inkType, color: color, width: width)
    }
}
