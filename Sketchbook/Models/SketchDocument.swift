import Foundation
import PencilKit
import UIKit

/// A single page within a sketchbook. Each page owns its own layer stack.
struct Page: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var layers: [Layer] = [Layer(name: "Layer 1")]
    var activeLayerIndex: Int = 0
}

/// The persisted sketch document — a sketchbook of one or more pages. Stored as
/// JSON (`.sketch`) in the iCloud Documents container (with a local fallback).
struct SketchDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var template: TemplateKind
    var canvasWidth: Double
    var canvasHeight: Double
    var backgroundHex: String
    /// All pages in the sketchbook (always ≥ 1).
    var pages: [Page]
    /// Index of the currently visible page.
    var currentPageIndex: Int
    /// PNG thumbnail for the gallery grid.
    var thumbnailData: Data?
    /// Starred / favorite sketch.
    var isFavorite: Bool = false

    var canvasSize: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }

    var thumbnail: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

    /// Layers of the current page. Proxied so existing per-layer code is unchanged.
    var layers: [Layer] {
        get { pages.indices.contains(currentPageIndex) ? pages[currentPageIndex].layers : [] }
        set {
            guard pages.indices.contains(currentPageIndex) else { return }
            pages[currentPageIndex].layers = newValue
        }
    }

    /// Active (editable) layer index within the current page.
    var activeLayerIndex: Int {
        get { pages.indices.contains(currentPageIndex) ? pages[currentPageIndex].activeLayerIndex : 0 }
        set {
            guard pages.indices.contains(currentPageIndex) else { return }
            pages[currentPageIndex].activeLayerIndex = newValue
        }
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
        self.pages = [Page()]
        self.currentPageIndex = 0
        self.thumbnailData = nil
    }

    var fileName: String { "\(id.uuidString).sketch" }

    // MARK: Codable (with migration from the old single-page format)

    enum CodingKeys: String, CodingKey {
        case id, title, createdAt, modifiedAt, template, canvasWidth, canvasHeight
        case backgroundHex, pages, currentPageIndex, thumbnailData, isFavorite
        case layers, activeLayerIndex   // legacy keys (decode only)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        template = try c.decode(TemplateKind.self, forKey: .template)
        canvasWidth = try c.decode(Double.self, forKey: .canvasWidth)
        canvasHeight = try c.decode(Double.self, forKey: .canvasHeight)
        backgroundHex = try c.decode(String.self, forKey: .backgroundHex)
        thumbnailData = try c.decodeIfPresent(Data.self, forKey: .thumbnailData)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        if let decodedPages = try c.decodeIfPresent([Page].self, forKey: .pages), !decodedPages.isEmpty {
            pages = decodedPages
            currentPageIndex = try c.decodeIfPresent(Int.self, forKey: .currentPageIndex) ?? 0
        } else {
            // Migrate a document saved before multi-page support.
            let legacyLayers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? [Layer(name: "Layer 1")]
            let legacyActive = try c.decodeIfPresent(Int.self, forKey: .activeLayerIndex) ?? 0
            pages = [Page(layers: legacyLayers, activeLayerIndex: legacyActive)]
            currentPageIndex = 0
        }
        currentPageIndex = min(max(0, currentPageIndex), pages.count - 1)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(modifiedAt, forKey: .modifiedAt)
        try c.encode(template, forKey: .template)
        try c.encode(canvasWidth, forKey: .canvasWidth)
        try c.encode(canvasHeight, forKey: .canvasHeight)
        try c.encode(backgroundHex, forKey: .backgroundHex)
        try c.encode(pages, forKey: .pages)
        try c.encode(currentPageIndex, forKey: .currentPageIndex)
        try c.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try c.encode(isFavorite, forKey: .isFavorite)
    }
}

/// Canvas size / aspect-ratio presets offered when creating a new sketch.
/// Each preset stores its **portrait** pixel dimensions; the New Sketch sheet
/// flips width/height when Landscape is chosen.
enum CanvasPreset: String, CaseIterable, Identifiable {
    case square
    case standard    // 3:4
    case wide        // 9:16
    case a4          // ISO A4 print
    case letter      // US Letter print

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return "Square"
        case .standard: return "Standard"
        case .wide: return "Wide"
        case .a4: return "A4"
        case .letter: return "Letter"
        }
    }

    var subtitle: String {
        switch self {
        case .square: return "1:1"
        case .standard: return "3:4"
        case .wide: return "9:16"
        case .a4: return "ISO A4"
        case .letter: return "US Letter"
        }
    }

    var systemImage: String {
        switch self {
        case .square: return "square"
        case .standard: return "rectangle.portrait"
        case .wide: return "rectangle.portrait"
        case .a4: return "doc"
        case .letter: return "doc.plaintext"
        }
    }

    /// Portrait pixel size for the preset.
    var portraitSize: CGSize {
        switch self {
        case .square: return CGSize(width: 2048, height: 2048)
        case .standard: return CGSize(width: 1536, height: 2048)
        case .wide: return CGSize(width: 1170, height: 2080)
        case .a4: return CGSize(width: 1654, height: 2339)
        case .letter: return CGSize(width: 1700, height: 2200)
        }
    }

    func size(landscape: Bool) -> CGSize {
        let s = portraitSize
        guard landscape, self != .square else { return s }
        return CGSize(width: s.height, height: s.width)
    }
}

/// Paper (canvas background) colour choices offered when creating a sketch.
enum PaperColor: String, CaseIterable, Identifiable {
    case white
    case cream
    case gray
    case black

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var hex: String {
        switch self {
        case .white: return "#FFFFFF"
        case .cream: return "#FBF6EC"
        case .gray: return "#3A3D42"
        case .black: return "#111418"
        }
    }
}
