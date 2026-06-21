import SwiftUI

struct BrushPanel: View {
    @ObservedObject var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(BrushType.allCases) { brush in
                        Button {
                            vm.selectBrush(brush)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: brush.systemImage).font(.title2)
                                Text(brush.title).font(.caption)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(vm.brush == brush ? .white : Theme.ink)
                            .background(vm.brush == brush ? Theme.primary : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Brushes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LayersPanel: View {
    @ObservedObject var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if vm.referenceLayerIndex != nil {
                    Section("Reference Overlay") {
                        VStack(alignment: .leading) {
                            Text("Tracing opacity: \(Int(vm.referenceOpacity * 100))%")
                                .font(.caption).foregroundStyle(Theme.mutedInk)
                            Slider(value: Binding(get: { vm.referenceOpacity },
                                                  set: { vm.updateReferenceOpacity($0) }), in: 0...1)
                        }
                    }
                }
                Section("Layers") {
                    ForEach(Array(vm.document.layers.enumerated()), id: \.element.id) { idx, layer in
                        LayerRow(vm: vm, index: idx, layer: layer)
                    }
                    .onDelete { offsets in
                        offsets.forEach { vm.deleteLayer(at: $0) }
                    }
                    .onMove { source, dest in vm.moveLayer(from: source, to: dest) }
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { vm.duplicateActiveLayer() } label: { Image(systemName: "plus.square.on.square") }
                    Button { vm.addLayer() } label: { Image(systemName: "plus") }
                }
            }
        }
    }
}

struct LayerRow: View {
    @ObservedObject var vm: EditorViewModel
    let index: Int
    let layer: Layer

    var body: some View {
        HStack {
            Button {
                vm.document.layers[index].isVisible.toggle()
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(Theme.mutedInk)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name).foregroundStyle(Theme.ink)
                if layer.isReference {
                    Text("Reference").font(.caption2).foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            if index == vm.activeIndex {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
            }
            Button {
                vm.document.layers[index].isLocked.toggle()
            } label: {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(Theme.mutedInk)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.setActiveLayer(index) }
    }
}
