import UIKit

/// Draws page templates (ring-file, grid, isometric …) as a background image.
enum TemplateRenderer {
    static func render(_ kind: TemplateKind, size: CGSize, backgroundColor: UIColor = .white) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            backgroundColor.setFill()
            c.fill(CGRect(origin: .zero, size: size))
            let line = UIColor(white: 0.0, alpha: 0.10)
            let accent = UIColor(red: 0.85, green: 0.55, blue: 0.55, alpha: 0.5)

            switch kind {
            case .blank:
                break
            case .ruled:
                drawHorizontalLines(c, size: size, spacing: 48, color: line)
            case .grid:
                drawGrid(c, size: size, spacing: 48, color: line)
            case .dotGrid:
                drawDots(c, size: size, spacing: 48, color: UIColor(white: 0, alpha: 0.18))
            case .isometric:
                drawIsometric(c, size: size, spacing: 56, color: line)
            case .storyboard:
                drawStoryboard(c, size: size, color: line)
            case .musicStaff:
                drawMusicStaff(c, size: size, color: line)
            case .ringFile:
                drawRingFile(c, size: size, line: line, accent: accent)
            }
        }
    }

    private static func drawHorizontalLines(_ c: CGContext, size: CGSize, spacing: CGFloat, color: UIColor) {
        color.setStroke(); c.setLineWidth(1)
        var y: CGFloat = spacing
        while y < size.height { c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
        c.strokePath()
    }

    private static func drawGrid(_ c: CGContext, size: CGSize, spacing: CGFloat, color: UIColor) {
        color.setStroke(); c.setLineWidth(1)
        var x: CGFloat = 0
        while x < size.width { c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
        var y: CGFloat = 0
        while y < size.height { c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
        c.strokePath()
    }

    private static func drawDots(_ c: CGContext, size: CGSize, spacing: CGFloat, color: UIColor) {
        color.setFill()
        var y: CGFloat = spacing
        while y < size.height {
            var x: CGFloat = spacing
            while x < size.width { c.fillEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)); x += spacing }
            y += spacing
        }
    }

    private static func drawIsometric(_ c: CGContext, size: CGSize, spacing: CGFloat, color: UIColor) {
        color.setStroke(); c.setLineWidth(1)
        let angle: CGFloat = .pi / 6 // 30°
        let dx = spacing / tan(angle)
        // forward diagonals
        var x = -size.height * tan(angle)
        while x < size.width {
            c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x + size.height / tan(angle), y: size.height)); x += dx
        }
        // backward diagonals
        x = 0
        while x < size.width + size.height / tan(angle) {
            c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x - size.height / tan(angle), y: size.height)); x += dx
        }
        c.strokePath()
        drawHorizontalLines(c, size: size, spacing: spacing, color: color)
    }

    private static func drawStoryboard(_ c: CGContext, size: CGSize, color: UIColor) {
        color.setStroke(); c.setLineWidth(2)
        let cols = 2, rows = 3
        let pad: CGFloat = 60, gap: CGFloat = 40
        let cellW = (size.width - pad * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (size.height - pad * 2 - gap * CGFloat(rows - 1)) / CGFloat(rows)
        for r in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(x: pad + CGFloat(col) * (cellW + gap),
                                  y: pad + CGFloat(r) * (cellH + gap),
                                  width: cellW, height: cellH * 0.72)
                c.stroke(rect)
            }
        }
    }

    private static func drawMusicStaff(_ c: CGContext, size: CGSize, color: UIColor) {
        color.setStroke(); c.setLineWidth(1)
        let staffGap: CGFloat = 16, blockGap: CGFloat = 90
        var top: CGFloat = 80
        while top + staffGap * 4 < size.height {
            for i in 0..<5 {
                let y = top + CGFloat(i) * staffGap
                c.move(to: CGPoint(x: 60, y: y)); c.addLine(to: CGPoint(x: size.width - 60, y: y))
            }
            top += staffGap * 4 + blockGap
        }
        c.strokePath()
    }

    private static func drawRingFile(_ c: CGContext, size: CGSize, line: UIColor, accent: UIColor) {
        // Ruled lines + red margin + binder holes down the left edge.
        drawHorizontalLines(c, size: size, spacing: 48, color: line)
        accent.setStroke(); c.setLineWidth(2)
        let marginX: CGFloat = 120
        c.move(to: CGPoint(x: marginX, y: 0)); c.addLine(to: CGPoint(x: marginX, y: size.height)); c.strokePath()

        UIColor(white: 0.92, alpha: 1).setFill()
        UIColor(white: 0.6, alpha: 1).setStroke()
        c.setLineWidth(2)
        let holeRadius: CGFloat = 18
        let holeX: CGFloat = 50
        let count = 7
        let spacing = size.height / CGFloat(count + 1)
        for i in 1...count {
            let rect = CGRect(x: holeX - holeRadius, y: spacing * CGFloat(i) - holeRadius,
                              width: holeRadius * 2, height: holeRadius * 2)
            c.fillEllipse(in: rect); c.strokeEllipse(in: rect)
        }
    }
}
