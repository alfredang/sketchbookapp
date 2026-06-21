import Foundation
import PencilKit
import UIKit

/// A single drawing layer. Each layer owns its own PencilKit drawing and can
/// optionally hold a raster image (used for imported reference photos and for
/// the flood-fill raster layer).
struct Layer: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    /// Serialized `PKDrawing` (`dataRepresentation()`); empty for image-only layers.
    var drawingData: Data
    /// Optional raster contents (PNG) — imported reference photo or fill bitmap.
    var imageData: Data?
    /// When true this is a non-printing tracing reference and is excluded from exports.
    var isReference: Bool
    /// Optional group name for organizing layers (nil = ungrouped).
    var groupName: String?

    init(id: UUID = UUID(),
         name: String,
         isVisible: Bool = true,
         isLocked: Bool = false,
         opacity: Double = 1.0,
         drawing: PKDrawing = PKDrawing(),
         imageData: Data? = nil,
         isReference: Bool = false,
         groupName: String? = nil) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.drawingData = drawing.dataRepresentation()
        self.imageData = imageData
        self.isReference = isReference
        self.groupName = groupName
    }

    var drawing: PKDrawing {
        get { (try? PKDrawing(data: drawingData)) ?? PKDrawing() }
        set { drawingData = newValue.dataRepresentation() }
    }

    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
}
