import Foundation
import PencilKit

enum SymmetryMode: String, CaseIterable, Codable, Identifiable {
    case off
    case vertical    // mirror left/right
    case horizontal  // mirror top/bottom
    case quad        // mirror both axes (4-way kaleidoscope)

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        case .quad: return "Quad"
        }
    }
    var systemImage: String {
        switch self {
        case .off: return "circle.slash"
        case .vertical: return "rectangle.split.2x1"
        case .horizontal: return "rectangle.split.1x2"
        case .quad: return "rectangle.split.2x2"
        }
    }
}

/// Produces mirrored copies of freshly drawn strokes for live symmetry guides.
enum SymmetryEngine {
    static func mirror(strokes: [PKStroke], mode: SymmetryMode, canvasSize: CGSize) -> [PKStroke] {
        let cx = canvasSize.width / 2
        let cy = canvasSize.height / 2
        let mirrorX = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * cx, ty: 0)
        let mirrorY = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 2 * cy)
        let mirrorXY = mirrorX.concatenating(mirrorY)

        var result: [PKStroke] = []
        for stroke in strokes {
            switch mode {
            case .off:
                break
            case .vertical:
                result.append(transformed(stroke, by: mirrorX))
            case .horizontal:
                result.append(transformed(stroke, by: mirrorY))
            case .quad:
                result.append(transformed(stroke, by: mirrorX))
                result.append(transformed(stroke, by: mirrorY))
                result.append(transformed(stroke, by: mirrorXY))
            }
        }
        return result
    }

    private static func transformed(_ stroke: PKStroke, by t: CGAffineTransform) -> PKStroke {
        var copy = stroke
        copy.transform = stroke.transform.concatenating(t)
        return copy
    }
}
