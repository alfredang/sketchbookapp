import SwiftUI
import PencilKit
import PhotosUI

struct EditorView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLayers = false
    @State private var showBrushes = false
    @State private var showWidth = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var arImage: UIImage?
    @StateObject private var canvasHandle = CanvasHandle()
    @ObservedObject private var orientation = OrientationManager.shared
    @Environment(\.horizontalSizeClass) private var hSize

    // Canvas pinch-zoom state.
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var zoomAnchor: UnitPoint = .center

    // iPad right-side panel state.
    @State private var sidePanelTab: SidePanelTab = .brush
    @State private var sidePanelCollapsed = false

    // Confirmation for destructive "all pages" actions.
    private enum PageConfirm { case clearAll, deleteAll }
    @State private var confirm: PageConfirm?

    /// True on iPad / regular width, where the docked side panel is shown.
    private var isRegular: Bool { hSize == .regular }

    init(document: SketchDocument) {
        _vm = StateObject(wrappedValue: EditorViewModel(document: document))
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                topBar
                Divider()
                canvasArea
                    .background(Theme.background)
                    .overlay(alignment: .bottom) { pageControl }
            }
            // iPad: docked, collapsible, tabbed inspector on the right.
            if isRegular {
                if sidePanelCollapsed {
                    expandPanelButton
                } else {
                    EditorSidePanel(vm: vm, tab: $sidePanelTab) {
                        withAnimation(.easeInOut(duration: 0.22)) { sidePanelCollapsed = true }
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { vm.attach(store: store) }
        .onDisappear { vm.save(); orientation.unlock() }
        .sheet(isPresented: $showLayers) {
            LayersPanel(vm: vm).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showBrushes) {
            BrushPanel(vm: vm).presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.importReference(image)
                }
            }
        }
        .fullScreenCover(item: Binding(get: { arImage.map { ARImageBox(image: $0) } },
                                       set: { arImage = $0?.image })) { box in
            ARSketchScreen(image: box.image)
        }
    }

    /// Thin affordance shown on the right edge when the iPad panel is collapsed.
    private var expandPanelButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { sidePanelCollapsed = false }
        } label: {
            Image(systemName: "sidebar.right")
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: 44)
                .frame(maxHeight: .infinity)
                .background(Theme.surface)
        }
        .help("Show panel")
        .accessibilityLabel("Show panel")
        .overlay(Divider(), alignment: .leading)
    }

    /// Bottom page navigator: flip between pages, add, or delete. Mirrors the
    /// two-finger swipe gesture (swipe up = next/new page, down = previous).
    private var pageControl: some View {
        HStack(spacing: 14) {
            Button { vm.previousPage() } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(vm.currentPage == 0)
            .accessibilityIdentifier("prevPage")
            .accessibilityLabel("Previous page")

            Text("Page \(vm.currentPage + 1) / \(vm.pageCount)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 92)
                .accessibilityIdentifier("pageIndicator")

            Button { vm.nextPage() } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(vm.currentPage == vm.pageCount - 1)
            .accessibilityIdentifier("nextPage")
            .accessibilityLabel("Next page")

            Divider().frame(height: 18)
            pagesMenu
        }
        .font(.title3)
        .tint(Theme.primary)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.ink.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .padding(.bottom, 14)
    }

    /// Page management: add before/after, clear, delete. Destructive actions
    /// for "all" are confirmed before running.
    private var pagesMenu: some View {
        Menu {
            Button { vm.addPageBefore() } label: { Label("Add Page Before", systemImage: "arrow.up.to.line") }
            Button { vm.addPageAfter() } label: { Label("Add Page After", systemImage: "arrow.down.to.line") }
            Divider()
            Button { vm.clearCurrentPage() } label: { Label("Clear Current Page", systemImage: "eraser") }
            Button { confirm = .clearAll } label: { Label("Clear All Pages", systemImage: "eraser.line.dashed") }
            Divider()
            Button(role: .destructive) { vm.deleteCurrentPage() } label: {
                Label("Delete Current Page", systemImage: "trash")
            }
            Button(role: .destructive) { confirm = .deleteAll } label: {
                Label("Delete All Pages", systemImage: "trash.slash")
            }
        } label: {
            Image(systemName: "square.stack.3d.up")
        }
        .accessibilityIdentifier("pagesMenu")
        .accessibilityLabel("Pages")
        .confirmationDialog("This affects every page in the sketchbook.",
                            isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible) {
            switch confirm {
            case .clearAll:
                Button("Clear All Pages", role: .destructive) { vm.clearAllPages() }
            case .deleteAll:
                Button("Delete All Pages", role: .destructive) { vm.deleteAllPages() }
            case nil:
                EmptyView()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Open the iPad panel to a tab, or fall back to a sheet on iPhone.
    private func openPicker(_ tab: SidePanelTab, sheet: () -> Void) {
        if isRegular {
            sidePanelTab = tab
            withAnimation(.easeInOut(duration: 0.22)) { sidePanelCollapsed = false }
        } else {
            sheet()
        }
    }

    // MARK: - Top toolbar

    private var topBar: some View {
        HStack(spacing: 6) {
            // Leading — pinned. Always reachable, never clipped.
            iconButton("chevron.left", label: "Back") { vm.save(); dismiss() }

            Divider().frame(height: 28)

            // Primary tools live in a horizontally scrollable strip so the bar
            // can never overflow / clip controls on narrow iPhone screens.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    brushButton
                    eraserButton

                    ColorPicker("", selection: $vm.color, supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 32, height: 32)
                        .frame(minWidth: 44, minHeight: 44)

                    iconButton("lineweight", label: "Brush size") { showWidth.toggle() }
                        .popover(isPresented: $showWidth) { widthPopover }

                    toolButton(.fill)
                    toolButton(.lasso)
                }
                .padding(.horizontal, 2)
            }

            Divider().frame(height: 28)

            // Trailing — pinned. Undo/redo + layers + overflow stay reachable.
            iconButton("arrow.uturn.backward", label: "Undo") { canvasHandle.undo() }
            iconButton("arrow.uturn.forward", label: "Redo") { canvasHandle.redo() }
            iconButton("square.3.layers.3d", label: "Layers") {
                openPicker(.layers) { showLayers = true }
            }
            overflowMenu
        }
        .font(.title3)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Theme.surface)
    }

    /// A toolbar icon button with a HIG-compliant 44×44 pt tap target.
    private func iconButton(_ systemName: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .help(label)
        .accessibilityLabel(label)
    }

    // Brush (draw) — shows the current brush and opens the brush picker.
    private var brushButton: some View {
        Button {
            vm.toolMode = .draw
            openPicker(.brush) { showBrushes = true }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.brush.systemImage)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(vm.toolMode == .draw ? .white : Theme.ink)
            .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44)
            .background(vm.toolMode == .draw ? Theme.primary : .clear,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .help("Brushes")
        .accessibilityLabel("Brushes")
    }

    // Eraser — tap to select; tap again (when active) to adjust size.
    private var eraserButton: some View {
        Button {
            if vm.toolMode == .erase { showWidth = true } else { vm.toolMode = .erase; Haptics.select() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "eraser")
                if vm.toolMode == .erase { Image(systemName: "chevron.down").font(.caption2) }
            }
            .foregroundStyle(vm.toolMode == .erase ? .white : Theme.ink)
            .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44)
            .background(vm.toolMode == .erase ? Theme.primary : .clear,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .help("Eraser")
        .accessibilityLabel("Eraser")
    }

    private func toolButton(_ mode: ToolMode) -> some View {
        Button { vm.toolMode = mode } label: {
            Image(systemName: mode.systemImage)
                .foregroundStyle(vm.toolMode == mode ? .white : Theme.ink)
                .frame(minWidth: 44, minHeight: 44)
                .background(vm.toolMode == mode ? Theme.primary : Color.clear,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .accessibilityLabel(mode.title)
    }

    /// Occasional actions grouped into an overflow menu to keep the bar uncluttered.
    private var overflowMenu: some View {
        Menu {
            guidesMenuContent
            Divider()
            Button { vm.setFingerDrawing(!vm.fingerDrawingEnabled) } label: {
                Label(vm.fingerDrawingEnabled ? "Finger Drawing: On" : "Finger Drawing: Off",
                      systemImage: vm.fingerDrawingEnabled ? "hand.draw.fill" : "hand.draw")
            }
            Button { orientation.toggle() } label: {
                Label(orientation.isLocked ? "Unlock Orientation" : "Lock Orientation",
                      systemImage: orientation.isLocked ? "lock.rotation.open" : "lock.rotation")
            }
            Button { showPhotoPicker = true } label: {
                Label("Import Reference Photo", systemImage: "photo.on.rectangle.angled")
            }
            Button { arImage = vm.exportedImage() } label: {
                Label("View in AR", systemImage: "arkit")
            }
            Button { vm.save() } label: {
                Label("Save", systemImage: "icloud.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .help("More")
        .accessibilityLabel("More options")
    }

    private var widthPopover: some View {
        VStack(alignment: .leading) {
            if vm.toolMode == .erase {
                Text("Eraser Size: \(Int(vm.eraseWidth))").font(.subheadline)
                Slider(value: $vm.eraseWidth, in: 6...80)
            } else {
                Text("Brush Size: \(Int(vm.width))").font(.subheadline)
                Slider(value: $vm.width, in: 1...60)
            }
        }
        .padding().frame(width: 260)
    }

    /// Rulers, symmetry guides, page templates and filter effects — embedded in
    /// the overflow menu so the top bar stays uncluttered.
    @ViewBuilder
    private var guidesMenuContent: some View {
        Menu("Guides & Effects") {
            Button {
                vm.isRulerActive.toggle()
            } label: {
                Label("Ruler", systemImage: vm.isRulerActive ? "checkmark" : "ruler")
            }

            Menu("Symmetry") {
                ForEach(SymmetryMode.allCases) { mode in
                    Button { vm.symmetry = mode } label: {
                        Label(mode.title, systemImage: vm.symmetry == mode ? "checkmark" : mode.systemImage)
                    }
                }
            }

            Menu("Drawing Guide") {
                ForEach(PerspectiveGuide.allCases) { g in
                    Button { vm.perspective = g } label: {
                        Label(g.title, systemImage: vm.perspective == g ? "checkmark" : "skew")
                    }
                }
            }

            Menu("Template") {
                ForEach(TemplateKind.allCases) { kind in
                    Button { vm.setTemplate(kind) } label: {
                        Label(kind.title, systemImage: vm.document.template == kind ? "checkmark" : kind.systemImage)
                    }
                }
            }

            Menu("Filter Effect") {
                ForEach(SketchFilter.photo) { f in
                    Button { vm.applyFilter(f) } label: { Text(f.title) }
                }
            }

            Menu("Painting Style") {
                ForEach(SketchFilter.painting) { f in
                    Button { vm.applyFilter(f) } label: { Text(f.title) }
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geo in
            let cs = vm.document.canvasSize
            let scale = min(geo.size.width / cs.width, geo.size.height / cs.height)
            // On-screen (display) size of the canvas; drawing stays in `cs` space.
            let disp = CGSize(width: cs.width * scale, height: cs.height * scale)
            ZStack {
                // Background + template
                Color(hex: vm.document.backgroundHex)
                Image(uiImage: vm.templateImage(size: cs))
                    .resizable().frame(width: disp.width, height: disp.height)

                // Layers in order; active layer is the live PencilKit canvas.
                ForEach(Array(vm.document.layers.enumerated()), id: \.element.id) { idx, layer in
                    if layer.isVisible {
                        layerView(idx: idx, layer: layer, displaySize: disp, canvasSize: cs)
                    }
                }

                // Symmetry + perspective/drawing guides
                SymmetryGuides(mode: vm.symmetry, size: disp)
                    .allowsHitTesting(false)
                PerspectiveGuides(guide: vm.perspective, size: disp)

                // Fill tap catcher (only active in fill mode, sits on top).
                // Map the tap from display space back into canvas coordinates.
                if vm.toolMode == .fill {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: disp.width, height: disp.height)
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            let p = CGPoint(x: value.location.x / max(scale, 0.0001),
                                            y: value.location.y / max(scale, 0.0001))
                            vm.performFill(at: p)
                        })
                }
            }
            .frame(width: disp.width, height: disp.height)
            .clipped()
            .frame(width: geo.size.width, height: geo.size.height)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .scaleEffect(zoom, anchor: zoomAnchor)
            .gesture(magnifyGesture)
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) { zoom = 1; baseZoom = 1 }
            }
        }
        .padding(16)
    }

    /// Two-finger pinch to zoom the canvas (1×–5×), anchored at the pinch point.
    /// Double-tap resets to fit. Single-finger input stays free for drawing.
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomAnchor = value.startAnchor
                zoom = min(max(baseZoom * value.magnification, 1), 5)
            }
            .onEnded { _ in baseZoom = zoom }
    }

    @ViewBuilder
    private func layerView(idx: Int, layer: Layer, displaySize: CGSize, canvasSize: CGSize) -> some View {
        if idx == vm.activeIndex && !layer.isReference {
            ZStack {
                // Raster contents of the active layer (fills, filters, imported art)
                // render beneath the live PencilKit canvas.
                if let image = layer.image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                }
                CanvasView(drawing: Binding(get: { vm.activeDrawing }, set: { vm.activeDrawing = $0 }),
                           tool: vm.currentTool,
                           isRulerActive: vm.isRulerActive,
                           // Allow finger for lasso selection even when finger-drawing is off.
                           pencilOnly: vm.pencilOnly && vm.toolMode != .lasso,
                           symmetry: vm.symmetry,
                           canvasSize: canvasSize,
                           isLocked: layer.isLocked || vm.toolMode == .fill,
                           handle: canvasHandle,
                           onSwipeUp: { vm.nextPage() },
                           onSwipeDown: { vm.previousPage() })
                    .frame(width: displaySize.width, height: displaySize.height)
            }
            .opacity(layer.opacity)
        } else {
            Image(uiImage: vm.inactiveLayerImage(layer, size: canvasSize))
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .opacity(layer.opacity)
        }
    }
}

/// Identifiable wrapper so we can present AR via `fullScreenCover(item:)`.
struct ARImageBox: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Dashed center lines indicating active symmetry axes.
struct SymmetryGuides: View {
    let mode: SymmetryMode
    let size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            var path = Path()
            if mode == .vertical || mode == .quad {
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            if mode == .horizontal || mode == .quad {
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            ctx.stroke(path, with: .color(Theme.secondary.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 2, dash: [12, 10]))
        }
        .frame(width: size.width, height: size.height)
    }
}
