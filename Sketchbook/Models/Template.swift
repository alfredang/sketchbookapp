import SwiftUI

/// Paper / page templates rendered behind the drawing layers.
enum TemplateKind: String, CaseIterable, Codable, Identifiable {
    case blank
    case ringFile      // ring-binder holes + margin + ruled lines
    case ruled
    case grid
    case dotGrid
    case isometric
    case storyboard
    case musicStaff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "Blank"
        case .ringFile: return "Ring File"
        case .ruled: return "Ruled"
        case .grid: return "Grid"
        case .dotGrid: return "Dot Grid"
        case .isometric: return "Isometric"
        case .storyboard: return "Storyboard"
        case .musicStaff: return "Music Staff"
        }
    }

    var systemImage: String {
        switch self {
        case .blank: return "rectangle"
        case .ringFile: return "ring.circle"
        case .ruled: return "list.bullet"
        case .grid: return "grid"
        case .dotGrid: return "circle.grid.3x3"
        case .isometric: return "cube"
        case .storyboard: return "rectangle.split.3x3"
        case .musicStaff: return "music.note.list"
        }
    }
}
