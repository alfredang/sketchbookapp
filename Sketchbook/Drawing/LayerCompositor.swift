import UIKit
import PencilKit

/// Flattens layers into a single image — used for the gallery thumbnail, PNG
/// export, the flood-fill snapshot and the AR texture.
enum LayerCompositor {
    /// Render one layer (its image then its strokes) at the given size.
    static func renderLayer(_ layer: Layer, size: CGSize, scale: CGFloat = 1) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size, format: format(scale: scale))
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            layer.image?.draw(in: rect, blendMode: .normal, alpha: layer.opacity)
            let strokeImage = layer.drawing.image(from: rect, scale: scale)
            strokeImage.draw(in: rect, blendMode: .normal, alpha: layer.opacity)
        }
    }

    /// Composite the full document. `includeReference` keeps tracing-reference
    /// layers (off for export so trace photos never leak into the artwork).
    static func composite(_ document: SketchDocument,
                          includeReference: Bool = false,
                          includeBackground: Bool = true,
                          scale: CGFloat = 1) -> UIImage {
        let size = document.canvasSize
        let renderer = UIGraphicsImageRenderer(size: size, format: format(scale: scale))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            if includeBackground {
                UIColor(hex: document.backgroundHex).setFill()
                ctx.cgContext.fill(rect)
                TemplateRenderer.render(document.template, size: size,
                                        backgroundColor: .clear).draw(in: rect)
            }
            for layer in document.layers where layer.isVisible {
                if layer.isReference && !includeReference { continue }
                layer.image?.draw(in: rect, blendMode: .normal, alpha: layer.opacity)
                layer.drawing.image(from: rect, scale: scale)
                    .draw(in: rect, blendMode: .normal, alpha: layer.opacity)
            }
        }
    }

    static func thumbnail(_ document: SketchDocument, maxDimension: CGFloat = 600) -> UIImage {
        let full = composite(document, includeReference: false, scale: 1)
        let size = document.canvasSize
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1)
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in full.draw(in: CGRect(origin: .zero, size: target)) }
    }

    private static func format(scale: CGFloat) -> UIGraphicsImageRendererFormat {
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = scale
        f.opaque = false
        return f
    }
}
