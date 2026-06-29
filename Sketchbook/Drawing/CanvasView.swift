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
    /// Reset pinch-zoom back to the fit-to-screen scale.
    func resetZoom() {
        guard let canvas else { return }
        canvas.setZoomScale(canvas.minimumZoomScale, animated: true)
    }
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
    /// Forceful two-finger swipes used to flip / create pages.
    var onSwipeUp: (() -> Void)?
    var onSwipeDown: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        handle?.canvas = canvas

        // Two-finger flick up/down → page navigation. Two fingers keeps the
        // single finger / Pencil free for drawing, and a swipe (not a pinch)
        // doesn't interfere with pinch-to-zoom.
        for direction in [UISwipeGestureRecognizer.Direction.up, .down] {
            let swipe = UISwipeGestureRecognizer(target: context.coordinator,
                                                 action: #selector(Coordinator.handleSwipe(_:)))
            swipe.direction = direction
            swipe.numberOfTouchesRequired = 2
            swipe.delegate = context.coordinator
            canvas.addGestureRecognizer(swipe)
        }
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
        // Only push the binding INTO the canvas when the change came from outside
        // (page switch, clear, filter, undo) — never when it's the value the
        // canvas itself just reported up. On iPad the docked side panel observes
        // the view model, so every stroke segment triggers a re-render → another
        // updateUIView mid-stroke; blindly assigning `canvas.drawing = drawing`
        // there rewinds the canvas to the lagging binding value and erases the
        // stroke in progress (the "can't draw with the panel open" bug).
        let coord = context.coordinator
        // NEVER touch the canvas's drawing while a stroke is in progress — doing
        // so cancels the live stroke (the device-only "can't draw with the panel
        // open" bug). Only push a drawing IN when it's a genuine external change
        // (page switch, clear, filter, undo) and not the value we just sent up.
        if !coord.isDrawing,
           canvas.drawing != drawing,
           drawing != coord.lastPushedUp,
           !coord.isApplyingSymmetry {
            coord.isPullingIn = true
            canvas.drawing = drawing
            coord.isPullingIn = false
            coord.syncStrokeCount(drawing.strokes.count)
            coord.lastPushedUp = drawing
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
                // Pinch-to-zoom is handled by PencilKit's own scroll-view zoom
                // (1×–5× of the fit scale) — NOT a SwiftUI .scaleEffect, which
                // breaks Pencil/touch input. `fit` is the zoomed-out baseline.
                canvas.minimumZoomScale = fit
                canvas.maximumZoomScale = fit * 5
                // Snap to fit only on first layout / when the user is zoomed out
                // past the new baseline; never fight an active user zoom.
                if !context.coordinator.didInitialZoom || canvas.zoomScale < fit {
                    canvas.zoomScale = fit
                    context.coordinator.didInitialZoom = true
                }
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

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var parent: CanvasView
        var isApplyingSymmetry = false
        var didInitialZoom = false
        /// True between tool-down and tool-up. While true, `updateUIView` must not
        /// reassign `canvas.drawing`, or the active stroke is cancelled.
        var isDrawing = false
        /// True while we are programmatically assigning `canvas.drawing` from the
        /// binding, so the resulting delegate callback doesn't echo it back.
        var isPullingIn = false
        /// The last drawing this canvas reported up through the binding. Used to
        /// distinguish our own round-trip from a genuine external change so
        /// `updateUIView` doesn't overwrite a stroke in progress.
        var lastPushedUp: PKDrawing?
        private var lastStrokeCount = 0

        init(_ parent: CanvasView) {
            self.parent = parent
            self.lastStrokeCount = parent.drawing.strokes.count
        }

        func syncStrokeCount(_ count: Int) { lastStrokeCount = count }

        @objc func handleSwipe(_ gr: UISwipeGestureRecognizer) {
            switch gr.direction {
            case .up: parent.onSwipeUp?()
            case .down: parent.onSwipeDown?()
            default: break
            }
        }

        // Allow the page-swipe to coexist with PencilKit's own gestures.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = false
            commit(canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Ignore the continuous stream of changes WHILE a stroke is being
            // drawn: committing per segment churns the binding, the iPad side
            // panel (which observes the model) re-renders, and the re-entrant
            // updateUIView would cancel the live stroke. The finished stroke is
            // committed in canvasViewDidEndUsingTool. Changes that arrive when
            // NOT actively drawing (undo/redo, programmatic edits) commit here.
            guard !isDrawing, !isPullingIn else { return }
            commit(canvasView)
        }

        /// Apply symmetry (if any) and push the finished drawing up to the model.
        private func commit(_ canvasView: PKCanvasView) {
            guard !isApplyingSymmetry, !isPullingIn else { return }
            var newDrawing = canvasView.drawing

            // Mirror strokes added since the last commit.
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
            // Record what we pushed, then commit SYNCHRONOUSLY. An async commit
            // leaves a window where the canvas holds the finished stroke but the
            // binding still holds the previous value; a re-render in that window
            // makes updateUIView treat the stale binding as an external change
            // and reset the canvas — erasing the stroke (the "sometimes the
            // stroke disappears" bug). These callbacks are user-event driven
            // (touch-up / undo), so setting state synchronously is safe.
            lastPushedUp = newDrawing
            parent.drawing = newDrawing
        }
    }
}
