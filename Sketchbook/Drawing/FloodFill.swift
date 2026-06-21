import UIKit

/// Bucket / color-fill using a scanline flood fill on a rasterised snapshot of
/// the current artwork. Returns a transparent image containing only the filled
/// region, which the editor composites onto the active layer.
enum FloodFill {
    /// - Parameters:
    ///   - base: composited snapshot used to detect region boundaries.
    ///   - point: seed point in `base`'s pixel coordinate space.
    ///   - fillColor: the color to paint.
    ///   - tolerance: 0...1 color match tolerance.
    static func fill(in base: UIImage, at point: CGPoint, with fillColor: UIColor, tolerance: CGFloat = 0.12) -> UIImage? {
        guard let cg = base.cgImage else { return nil }
        let width = cg.width, height = cg.height
        let sx = Int(point.x), sy = Int(point.y)
        guard sx >= 0, sy >= 0, sx < width, sy < height else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var src = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let ctx = CGContext(data: &src, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        func idx(_ x: Int, _ y: Int) -> Int { (y * width + x) * bytesPerPixel }
        let seed = idx(sx, sy)
        let target = (src[seed], src[seed + 1], src[seed + 2], src[seed + 3])

        let tol = UInt16(tolerance * 255)
        func matches(_ p: Int) -> Bool {
            func d(_ a: UInt8, _ b: UInt8) -> UInt16 { a > b ? UInt16(a - b) : UInt16(b - a) }
            return d(src[p], target.0) <= tol && d(src[p + 1], target.1) <= tol
                && d(src[p + 2], target.2) <= tol && d(src[p + 3], target.3) <= tol
        }

        // Output buffer (transparent) we paint into.
        var out = [UInt8](repeating: 0, count: bytesPerRow * height)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        fillColor.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        let cr = UInt8(fr * 255), cg2 = UInt8(fg * 255), cb = UInt8(fb * 255), ca = UInt8(fa * 255)

        var visited = [Bool](repeating: false, count: width * height)
        var stack = [(Int, Int)]()
        stack.append((sx, sy))

        while let (x, y) = stack.popLast() {
            if x < 0 || y < 0 || x >= width || y >= height { continue }
            let cell = y * width + x
            if visited[cell] { continue }
            let p = idx(x, y)
            if !matches(p) { continue }
            visited[cell] = true
            out[p] = cr; out[p + 1] = cg2; out[p + 2] = cb; out[p + 3] = ca
            stack.append((x + 1, y)); stack.append((x - 1, y))
            stack.append((x, y + 1)); stack.append((x, y - 1))
        }

        guard let outCtx = CGContext(data: &out, width: width, height: height, bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let outCG = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: base.scale, orientation: .up)
    }
}
