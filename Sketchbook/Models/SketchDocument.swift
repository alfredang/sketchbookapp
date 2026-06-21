import Foundation
import PencilKit
import UIKit

/// The persisted sketch document. Stored as JSON (`.sketch`) in the iCloud
/// Documents container (with a local fallback) by `DocumentStore`.
struct SketchDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var template: TemplateKind
    var canvasWidth: Double
    var canvasHeight: Double
    var backgroundHex: String
    var layers: [Layer]
    /// Index of the currently active (editable) layer.
    var activeLayerIndex: Int
    /// PNG thumbnail for the gallery grid.
    var thumbnailData: Data?
    /// Starred / favorite sketch.
    var isFavorite: Bool = false

    var canvasSize: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }

    var thumbnail: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

    static let defaultSize = CGSize(width: 2048, height: 1536) // landscape iPad-ish canvas

    init(id: UUID = UUID(),
         title: String = "Untitled",
         template: TemplateKind = .blank,
         size: CGSize = SketchDocument.defaultSize,
         backgroundHex: String = "#FFFFFF",
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.template = template
        self.canvasWidth = size.width
        self.canvasHeight = size.height
        self.backgroundHex = backgroundHex
        self.layers = [Layer(name: "Layer 1")]
        self.activeLayerIndex = 0
        self.thumbnailData = nil
    }

    var fileName: String { "\(id.uuidString).sketch" }
}
