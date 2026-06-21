import SwiftUI

struct NewSketchSheet: View {
    var onCreate: (SketchDocument) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = "Untitled"
    @State private var template: TemplateKind = .blank
    @State private var landscape = true

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Title", text: $title).textFieldStyle(.roundedBorder)
                    Toggle("Landscape", isOn: $landscape)

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let base = SketchDocument.defaultSize
                        let size = landscape ? base : CGSize(width: base.height, height: base.width)
                        let doc = SketchDocument(title: title.isEmpty ? "Untitled" : title,
                                                 template: template, size: size)
                        onCreate(doc)
                    }
                }
            }
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
