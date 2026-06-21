import SwiftUI

/// Non-printing drawing-technique guides (perspective, isometric, grid) overlaid
/// on the canvas to help the artist — like Procreate's Drawing Guides.
enum PerspectiveGuide: String, CaseIterable, Identifiable {
    case off, onePoint, twoPoint, threePoint, isometric, grid

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .onePoint: return "1-Point Perspective"
        case .twoPoint: return "2-Point Perspective"
        case .threePoint: return "3-Point Perspective"
        case .isometric: return "Isometric"
        case .grid: return "Grid"
        }
    }
}

/// Renders the selected guide. `size` is the on-screen display size.
struct PerspectiveGuides: View {
    let guide: PerspectiveGuide
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            guard guide != .off else { return }
            let color = Color(red: 0.18, green: 0.55, blue: 0.78).opacity(0.35)
            let thin = StrokeStyle(lineWidth: 1)
            let horizonY = sz.height * 0.45

            func ray(from vp: CGPoint, count: Int) {
                var path = Path()
                for i in 0..<count {
                    let pt = perimeterPoint(CGFloat(i) / CGFloat(count), sz)
                    path.move(to: vp); path.addLine(to: pt)
                }
                ctx.stroke(path, with: .color(color), style: thin)
            }
            func line(_ a: CGPoint, _ b: CGPoint) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), style: thin)
            }

            switch guide {
            case .off: break
            case .onePoint:
                line(CGPoint(x: 0, y: horizonY), CGPoint(x: sz.width, y: horizonY))
                ray(from: CGPoint(x: sz.width / 2, y: horizonY), count: 24)
            case .twoPoint:
                line(CGPoint(x: 0, y: horizonY), CGPoint(x: sz.width, y: horizonY))
                ray(from: CGPoint(x: sz.width * 0.05, y: horizonY), count: 18)
                ray(from: CGPoint(x: sz.width * 0.95, y: horizonY), count: 18)
            case .threePoint:
                line(CGPoint(x: 0, y: horizonY), CGPoint(x: sz.width, y: horizonY))
                ray(from: CGPoint(x: sz.width * 0.05, y: horizonY), count: 16)
                ray(from: CGPoint(x: sz.width * 0.95, y: horizonY), count: 16)
                ray(from: CGPoint(x: sz.width / 2, y: sz.height * 1.15), count: 16)
            case .isometric:
                drawIsometric(ctx, sz, color: color)
            case .grid:
                drawGrid(ctx, sz, color: color)
            }
        }
        .allowsHitTesting(false)
    }

    private func perimeterPoint(_ t: CGFloat, _ s: CGSize) -> CGPoint {
        let total = 2 * (s.width + s.height)
        var p = t * total
        if p < s.width { return CGPoint(x: p, y: 0) }
        p -= s.width
        if p < s.height { return CGPoint(x: s.width, y: p) }
        p -= s.height
        if p < s.width { return CGPoint(x: s.width - p, y: s.height) }
        p -= s.width
        return CGPoint(x: 0, y: s.height - p)
    }

    private func drawIsometric(_ ctx: GraphicsContext, _ s: CGSize, color: Color) {
        let spacing: CGFloat = 36
        let slope = tan(CGFloat.pi / 6) // 30°
        var path = Path()
        var x: CGFloat = -s.height * slope
        while x < s.width + s.height * slope {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + s.height * slope, y: s.height))
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x - s.height * slope, y: s.height))
            x += spacing
        }
        var vx: CGFloat = 0
        while vx < s.width { path.move(to: CGPoint(x: vx, y: 0)); path.addLine(to: CGPoint(x: vx, y: s.height)); vx += spacing }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1))
    }

    private func drawGrid(_ ctx: GraphicsContext, _ s: CGSize, color: Color) {
        let spacing: CGFloat = 36
        var path = Path()
        var x: CGFloat = 0
        while x < s.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: s.height)); x += spacing }
        var y: CGFloat = 0
        while y < s.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: s.width, y: y)); y += spacing }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1))
    }
}
