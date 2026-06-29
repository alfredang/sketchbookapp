import SwiftUI

struct NewSketchSheet: View {
    var onCreate: (SketchDocument) -> Void
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplate = TemplateKind.blank.rawValue
    @AppStorage(SettingsKey.defaultLandscape) private var defaultLandscape = true
    @State private var title = "Untitled"
    @State private var template: TemplateKind = .blank
    @State private var landscape = true
    @State private var preset: CanvasPreset = .standard
    @State private var paper: PaperColor = .white

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]
    private let sizeColumns = [GridItem(.adaptive(minimum: 96), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Title", text: $title).textFieldStyle(.roundedBorder)
                    Toggle("Landscape", isOn: $landscape)

                    Text("CANVAS SIZE").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                    LazyVGrid(columns: sizeColumns, spacing: 14) {
                        ForEach(CanvasPreset.allCases) { p in
                            CanvasSizeChip(preset: p, landscape: landscape, isSelected: preset == p)
                                .onTapGesture { preset = p }
                        }
                    }

                    Text("PAPER").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                    HStack(spacing: 14) {
                        ForEach(PaperColor.allCases) { c in
                            PaperChip(paper: c, isSelected: paper == c)
                                .onTapGesture { paper = c }
                        }
                    }

                    Text("TEMPLATE").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(TemplateKind.allCases) { kind in
                            TemplateChip(kind: kind, isSelected: template == kind)
                                .onTapGesture { template = kind }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("New Sketch")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                template = TemplateKind(rawValue: defaultTemplate) ?? .blank
                landscape = defaultLandscape
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let size = preset.size(landscape: landscape)
                        let doc = SketchDocument(title: title.isEmpty ? "Untitled" : title,
                                                 template: template, size: size,
                                                 backgroundHex: paper.hex)
                        onCreate(doc)
                    }
                }
            }
        }
    }
}

/// A canvas size / aspect-ratio preset chip. Draws a proportional rectangle
/// preview that flips with the Landscape toggle.
struct CanvasSizeChip: View {
    let preset: CanvasPreset
    let landscape: Bool
    let isSelected: Bool

    private var ratio: CGSize {
        let s = preset.size(landscape: landscape)
        let m = max(s.width, s.height)
        return CGSize(width: s.width / m, height: s.height / m)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.9) : Theme.surface)
                    .frame(width: 44 * ratio.width, height: 44 * ratio.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isSelected ? .clear : Theme.mutedInk.opacity(0.4), lineWidth: 1.5)
                    )
            }
            .frame(width: 56, height: 56)
            .background(isSelected ? Theme.primary : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(spacing: 1) {
                Text(preset.title).font(.caption).foregroundStyle(Theme.ink)
                Text(preset.subtitle).font(.caption2).foregroundStyle(Theme.mutedInk)
            }
        }
    }
}

/// A paper-colour swatch chip.
struct PaperChip: View {
    let paper: PaperColor
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: paper.hex))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Theme.mutedInk.opacity(0.3), lineWidth: 1))
                .overlay(
                    Circle().stroke(Theme.primary, lineWidth: isSelected ? 3 : 0).padding(-3)
                )
            Text(paper.title).font(.caption2).foregroundStyle(Theme.ink)
        }
    }
}

struct TemplateChip: View {
    let kind: TemplateKind
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: kind.systemImage)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : Theme.primary)
                .frame(width: 56, height: 56)
                .background(isSelected ? Theme.primary : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(kind.title).font(.caption).foregroundStyle(Theme.ink)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Theme.primary : Color.black.opacity(0.06), lineWidth: 2)
                .frame(width: 56, height: 56)
                .offset(y: -16)
        )
    }
}
