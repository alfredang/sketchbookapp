import SwiftUI
import PencilKit

enum ToolMode: String, CaseIterable, Identifiable {
    case draw, erase, fill
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .draw: return "paintbrush.pointed"
        case .erase: return "eraser"
        case .fill: return "drop.fill"
        }
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var document: SketchDocument
    @Published var brush: BrushType = .pen
    @Published var color: Color = .black
    @Published var width: CGFloat = 5
    @Published var toolMode: ToolMode = .draw
    @Published var isRulerActive = false
    @Published var symmetry: SymmetryMode = .off
    /// Palm rejection: when true, only Apple Pencil input draws (finger/palm ignored).
    @Published var pencilOnly = false
    @Published var referenceOpacity: Double = 0.5
    @Published var lastSavedAt: Date?

    private var store: DocumentStore?

    init(document: SketchDocument) {
        self.document = document
        self.width = brush.defaultWidth
    }

    /// Inject the environment store after init (StateObject can't read environment in init).
    func attach(store: DocumentStore) {
        if self.store == nil { self.store = store }
    }

    // MARK: - Active layer

    var activeIndex: Int { document.activeLayerIndex }

    var activeDrawing: PKDrawing {
        get {
            guard document.layers.indices.contains(activeIndex) else { return PKDrawing() }
            return document.layers[activeIndex].drawing
        }
        set {
            guard document.layers.indices.contains(activeIndex) else { return }
            document.layers[activeIndex].drawing = newValue
        }
    }

    var activeLayerLocked: Bool {
        document.layers.indices.contains(activeIndex) ? document.layers[activeIndex].isLocked : true
    }

    // MARK: - Tool

    var currentTool: PKTool {
        switch toolMode {
        case .draw:
            return brush.tool(color: UIColor(color), width: width)
        case .erase:
            return PKEraserTool(.bitmap)
        case .fill:
            // Fill uses a tap gesture, not a PencilKit tool; keep a no-op pen.
            return brush.tool(color: UIColor(color), width: width)
        }
    }

    func selectBrush(_ b: BrushType) {
        brush = b
        width = b.defaultWidth
        toolMode = .draw
    }

    // MARK: - Layers

    func addLayer() {
        let layer = Layer(name: "Layer \(document.layers.count + 1)")
        document.layers.append(layer)
        document.activeLayerIndex = document.layers.count - 1
    }

    func duplicateActiveLayer() {
        guard document.layers.indices.contains(activeIndex) else { return }
        var copy = document.layers[activeIndex]
        copy.id = UUID()
        copy.name += " copy"
        document.layers.insert(copy, at: activeIndex + 1)
        document.activeLayerIndex = activeIndex + 1
    }

    func deleteLayer(at index: Int) {
        guard document.layers.count > 1, document.layers.indices.contains(index) else { return }
        document.layers.remove(at: index)
        document.activeLayerIndex = min(document.activeLayerIndex, document.layers.count - 1)
    }

    func moveLayer(from source: IndexSet, to destination: Int) {
        document.layers.move(fromOffsets: source, toOffset: destination)
    }

    func setActiveLayer(_ index: Int) {
        guard document.layers.indices.contains(index) else { return }
        document.activeLayerIndex = index
    }

    // MARK: - Color fill

    /// Flood-fill from a tap. `point` is in canvas pixel coordinates.
    func performFill(at point: CGPoint) {
        guard document.layers.indices.contains(activeIndex),
              !document.layers[activeIndex].isLocked else { return }
        let base = LayerCompositor.composite(document, includeReference: false, scale: 1)
        guard let patch = FloodFill.fill(in: base, at: point, with: UIColor(color)) else { return }
        // Composite the filled patch onto the active layer's raster image.
        let size = document.canvasSize
        let merged = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            document.layers[activeIndex].image?.draw(in: rect)
            patch.draw(in: rect)
        }
        document.layers[activeIndex].imageData = merged.pngData()
    }

    // MARK: - Reference image (upload + overlay for tracing)

    func importReference(_ image: UIImage) {
        let layer = Layer(name: "Reference",
                          opacity: referenceOpacity,
                          imageData: image.pngData(),
                          isReference: true)
        document.layers.append(layer)
        // Keep the active (drawing) layer selected so the user traces over it.
    }

    var referenceLayerIndex: Int? { document.layers.firstIndex { $0.isReference } }

    func updateReferenceOpacity(_ value: Double) {
        referenceOpacity = value
        if let i = referenceLayerIndex { document.layers[i].opacity = value }
    }

    // MARK: - Filters (apply to active layer)

    func applyFilter(_ filter: SketchFilter) {
        guard filter != .none, document.layers.indices.contains(activeIndex) else { return }
        let size = document.canvasSize
        let rendered = LayerCompositor.renderLayer(document.layers[activeIndex], size: size, scale: 1)
        let filtered = FilterEngine.apply(filter, to: rendered)
        document.layers[activeIndex].imageData = filtered.pngData()
        document.layers[activeIndex].drawing = PKDrawing() // baked into the image
    }

    // MARK: - Templates / background

    func setTemplate(_ template: TemplateKind) { document.template = template }

    // MARK: - Persistence

    func save() {
        document.thumbnailData = LayerCompositor.thumbnail(document).pngData()
        guard let store else { return }
        let saved = store.save(document)
        document = saved
        lastSavedAt = saved.modifiedAt
    }

    /// Flattened export used by AR / share (excludes tracing references).
    func exportedImage() -> UIImage {
        LayerCompositor.composite(document, includeReference: false, includeBackground: true, scale: 2)
    }
}
