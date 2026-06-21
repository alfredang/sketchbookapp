import SwiftUI

struct BrushPanel: View {
    @ObservedObject var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SIZE").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                    HStack(spacing: 12) {
                        Slider(value: $vm.width, in: 1...60)
                        Text("\(Int(vm.width)) pt").font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.ink).frame(width: 52, alignment: .trailing)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("BRUSHES").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                    ForEach(BrushType.allCases.filter { $0 != .pencil }) { brush in
                        Button {
                            vm.selectBrush(brush)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: brush.systemImage)
                                    .font(.title3).frame(width: 28)
                                    .foregroundStyle(isSelectedBrush(brush) ? .white : Theme.primary)
                                Text(brush.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(isSelectedBrush(brush) ? .white : Theme.ink)
                                    .frame(width: 84, alignment: .leading)
                                BrushStrokePreview(brush: brush, color: vm.color)
                                    .frame(height: 30).frame(maxWidth: .infinity)
                                if isSelectedBrush(brush) { Image(systemName: "checkmark").foregroundStyle(.white) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(isSelectedBrush(brush) ? Theme.primary : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    Text("PENCILS").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                        .padding(.top, 8)
                    ForEach(PencilGrade.allCases) { grade in
                        Button {
                            vm.selectPencilGrade(grade)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "pencil")
                                    .font(.title3).frame(width: 28)
                                    .foregroundStyle(vm.pencilGrade == grade ? .white : Theme.primary)
                                Text("Pencil \(grade.title)")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(vm.pencilGrade == grade ? .white : Theme.ink)
                                    .frame(width: 84, alignment: .leading)
                                PencilStrokePreview(grade: grade)
                                    .frame(height: 30).frame(maxWidth: .infinity)
                                if vm.pencilGrade == grade { Image(systemName: "checkmark").foregroundStyle(.white) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(vm.pencilGrade == grade ? Theme.primary : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Brushes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func isSelectedBrush(_ brush: BrushType) -> Bool {
        vm.brush == brush && vm.pencilGrade == nil
    }
}

/// Preview squiggle for a graphite pencil grade (darkness + width).
struct PencilStrokePreview: View {
    let grade: PencilGrade
    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            var p = Path()
            p.move(to: CGPoint(x: 6, y: midY))
            p.addCurve(to: CGPoint(x: size.width - 6, y: midY),
                       control1: CGPoint(x: size.width * 0.33, y: midY - size.height * 0.42),
                       control2: CGPoint(x: size.width * 0.66, y: midY + size.height * 0.42))
            ctx.stroke(p, with: .color(grade.color.opacity(0.8)),
                       style: StrokeStyle(lineWidth: grade.width, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A sample squiggle rendered with each brush's characteristic width and opacity
/// so the brushes are visually distinguishable (icons alone read as similar).
struct BrushStrokePreview: View {
    let brush: BrushType
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            var p = Path()
            p.move(to: CGPoint(x: 6, y: midY))
            p.addCurve(to: CGPoint(x: size.width - 6, y: midY),
                       control1: CGPoint(x: size.width * 0.33, y: midY - size.height * 0.42),
                       control2: CGPoint(x: size.width * 0.66, y: midY + size.height * 0.42))
            let w = min(brush.defaultWidth, 22)
            var strokeColor = color
            switch brush {
            case .pencil, .crayon: strokeColor = color.opacity(0.65)
            case .marker, .watercolor: strokeColor = color.opacity(0.45)
            default: break
            }
            ctx.stroke(p, with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }
}

struct LayersPanel: View {
    @ObservedObject var vm: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var groupingIndex: Int?
    @State private var newGroupName = ""

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

                if !vm.groupNames.isEmpty {
                    Section("Groups") {
                        ForEach(vm.groupNames, id: \.self) { group in
                            HStack {
                                Image(systemName: "folder").foregroundStyle(Theme.primary)
                                Text(group).foregroundStyle(Theme.ink)
                                Spacer()
                                Button { vm.toggleGroupVisibility(group) } label: {
                                    Image(systemName: "eye").foregroundStyle(Theme.mutedInk)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Layers") {
                    ForEach(Array(vm.document.layers.enumerated()), id: \.element.id) { idx, layer in
                        LayerRow(vm: vm, index: idx, layer: layer) {
                            groupingIndex = idx
                            newGroupName = layer.groupName ?? ""
                        }
                    }
                    .onDelete { offsets in offsets.forEach { vm.deleteLayer(at: $0) } }
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
            .alert("Group Name", isPresented: Binding(get: { groupingIndex != nil },
                                                      set: { if !$0 { groupingIndex = nil } })) {
                TextField("Group name (empty to ungroup)", text: $newGroupName)
                Button("Save") {
                    if let i = groupingIndex { vm.setGroup(at: i, to: newGroupName) }
                    groupingIndex = nil
                }
                Button("Cancel", role: .cancel) { groupingIndex = nil }
            }
        }
    }
}

struct LayerRow: View {
    @ObservedObject var vm: EditorViewModel
    let index: Int
    let layer: Layer
    var onGroup: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                vm.document.layers[index].isVisible.toggle()
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(Theme.mutedInk)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Layer", text: Binding(
                    get: { layer.name },
                    set: { vm.renameLayer(at: index, to: $0) }))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    if let g = layer.groupName {
                        Label(g, systemImage: "folder").font(.caption2).foregroundStyle(Theme.secondary)
                    }
                    if layer.isReference {
                        Text("Reference").font(.caption2).foregroundStyle(Theme.secondary)
                    }
                }
            }

            if index == vm.activeIndex {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
            }
            Menu {
                Button { vm.setActiveLayer(index) } label: { Label("Select", systemImage: "hand.tap") }
                Button(action: onGroup) { Label("Move to Group…", systemImage: "folder.badge.plus") }
                if layer.groupName != nil {
                    Button { vm.setGroup(at: index, to: nil) } label: { Label("Ungroup", systemImage: "folder.badge.minus") }
                }
                Button { vm.document.layers[index].isLocked.toggle() } label: {
                    Label(layer.isLocked ? "Unlock" : "Lock", systemImage: layer.isLocked ? "lock.open" : "lock")
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(Theme.mutedInk)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.setActiveLayer(index) }
    }
}
