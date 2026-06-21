import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum SketchFilter: String, CaseIterable, Identifiable {
    case none
    case mono
    case sepia
    case vibrant
    case invert
    case comic
    case blur
    // Painting styles
    case oil
    case watercolor
    case pointillism
    case mosaic

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Original"
        case .mono: return "Mono"
        case .sepia: return "Sepia"
        case .vibrant: return "Vibrant"
        case .invert: return "Invert"
        case .comic: return "Comic"
        case .blur: return "Soft Blur"
        case .oil: return "Oil Painting"
        case .watercolor: return "Watercolor"
        case .pointillism: return "Pointillism"
        case .mosaic: return "Mosaic"
        }
    }

    /// Photographic / tonal filters.
    static var photo: [SketchFilter] { [.none, .mono, .sepia, .vibrant, .invert, .comic, .blur] }
    /// Painterly styles.
    static var painting: [SketchFilter] { [.oil, .watercolor, .pointillism, .mosaic] }
}

/// Applies Core Image effects to a composited sketch image.
enum FilterEngine {
    private static let context = CIContext()

    static func apply(_ filter: SketchFilter, to image: UIImage) -> UIImage {
        guard filter != .none, let input = CIImage(image: image) else { return image }
        var output: CIImage?

        switch filter {
        case .none:
            return image
        case .mono:
            let f = CIFilter.photoEffectMono()
            f.inputImage = input
            output = f.outputImage
        case .sepia:
            let f = CIFilter.sepiaTone()
            f.inputImage = input
            f.intensity = 0.9
            output = f.outputImage
        case .vibrant:
            let f = CIFilter.vibrance()
            f.inputImage = input
            f.amount = 1.0
            output = f.outputImage
        case .invert:
            let f = CIFilter.colorInvert()
            f.inputImage = input
            output = f.outputImage
        case .comic:
            let f = CIFilter.comicEffect()
            f.inputImage = input
            output = f.outputImage
        case .blur:
            let f = CIFilter.gaussianBlur()
            f.inputImage = input
            f.radius = 6
            output = f.outputImage?.cropped(to: input.extent)
        case .oil:
            // Painterly blobs via crystallize.
            let f = CIFilter.crystallize()
            f.inputImage = input
            f.radius = 18
            f.center = CGPoint(x: input.extent.midX, y: input.extent.midY)
            output = f.outputImage?.cropped(to: input.extent)
        case .watercolor:
            // Soft bloom + boosted saturation reads as washy watercolor.
            let blur = CIFilter.gaussianBlur(); blur.inputImage = input; blur.radius = 2.5
            let sat = CIFilter.colorControls()
            sat.inputImage = blur.outputImage?.cropped(to: input.extent)
            sat.saturation = 1.5; sat.brightness = 0.03
            output = sat.outputImage?.cropped(to: input.extent)
        case .pointillism:
            let f = CIFilter.pointillize()
            f.inputImage = input
            f.radius = 12
            f.center = CGPoint(x: input.extent.midX, y: input.extent.midY)
            output = f.outputImage?.cropped(to: input.extent)
        case .mosaic:
            let f = CIFilter.pixellate()
            f.inputImage = input
            f.scale = 16
            f.center = CGPoint(x: input.extent.midX, y: input.extent.midY)
            output = f.outputImage?.cropped(to: input.extent)
        }

        guard let result = output,
              let cg = context.createCGImage(result, from: input.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
