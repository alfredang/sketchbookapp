import SwiftUI
import PencilKit

/// Holds a weak reference to the live PKCanvasView so the toolbar can drive
/// PencilKit's undo/redo.
final class CanvasHandle: ObservableObject {
    weak var canvas: PKCanvasView?
    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    var canUndo: Bool { canvas?.undoManager?.canUndo ?? false }
    var canRedo: Bool { canvas?.undoManager?.canRedo ?? false }
}

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
    var handle: CanvasHandle?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        handle?.canvas = canvas
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.bouncesZoom = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentSize = canvasSize
        applyConfig(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing && !context.coordinator.isApplyingSymmetry {
            canvas.drawing = drawing
        }
        applyConfig(canvas)
        // Fit the fixed-size drawing canvas into the on-screen frame using
        // PencilKit's own zoom (NOT a SwiftUI .scaleEffect, which breaks Pencil
        // touch handling). Drawing stays in canvasSize coordinates.
        canvas.contentSize = canvasSize
        let bounds = canvas.bounds.size
        if bounds.width > 0, bounds.height > 0 {
            let fit = min(bounds.width / canvasSize.width, bounds.height / canvasSize.height)
            if fit > 0, fit.isFinite {
                canvas.minimumZoomScale = fit
                canvas.maximumZoomScale = fit
                if abs(canvas.zoomScale - fit) > 0.0001 { canvas.zoomScale = fit }
            }
        }
    }

    private func applyConfig(_ canvas: PKCanvasView) {
        canvas.tool = tool
        canvas.isRulerActive = isRulerActive
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = !isLocked
        // In Dark Mode PencilKit inverts ink colors (black ink → white), making
        // black strokes invisible on the white canvas. Pin the canvas to light
        // so ink renders in the authored color.
        canvas.overrideUserInterfaceStyle = .light
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
