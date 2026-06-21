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

            // Tool modes
            ForEach(ToolMode.allCases) { mode in
                toolButton(mode)
            }

            Button { showBrushes = true } label: {
                Image(systemName: vm.brush.systemImage)
            }
            .help("Brushes")

            ColorPicker("", selection: $vm.color, supportsOpacity: true)
                .labelsHidden().frame(width: 32)

            Button { showWidth.toggle() } label: { Image(systemName: "lineweight") }
                .popover(isPresented: $showWidth) { widthPopover }

            Divider().frame(height: 24)

            Button { vm.isRulerActive.toggle() } label: {
                Image(systemName: "ruler").foregroundStyle(vm.isRulerActive ? Theme.primary : Theme.ink)
            }

            symmetryMenu
            templateMenu
            filterMenu

            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
            }

            Button { vm.pencilOnly.toggle() } label: {
                Image(systemName: vm.pencilOnly ? "hand.raised.fill" : "hand.raised.slash")
                    .foregroundStyle(vm.pencilOnly ? Theme.primary : Theme.ink)
            }
            .help("Palm rejection (Pencil only)")

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
            Text("Brush Size: \(Int(vm.width))").font(.subheadline)
            Slider(value: $vm.width, in: 1...60)
        }
        .padding().frame(width: 260)
    }

    private var symmetryMenu: some View {
        Menu {
            ForEach(SymmetryMode.allCases) { mode in
                Button { vm.symmetry = mode } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                }
            }
        } label: {
            Image(systemName: vm.symmetry == .off ? "circle.slash" : vm.symmetry.systemImage)
                .foregroundStyle(vm.symmetry == .off ? Theme.ink : Theme.primary)
        }
    }

    private var templateMenu: some View {
        Menu {
            ForEach(TemplateKind.allCases) { kind in
                Button { vm.setTemplate(kind) } label: { Label(kind.title, systemImage: kind.systemImage) }
            }
        } label: { Image(systemName: "doc.plaintext") }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(SketchFilter.allCases) { f in
                Button { vm.applyFilter(f) } label: { Text(f.title) }
            }
        } label: { Image(systemName: "camera.filters") }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geo in
            let cs = vm.document.canvasSize
            let scale = min(geo.size.width / cs.width, geo.size.height / cs.height)
            ZStack {
                // Background + template
                Color(hex: vm.document.backgroundHex)
                Image(uiImage: TemplateRenderer.render(vm.document.template, size: cs, backgroundColor: .clear))
                    .resizable().frame(width: cs.width, height: cs.height)

                // Layers in order; active layer is the live PencilKit canvas.
                ForEach(Array(vm.document.layers.enumerated()), id: \.element.id) { idx, layer in
                    if layer.isVisible {
                        layerView(idx: idx, layer: layer, size: cs)
                    }
                }

                // Symmetry guides
                SymmetryGuides(mode: vm.symmetry, size: cs)
                    .allowsHitTesting(false)

                // Fill tap catcher (only active in fill mode, sits on top)
                if vm.toolMode == .fill {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: cs.width, height: cs.height)
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            vm.performFill(at: value.location)
                        })
                }
            }
            .frame(width: cs.width, height: cs.height)
            .clipped()
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .padding(16)
    }

    @ViewBuilder
    private func layerView(idx: Int, layer: Layer, size: CGSize) -> some View {
        if idx == vm.activeIndex && !layer.isReference {
            CanvasView(drawing: Binding(get: { vm.activeDrawing }, set: { vm.activeDrawing = $0 }),
                       tool: vm.currentTool,
                       isRulerActive: vm.isRulerActive,
                       pencilOnly: vm.pencilOnly,
                       symmetry: vm.symmetry,
                       canvasSize: size,
                       isLocked: layer.isLocked || vm.toolMode == .fill)
                .frame(width: size.width, height: size.height)
                .opacity(layer.opacity)
        } else {
            Image(uiImage: LayerCompositor.renderLayer(layer, size: size))
                .resizable()
                .frame(width: size.width, height: size.height)
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
