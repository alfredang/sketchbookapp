import PencilKit
import SwiftUI

/// The brush library. Each brush is a preset over one of PencilKit's ink types,
/// tuned with a characteristic width and opacity so it reads like a distinct art
/// tool. Grouped into categories (Inking / Sketching / Painting) the way a
/// Procreate-style brush library is organised.
enum BrushType: String, CaseIterable, Codable, Identifiable {
    // Inking
    case pen          // Studio Pen
    case fountain     // Fountain Pen
    case monoline     // Monoline
    case technical    // Technical Pen
    case gel          // Gel Pen
    case brushPen     // Brush Pen
    // Sketching
    case pencil       // Graphite Pencil
    case charcoal     // Charcoal
    case crayon       // Crayon
    case chalk        // Chalk
    case pastel       // Soft Pastel
    // Painting
    case marker       // Marker
    case highlighter  // Highlighter
    case oil          // Oil Paint
    case gouache      // Gouache
    case acrylic      // Acrylic
    case watercolor   // Watercolor
    case airbrush     // Airbrush
    case ink          // Ink Bleed

    var id: String { rawValue }

    enum Category: String, CaseIterable, Identifiable {
        case inking = "Inking"
        case sketching = "Sketching"
        case painting = "Painting"
        var id: String { rawValue }
    }

    var category: Category {
        switch self {
        case .pen, .fountain, .monoline, .technical, .gel, .brushPen:
            return .inking
        case .pencil, .charcoal, .crayon, .chalk, .pastel:
            return .sketching
        case .marker, .highlighter, .oil, .gouache, .acrylic, .watercolor, .airbrush, .ink:
            return .painting
        }
    }

    var title: String {
        switch self {
        case .pen: return "Studio Pen"
        case .fountain: return "Fountain Pen"
        case .monoline: return "Monoline"
        case .technical: return "Technical Pen"
        case .gel: return "Gel Pen"
        case .brushPen: return "Brush Pen"
        case .pencil: return "Pencil"
        case .charcoal: return "Charcoal"
        case .crayon: return "Crayon"
        case .chalk: return "Chalk"
        case .pastel: return "Soft Pastel"
        case .marker: return "Marker"
        case .highlighter: return "Highlighter"
        case .oil: return "Oil Paint"
        case .gouache: return "Gouache"
        case .acrylic: return "Acrylic"
        case .watercolor: return "Watercolor"
        case .airbrush: return "Airbrush"
        case .ink: return "Ink Bleed"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .fountain: return "pencil.and.outline"
        case .monoline: return "line.diagonal"
        case .technical: return "ruler"
        case .gel: return "pencil.tip.crop.circle"
        case .brushPen: return "paintbrush.pointed"
        case .pencil: return "pencil"
        case .charcoal: return "scribble.variable"
        case .crayon: return "scribble"
        case .chalk: return "pencil.line"
        case .pastel: return "paintbrush"
        case .marker: return "highlighter"
        case .highlighter: return "highlighter"
        case .oil: return "paintbrush.fill"
        case .gouache: return "paintbrush"
        case .acrylic: return "paintbrush.fill"
        case .watercolor: return "drop"
        case .airbrush: return "wind"
        case .ink: return "drop.fill"
        }
    }

    /// PencilKit ink type backing this brush. Uses the iOS 17 ink types
    /// (monoline / fountainPen / watercolor / crayon) for higher fidelity.
    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen, .gel, .brushPen: return .pen
        case .fountain: return .fountainPen
        case .monoline, .technical: return .monoline
        case .pencil, .charcoal: return .pencil
        case .crayon, .chalk, .pastel: return .crayon
        case .marker, .highlighter, .oil, .gouache, .acrylic, .airbrush: return .marker
        case .watercolor, .ink: return .watercolor
        }
    }

    /// A reasonable default width for the brush (points).
    var defaultWidth: CGFloat {
        switch self {
        case .technical: return 3
        case .pen, .monoline: return 5
        case .fountain: return 7
        case .gel: return 8
        case .brushPen: return 10
        case .pencil: return 4
        case .charcoal: return 10
        case .crayon: return 12
        case .chalk: return 14
        case .pastel: return 16
        case .acrylic: return 16
        case .marker: return 18
        case .oil, .gouache: return 20
        case .highlighter: return 22
        case .watercolor: return 24
        case .airbrush: return 26
        case .ink: return 12
        }
    }

    /// Characteristic opacity, folded into the stroke colour's alpha so brushes
    /// read distinctly — translucent washes (watercolor, airbrush) vs. opaque
    /// inks (studio pen, gel).
    var opacity: CGFloat {
        switch self {
        case .highlighter, .airbrush: return 0.35
        case .marker, .watercolor: return 0.5
        case .chalk: return 0.6
        case .charcoal, .pastel, .gouache: return 0.7
        case .ink: return 0.8
        case .crayon, .oil: return 0.85
        case .brushPen: return 0.9
        case .gel: return 0.95
        default: return 1.0
        }
    }

    func tool(color: UIColor, width: CGFloat) -> PKInkingTool {
        PKInkingTool(inkType, color: color.multiplyingAlpha(opacity), width: width)
    }
}

private extension UIColor {
    /// Returns the colour with its alpha scaled by `factor` (clamped to 0...1).
    func multiplyingAlpha(_ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r, green: g, blue: b, alpha: max(0, min(1, a * factor)))
    }
}
