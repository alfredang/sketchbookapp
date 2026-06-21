import SwiftUI
import PencilKit

/// SwiftUI wrapper around `PKCanvasView` for the active layer.
///
/// - Apple Pencil + palm rejection are handled by PencilKit; `pencilOnly`
///   switches the drawing policy so a resting palm (or any finger) is ignored.
/// - Live symmetry mirroring is applied on stroke commit via the coordinator.
struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: PKTool
    var isRulerActive: Bool
    var pencilOnly: Bool
    var symmetry: SymmetryMode
    var canvasSize: CGSize
    var isLocked: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.contentSize = canvasSize
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        applyConfig(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing && !context.coordinator.isApplyingSymmetry {
            canvas.drawing = drawing
        }
        applyConfig(canvas)
    }

    private func applyConfig(_ canvas: PKCanvasView) {
        canvas.tool = tool
        canvas.isRulerActive = isRulerActive
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = !isLocked
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        var isApplyingSymmetry = false
        private var lastStrokeCount = 0

        init(_ parent: CanvasView) {
            self.parent = parent
            self.lastStrokeCount = parent.drawing.strokes.count
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingSymmetry else { return }
            var newDrawing = canvasView.drawing

            // Apply live symmetry to strokes added since the last change.
            if parent.symmetry != .off, newDrawing.strokes.count > lastStrokeCount {
                let added = Array(newDrawing.strokes[lastStrokeCount...])
                let mirrored = SymmetryEngine.mirror(strokes: added,
                                                     mode: parent.symmetry,
                                                     canvasSize: parent.canvasSize)
                if !mirrored.isEmpty {
                    isApplyingSymmetry = true
                    newDrawing.strokes.append(contentsOf: mirrored)
                    canvasView.drawing = newDrawing
                    isApplyingSymmetry = false
                }
            }
            lastStrokeCount = newDrawing.strokes.count
            DispatchQueue.main.async { self.parent.drawing = newDrawing }
        }
    }
}
