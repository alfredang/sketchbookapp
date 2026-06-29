import SwiftUI

/// Tabs available in the iPad right-side panel.
enum SidePanelTab: String, CaseIterable, Identifiable {
    case brush, color, layers
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .color: return "paintpalette.fill"
        case .layers: return "square.3.layers.3d"
        }
    }
    var title: String {
        switch self {
        case .brush: return "Brushes"
        case .color: return "Color"
        case .layers: return "Layers"
        }
    }
}

/// Collapsible, tabbed inspector shown on the right on iPad. Lets the user
/// switch brushes, pick colors, and manage layers without leaving the canvas.
/// Collapse it to focus on the sketch; expand it to access the tools.
struct EditorSidePanel: View {
    @ObservedObject var vm: EditorViewModel
    @Binding var tab: SidePanelTab
    var onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 320)
        .background(Theme.background)
        .overlay(Divider(), alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onCollapse) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .help("Collapse panel")

            Spacer()

            HStack(spacing: 4) {
                ForEach(SidePanelTab.allCases) { t in
                    Button { tab = t } label: {
                        Image(systemName: t.systemImage)
                            .font(.body)
                            .foregroundStyle(tab == t ? .white : Theme.ink)
                            .frame(width: 44, height: 36)
                            .background(tab == t ? Theme.primary : .clear,
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .help(t.title)
                    .accessibilityLabel(t.title)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .brush:
            BrushPickerContent(vm: vm).background(Theme.background)
        case .color:
            ColorPickerContent(vm: vm)
        case .layers:
            LayersPanel(vm: vm, embedded: true)
        }
    }
}

/// Color tab: live color well + opacity, plus a quick palette of swatches.
struct ColorPickerContent: View {
    @ObservedObject var vm: EditorViewModel

    private let swatches: [String] = [
        "#111418", "#5B5F66", "#9AA0A6", "#FFFFFF",
        "#E53935", "#FB8C00", "#FDD835", "#43A047",
        "#1E88E5", "#3949AB", "#8E24AA", "#D81B60",
        "#6D4C41", "#00897B", "#00ACC1", "#C0CA33",
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("COLOR").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                ColorPicker("Selected color", selection: $vm.color, supportsOpacity: true)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("PALETTE").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(swatches, id: \.self) { hex in
                        let color = Color(hex: hex)
                        Button { vm.color = color } label: {
                            Circle()
                                .fill(color)
                                .frame(height: 48)
                                .overlay(Circle().stroke(Theme.mutedInk.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }
}
