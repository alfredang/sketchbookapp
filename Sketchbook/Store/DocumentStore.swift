import Foundation
import Combine

/// Persists `SketchDocument`s to the user's **iCloud Documents** container so
/// sketches sync across their iPad / iPhone. Falls back to the app's local
/// Documents directory when iCloud is unavailable (e.g. signed-out simulator).
@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [SketchDocument] = []
    @Published private(set) var usingICloud: Bool = false

    private let ubiquityContainerID = "iCloud.com.tertiaryinfotech.sketchbookapp"
    private let fileExtension = "sketch"
    private var metadataQuery: NSMetadataQuery?

    init() {
        resolveContainerAndLoad()
    }

    // MARK: - Container resolution

    /// Directory where sketches live. Prefers the iCloud `Documents` folder.
    private func documentsDirectory() -> URL {
        let fm = FileManager.default
        if let container = fm.url(forUbiquityContainerIdentifier: ubiquityContainerID) {
            let docs = container.appendingPathComponent("Documents", isDirectory: true)
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
            usingICloud = true
            return docs
        }
        usingICloud = false
        return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func resolveContainerAndLoad() {
        // Resolving the ubiquity container can block; do it off the main actor.
        Task.detached { [weak self] in
            guard let self else { return }
            await self.reload()
        }
    }

    // MARK: - CRUD

    func reload() async {
        let dir = documentsDirectory()
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.pathExtension == fileExtension } ?? []
        var loaded: [SketchDocument] = []
        for url in urls {
            // Make sure iCloud has materialised the file locally.
            try? fm.startDownloadingUbiquitousItem(at: url)
            if let data = try? Data(contentsOf: url),
               let doc = try? JSONDecoder().decode(SketchDocument.self, from: data) {
                loaded.append(doc)
            }
        }
        loaded.sort { $0.modifiedAt > $1.modifiedAt }
        // Screenshot-only sample seeding (gated by SKETCH_SEED env; no-op in production).
        if loaded.isEmpty && SampleArt.seedRequested {
            for s in SampleArt.makeSamples() { loaded.append(save(s)) }
            loaded.sort { $0.modifiedAt > $1.modifiedAt }
        }
        self.documents = loaded
    }

    @discardableResult
    func save(_ document: SketchDocument) -> SketchDocument {
        var doc = document
        doc.modifiedAt = Date()
        let url = documentsDirectory().appendingPathComponent(doc.fileName)
        if let data = try? JSONEncoder().encode(doc) {
            try? data.write(to: url, options: .atomic)
        }
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[idx] = doc
        } else {
            documents.insert(doc, at: 0)
        }
        documents.sort { $0.modifiedAt > $1.modifiedAt }
        return doc
    }

    func delete(_ document: SketchDocument) {
        let url = documentsDirectory().appendingPathComponent(document.fileName)
        try? FileManager.default.removeItem(at: url)
        documents.removeAll { $0.id == document.id }
    }

    /// Duplicate an existing sketch into a brand-new document.
    @discardableResult
    func duplicate(_ document: SketchDocument) -> SketchDocument {
        var copy = document
        copy.id = UUID()
        copy.title = document.title + " copy"
        copy.createdAt = Date()
        copy.modifiedAt = Date()
        return save(copy)
    }
}
