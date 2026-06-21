import UIKit
import PencilKit

/// Generates sample sketches used ONLY for App Store screenshot captures.
/// Activated by the `SKETCH_SEED=1` launch environment variable — never runs
/// in a normal/production launch.
enum SampleArt {
    static var seedRequested: Bool {
        ProcessInfo.processInfo.environment["SKETCH_SEED"] == "1"
    }

    static func makeSamples() -> [SketchDocument] {
        [
            sample(title: "Mountain Sunrise", template: .blank, size: SketchDocument.defaultSize) { ctx, s in
                let sky = UIGraphicsGetCurrentContext()!
                let colors = [UIColor(hex: "#FFE0B2").cgColor, UIColor(hex: "#FFCC80").cgColor, UIColor(hex: "#FFAB91").cgColor]
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.6, 1])!
                sky.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
                UIColor(hex: "#FFD54F").setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: s.width*0.62, y: s.height*0.18, width: s.width*0.16, height: s.width*0.16))
                drawMountains(ctx.cgContext, s)
            },
            sample(title: "Botanical Study", template: .dotGrid, size: SketchDocument.defaultSize) { ctx, s in
                UIColor(hex: "#F1F8E9").setFill(); ctx.cgContext.fill(CGRect(origin: .zero, size: s))
                drawLeaf(ctx.cgContext, center: CGPoint(x: s.width*0.5, y: s.height*0.5), scale: s.height*0.5)
            },
            sample(title: "Character Sketch", template: .ringFile, size: SketchDocument.defaultSize) { ctx, s in
                let c = UIGraphicsGetCurrentContext()!
                c.setStrokeColor(UIColor(hex: "#37474F").cgColor); c.setLineWidth(10); c.setLineCap(.round)
                let cx = s.width*0.55, cy = s.height*0.42, r = s.height*0.18
                c.strokeEllipse(in: CGRect(x: cx-r, y: cy-r, width: 2*r, height: 2*r))
                for dx in [-r*0.4, r*0.4] { c.fillEllipse(in: CGRect(x: cx+dx-8, y: cy-12, width: 16, height: 16)) }
                c.move(to: CGPoint(x: cx-r*0.4, y: cy+r*0.45)); c.addQuadCurve(to: CGPoint(x: cx+r*0.4, y: cy+r*0.45), control: CGPoint(x: cx, y: cy+r*0.75)); c.strokePath()
            }
        ]
    }

    private static func drawMountains(_ ctx: CGContext, _ s: CGSize) {
        let c = UIGraphicsGetCurrentContext()!
        c.setFillColor(UIColor(hex: "#8D6E63").cgColor)
        c.move(to: CGPoint(x: 0, y: s.height)); c.addLine(to: CGPoint(x: s.width*0.3, y: s.height*0.45))
        c.addLine(to: CGPoint(x: s.width*0.55, y: s.height)); c.closePath(); c.fillPath()
        c.setFillColor(UIColor(hex: "#6D4C41").cgColor)
        c.move(to: CGPoint(x: s.width*0.35, y: s.height)); c.addLine(to: CGPoint(x: s.width*0.7, y: s.height*0.35))
        c.addLine(to: CGPoint(x: s.width, y: s.height)); c.closePath(); c.fillPath()
    }

    private static func drawLeaf(_ ctx: CGContext, center: CGPoint, scale: CGFloat) {
        let c = UIGraphicsGetCurrentContext()!
        c.setStrokeColor(UIColor(hex: "#33691E").cgColor); c.setLineWidth(8); c.setLineCap(.round)
        c.move(to: CGPoint(x: center.x, y: center.y+scale*0.5))
        c.addLine(to: CGPoint(x: center.x, y: center.y-scale*0.5)); c.strokePath()
        c.setFillColor(UIColor(hex: "#7CB342").withAlphaComponent(0.85).cgColor)
        for i in 0..<5 {
            let y = center.y - scale*0.4 + CGFloat(i)*scale*0.2
            for sgn in [CGFloat(-1), 1] {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: center.x, y: y))
                p.addQuadCurve(to: CGPoint(x: center.x + sgn*scale*0.28, y: y - scale*0.06),
                               controlPoint: CGPoint(x: center.x + sgn*scale*0.18, y: y - scale*0.18))
                p.addQuadCurve(to: CGPoint(x: center.x, y: y + scale*0.04),
                               controlPoint: CGPoint(x: center.x + sgn*scale*0.18, y: y + scale*0.12))
                p.fill()
            }
        }
    }

    private static func sample(title: String, template: TemplateKind, size: CGSize,
                               draw: (UIGraphicsImageRendererContext, CGSize) -> Void) -> SketchDocument {
        var doc = SketchDocument(title: title, template: template, size: size)
        let art = UIGraphicsImageRenderer(size: size).image { ctx in draw(ctx, size) }
        doc.layers = [Layer(name: "Layer 1", imageData: art.pngData())]
        doc.activeLayerIndex = 0
        doc.thumbnailData = LayerCompositor.thumbnail(doc).pngData()
        return doc
    }
}
