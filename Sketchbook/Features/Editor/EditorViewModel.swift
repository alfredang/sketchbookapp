import SwiftUI
import PencilKit

enum ToolMode: String, CaseIterable, Identifiable {
    case draw, erase, fill, lasso
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .draw: return "paintbrush.pointed"
        case .erase: return "eraser"
        case .fill: return "drop.fill"
        case .lasso: return "lasso"
        }
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var document: SketchDocument
    @Published var brush: BrushType = .pen
    @Published var color: Color = .black
    @Published var width: CGFloat = 5
    @Published var eraseWidth: CGFloat = 24
    @Published var toolMode: ToolMode = .draw
    @Published var isRulerActive = false
    @Published var symmetry: SymmetryMode = .off
    @Published var perspective: PerspectiveGuide = .off
    /// Palm rejection: when true, only Apple Pencil input draws (finger/palm ignored).
    /// Driven by the "Finger Drawing" setting (off → pencil-only → palm rejected).
    @Published var pencilOnly = true
    @Published var referenceOpacity: Double = 0.5
    @Published var lastSavedAt: Date?

    private var store: DocumentStore?

    // MARK: - Render caches (avoid re-rendering full-res images every view update,
    // which caused input latency when switching tools).
    private var templateCache: (TemplateKind, CGFloat, CGFloat, UIImage)?
    private var layerImageCache: [UUID: UIImage] = [:]

    func templateImage(size: CGSize) -> UIImage {
        if let c = templateCache, c.0 == document.template, c.1 == size.width, c.2 == size.height {
            return c.3
        }
        let img = TemplateRenderer.render(document.template, size: size, backgroundColor: .clear)
        templateCache = (document.template, size.width, size.height, img)
        return img
    }

    func inactiveLayerImage(_ layer: Layer, size: CGSize) -> UIImage {
        if let img = layerImageCache[layer.id] { return img }
        let img = LayerCompositor.renderLayer(layer, size: size)
        layerImageCache[layer.id] = img
        return img
    }

    private func invalidateLayerImage(_ id: UUID?) {
        if let id { layerImageCache.removeValue(forKey: id) } else { layerImageCache.removeAll() }
    }

    init(document: SketchDocument) {
        self.document = document
        // Apply saved defaults (Settings).
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: SettingsKey.defaultBrush),
           let b = BrushType(rawValue: raw) {
            self.brush = b
        }
        // Finger drawing on by default so drawing works out of the box (with or
        // without an Apple Pencil); users can switch to Pencil-only in Settings.
        let fingerDrawing = defaults.object(forKey: SettingsKey.fingerDrawing) as? Bool ?? true
        self.pencilOnly = !fingerDrawing
        if let e = defaults.object(forKey: SettingsKey.defaultEraseSize) as? Double, e > 0 {
            self.eraseWidth = CGFloat(e)
        }
        self.width = brush.defaultWidth
        // If the default brush is the pencil, apply the saved grade.
        if brush == .pencil, let g = defaults.string(forKey: SettingsKey.defaultPencilGrade),
           let grade = PencilGrade(rawValue: g) {
            self.pencilGrade = grade
            self.width = grade.width
            self.color = grade.color
        }
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
            return PKEraserTool(.bitmap, width: eraseWidth)
        case .lasso:
            // PencilKit's lasso selects strokes and shows its own edit menu
            // (cut / copy / duplicate / move).
            return PKLassoTool()
        case .fill:
            // Fill uses a tap gesture, not a PencilKit tool; keep a no-op pen.
            return brush.tool(color: UIColor(color), width: width)
        }
    }

    /// Currently selected graphite grade (when the pencil brush is in use).
    @Published var pencilGrade: PencilGrade?

    func selectBrush(_ b: BrushType) {
        brush = b
        width = b.defaultWidth
        pencilGrade = nil
        toolMode = .draw
        Haptics.select()
    }

    /// Select a graphite pencil grade — sets the pencil ink with grade darkness + width.
    func selectPencilGrade(_ grade: PencilGrade) {
        brush = .pencil
        width = grade.width
        color = grade.color
        pencilGrade = grade
        toolMode = .draw
        Haptics.select()
    }

    // MARK: - Finger drawing

    /// Whether finger (touch) input draws. When off, only Apple Pencil draws and
    /// fingers pan/zoom (palm rejection). Mirrors the Settings default.
    var fingerDrawingEnabled: Bool { !pencilOnly }

    func setFingerDrawing(_ on: Bool) {
        pencilOnly = !on
        UserDefaults.standard.set(on, forKey: SettingsKey.fingerDrawing)
        Haptics.select()
    }

    // MARK: - Pages

    var pageCount: Int { document.pages.count }
    var currentPage: Int { document.currentPageIndex }

    /// Add a new blank page after the current one and switch to it.
    func addPage() { addPageAfter() }

    /// Insert a blank page immediately before the current page and switch to it.
    func addPageBefore() {
        flushActiveDrawing()
        let insertAt = document.currentPageIndex
        document.pages.insert(Page(), at: insertAt)
        document.currentPageIndex = insertAt
        Haptics.select()
    }

    /// Insert a blank page immediately after the current page and switch to it.
    func addPageAfter() {
        flushActiveDrawing()
        let insertAt = document.currentPageIndex + 1
        document.pages.insert(Page(), at: insertAt)
        document.currentPageIndex = insertAt
        Haptics.select()
    }

    func goToPage(_ index: Int) {
        guard document.pages.indices.contains(index), index != document.currentPageIndex else { return }
        flushActiveDrawing()
        document.currentPageIndex = index
        Haptics.select()
    }

    /// Next page, or create one when swiping past the last page.
    func nextPageOrCreate() {
        if document.currentPageIndex < document.pages.count - 1 {
            goToPage(document.currentPageIndex + 1)
        } else {
            addPage()
        }
    }

    func previousPage() {
        guard document.currentPageIndex > 0 else { return }
        goToPage(document.currentPageIndex - 1)
    }

    func deleteCurrentPage() {
        guard document.pages.count > 1 else { clearCurrentPage(); return }
        document.pages.remove(at: document.currentPageIndex)
        document.currentPageIndex = min(document.currentPageIndex, document.pages.count - 1)
        invalidateLayerImage(nil)
        Haptics.select()
    }

    /// Remove every page and start over with a single blank page.
    func deleteAllPages() {
        document.pages = [Page()]
        document.currentPageIndex = 0
        invalidateLayerImage(nil)
        Haptics.select()
    }

    /// Wipe the current page's content back to one blank layer (keeps the page).
    func clearCurrentPage() {
        document.pages[document.currentPageIndex] = Page()
        invalidateLayerImage(nil)
        Haptics.select()
    }

    /// Wipe every page's content but keep the page count.
    func clearAllPages() {
        for i in document.pages.indices { document.pages[i] = Page() }
        invalidateLayerImage(nil)
        Haptics.select()
    }

    /// Next page without auto-creating (used by the swipe gesture).
    func nextPage() {
        guard document.currentPageIndex < document.pages.count - 1 else { return }
        goToPage(document.currentPageIndex + 1)
    }

    /// Ensure the latest PencilKit strokes are committed to the model before a
    /// page switch (the canvas pushes changes asynchronously).
    private func flushActiveDrawing() {
        guard document.layers.indices.contains(activeIndex) else { return }
        invalidateLayerImage(document.layers[activeIndex].id)
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
        invalidateLayerImage(nil)
    }

    func setActiveLayer(_ index: Int) {
        guard document.layers.indices.contains(index) else { return }
        // The layer we're leaving may have changed — drop its cached image so it
        // re-renders correctly as an inactive layer.
        if document.layers.indices.contains(activeIndex) {
            invalidateLayerImage(document.layers[activeIndex].id)
        }
        document.activeLayerIndex = index
        invalidateLayerImage(document.layers[index].id)
    }

    func renameLayer(at index: Int, to name: String) {
        guard document.layers.indices.contains(index) else { return }
        document.layers[index].name = name
    }

    /// Distinct group names currently in use.
    var groupNames: [String] {
        var seen = [String]()
        for l in document.layers { if let g = l.groupName, !seen.contains(g) { seen.append(g) } }
        return seen
    }

    func setGroup(at index: Int, to name: String?) {
        guard document.layers.indices.contains(index) else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        document.layers[index].groupName = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// Toggle visibility for every layer in a group at once.
    func toggleGroupVisibility(_ group: String) {
        let anyVisible = document.layers.contains { $0.groupName == group && $0.isVisible }
        for i in document.layers.indices where document.layers[i].groupName == group {
            document.layers[i].isVisible = !anyVisible
        }
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
        invalidateLayerImage(document.layers[activeIndex].id)
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
        invalidateLayerImage(document.layers[activeIndex].id)
    }

    // MARK: - Templates / background

    func setTemplate(_ template: TemplateKind) {
        document.template = template
        templateCache = nil
    }

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
