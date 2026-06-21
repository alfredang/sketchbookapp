import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var newSketch: SketchDocument?
    @State private var openSketch: SketchDocument?
    @State private var showingNewSheet = false
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 20)]

    /// Favorites first, then most-recently modified.
    private var sortedDocuments: [SketchDocument] {
        store.documents.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.documents.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(sortedDocuments) { doc in
                            SketchCell(document: doc) { store.toggleFavorite(doc) }
                                .onTapGesture { openSketch = doc }
                                .contextMenu {
                                    Button { openSketch = doc } label: { Label("Open", systemImage: "pencil") }
                                    Button { store.toggleFavorite(doc) } label: {
                                        Label(doc.isFavorite ? "Unfavorite" : "Favorite",
                                              systemImage: doc.isFavorite ? "star.slash" : "star")
                                    }
                                    Button { store.duplicate(doc) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                    Button(role: .destructive) { store.delete(doc) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Sketches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewSheet = true } label: { Label("New", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNewSheet) {
                NewSketchSheet { doc in
                    let saved = store.save(doc)
                    showingNewSheet = false
                    openSketch = saved
                }
            }
            .fullScreenCover(item: $openSketch) { doc in
                EditorView(document: doc)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(store)
            }
            .task {
                await store.reload()
                if ProcessInfo.processInfo.environment["SKETCH_OPEN"] == "1" {
                    openSketch = store.documents.first
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 64)).foregroundStyle(Theme.primary)
            Text("No sketches yet").font(.title2.bold()).foregroundStyle(Theme.ink)
            Text("Tap + to start your first sketch.").foregroundStyle(Theme.mutedInk)
            Button { showingNewSheet = true } label: {
                Label("New Sketch", systemImage: "plus")
                    .foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.primary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

struct SketchCell: View {
    let document: SketchDocument
    var onToggleFavorite: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface)
                    if let thumb = document.thumbnail {
                        Image(uiImage: thumb).resizable().scaledToFit().padding(8)
                    } else {
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(Theme.mutedInk)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06)))

                Button(action: onToggleFavorite) {
                    Image(systemName: document.isFavorite ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(document.isFavorite ? Theme.highlight : .white)
                        .padding(7)
                        .background(.black.opacity(0.28), in: Circle())
                }
                .padding(8)
            }

            Text(document.title).font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink).lineLimit(1)
            Text(document.modifiedAt, style: .date).font(.caption).foregroundStyle(Theme.mutedInk)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
    }
}
