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
    @State private var photoItem: PhotosPickerItem?
    @State private var arImage: UIImage?
    @StateObject private var canvasHandle = CanvasHandle()

    init(document: SketchDocument) {
        _vm = StateObject(wrappedValue: EditorViewModel(document: document))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            canvasArea
                .background(Theme.background)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { vm.attach(store: store) }
        .onDisappear { vm.save() }
        .sheet(isPresented: $showLayers) {
            LayersPanel(vm: vm).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showBrushes) {
            BrushPanel(vm: vm).presentationDetents([.height(320)])
        }
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

    // MARK: - Top toolbar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { vm.save(); dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline)
            }

            Divider().frame(height: 24)

            // Brush (draw) — shows the current brush and opens the brush picker.
            Button {
                vm.toolMode = .draw
                showBrushes = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: vm.brush.systemImage)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(vm.toolMode == .draw ? .white : Theme.ink)
                .frame(height: 32).padding(.horizontal, 8)
                .background(vm.toolMode == .draw ? Theme.primary : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .help("Brushes")

            toolButton(.erase)
            toolButton(.fill)
            toolButton(.lasso)

            ColorPicker("", selection: $vm.color, supportsOpacity: true)
                .labelsHidden().frame(width: 32)

            Button { showWidth.toggle() } label: { Image(systemName: "lineweight") }
                .popover(isPresented: $showWidth) { widthPopover }

            Button { canvasHandle.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .help("Undo")
            Button { canvasHandle.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .help("Redo")

            Divider().frame(height: 24)

            guidesMenu

            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
            }
            .help("Import reference photo")

            Spacer()

            Button { showLayers = true } label: { Image(systemName: "square.3.layers.3d") }
            Button { arImage = vm.exportedImage() } label: { Image(systemName: "arkit") }
            Button { vm.save() } label: { Image(systemName: "icloud.and.arrow.up") }
        }
        .font(.title3)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surface)
    }

    private func toolButton(_ mode: ToolMode) -> some View {
        Button { vm.toolMode = mode } label: {
            Image(systemName: mode.systemImage)
                .foregroundStyle(vm.toolMode == mode ? .white : Theme.ink)
                .frame(width: 36, height: 32)
                .background(vm.toolMode == mode ? Theme.primary : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
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

    /// Single dropdown grouping rulers, symmetry guides, page templates and filter effects.
    private var guidesMenu: some View {
        Menu {
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
        } label: {
            let active = vm.isRulerActive || vm.symmetry != .off || vm.perspective != .off
            Image(systemName: "wand.and.stars")
                .foregroundStyle(active ? Theme.primary : Theme.ink)
        }
        .help("Guides & Effects")
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
                Image(uiImage: TemplateRenderer.render(vm.document.template, size: cs, backgroundColor: .clear))
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
        }
        .padding(16)
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
                           pencilOnly: vm.pencilOnly,
                           symmetry: vm.symmetry,
                           canvasSize: canvasSize,
                           isLocked: layer.isLocked || vm.toolMode == .fill,
                           handle: canvasHandle)
                    .frame(width: displaySize.width, height: displaySize.height)
            }
            .opacity(layer.opacity)
        } else {
            Image(uiImage: LayerCompositor.renderLayer(layer, size: canvasSize))
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
