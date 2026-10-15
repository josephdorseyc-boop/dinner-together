import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The play button some video posts bake into their cover picture (Joe,
/// build 19: an Instagram reel's cover came with a big ▶ in the middle).
/// Found by its shape — a near-white triangle pointing right, alone at the
/// picture's centre, with no other white around it — and cropped away by
/// keeping the larger clean band above or below it. A photo without one is
/// left exactly as it was.
enum PlayOverlay {
    /// In the sampled picture's pixels: the triangle's centre and the radius
    /// of the disc to keep clear of.
    struct Hit: Equatable {
        var centerX: Double
        var centerY: Double
        var radius: Double
    }

    /// `luma`: row-major brightness 0…1 of a small copy of the picture.
    static func find(luma: [Double], width w: Int, height h: Int) -> Hit? {
        guard w >= 32, h >= 32, luma.count == w * h else { return nil }
        let side = Double(min(w, h))
        let cx = Double(w) / 2, cy = Double(h) / 2
        // Only the middle of the picture: a ▶ elsewhere is not the overlay.
        let half = Int(side * 0.2)
        let x0 = max(0, Int(cx) - half), x1 = min(w - 1, Int(cx) + half)
        let y0 = max(0, Int(cy) - half), y1 = min(h - 1, Int(cy) + half)
        let white = 0.86
        func isWhite(_ x: Int, _ y: Int) -> Bool { luma[y * w + x] > white }

        // The white blob nearest the centre (4-connected), within the box.
        var seen = Set<Int>()
        var best: [(Int, Int)] = []
        var bestDistance = Double.infinity
        for y in y0...y1 {
            for x in x0...x1 where isWhite(x, y) && !seen.contains(y * w + x) {
                var blob: [(Int, Int)] = []
                var queue = [(x, y)]
                seen.insert(y * w + x)
                var touchesEdge = false
                while let p = queue.popLast() {
                    let (px, py) = p
                    blob.append((px, py))
                    if px == x0 || px == x1 || py == y0 || py == y1 { touchesEdge = true }
                    for (nx, ny) in [(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)]
                    where nx >= x0 && nx <= x1 && ny >= y0 && ny <= y1 && isWhite(nx, ny) && !seen.contains(ny * w + nx) {
                        seen.insert(ny * w + nx)
                        queue.append((nx, ny))
                    }
                }
                guard !touchesEdge, blob.count >= 12 else { continue }
                let mx = Double(blob.map { $0.0 }.reduce(0, +)) / Double(blob.count)
                let my = Double(blob.map { $0.1 }.reduce(0, +)) / Double(blob.count)
                let d = hypot(mx - cx, my - cy)
                if d < bestDistance { bestDistance = d; best = blob }
            }
        }
        guard !best.isEmpty, bestDistance <= side * 0.08 else { return nil }
        let bx0 = best.map { $0.0 }.min()!, bx1 = best.map { $0.0 }.max()!
        let by0 = best.map { $0.1 }.min()!, by1 = best.map { $0.1 }.max()!
        let bw = Double(bx1 - bx0 + 1), bh = Double(by1 - by0 + 1)
        // A triangle about as wide as it is tall, a modest share of the picture.
        guard bh >= side * 0.04, bh <= side * 0.3, bw >= bh * 0.5, bw <= bh * 1.2 else { return nil }
        let fill = Double(best.count) / (bw * bh)
        guard fill >= 0.3, fill <= 0.7 else { return nil }
        // Pointing right: tall on the left, narrow at the tip.
        func columnHeight(_ x: Int) -> Int { best.filter { $0.0 == x }.count }
        let left = columnHeight(bx0 + Int(bw * 0.2)), right = columnHeight(bx1 - Int(bw * 0.2))
        guard Double(left) >= Double(right) * 1.8 + 1 else { return nil }
        // Symmetric top to bottom.
        func rowWidth(_ y: Int) -> Int { best.filter { $0.1 == y }.count }
        let top = rowWidth(by0 + Int(bh * 0.25)), bottom = rowWidth(by1 - Int(bh * 0.25))
        guard top > 0, bottom > 0, Double(max(top, bottom)) / Double(min(top, bottom)) <= 1.7 else { return nil }
        // Alone: no other white in the ring around it (the button's disc).
        let tx = Double(bx0 + bx1) / 2, ty = Double(by0 + by1) / 2
        let r0 = bh * 0.8, r1 = bh * 1.3
        var ring = 0, ringWhite = 0
        for y in max(0, Int(ty - r1))...min(h - 1, Int(ty + r1)) {
            for x in max(0, Int(tx - r1))...min(w - 1, Int(tx + r1)) {
                let d = hypot(Double(x) - tx, Double(y) - ty)
                guard d >= r0, d <= r1 else { continue }
                ring += 1
                if isWhite(x, y) { ringWhite += 1 }
            }
        }
        guard ring > 0, Double(ringWhite) / Double(ring) < 0.04 else { return nil }
        return Hit(centerX: tx, centerY: ty, radius: bh * 1.55)
    }

    /// The band of the picture to keep, in its own pixels: full width, above
    /// or below the button, whichever is taller; nil when neither is at
    /// least a quarter as tall as the picture is wide.
    static func cleanBand(width: Double, height: Double, hit: Hit, scale: Double) -> (y: Double, height: Double)? {
        let top = (hit.centerY - hit.radius) * scale
        let bottom = (hit.centerY + hit.radius) * scale
        let above = max(0, top), below = max(0, height - bottom)
        let band = above >= below ? (y: 0.0, height: above) : (y: bottom, height: below)
        return band.height >= width * 0.25 ? band : nil
    }

    #if canImport(UIKit)
    /// The picture without its play button, as JPEG; the original data when
    /// there is no button (or it cannot be read).
    static func cleaned(_ data: Data) -> Data {
        guard let image = UIImage(data: data), let cg = image.cgImage,
              let cropped = cropped(cg) else { return data }
        return UIImage(cgImage: cropped).jpegData(compressionQuality: 0.9) ?? data
    }

    static func cropped(_ cg: CGImage) -> CGImage? {
        let sampleW = 160
        let sampleH = max(32, Int((Double(cg.height) / Double(cg.width) * Double(sampleW)).rounded()))
        var bytes = [UInt8](repeating: 0, count: sampleW * sampleH * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: sampleW, height: sampleH, bitsPerComponent: 8,
                                      bytesPerRow: sampleW * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))
            return true
        }
        guard drawn else { return nil }
        var luma = [Double](repeating: 0, count: sampleW * sampleH)
        for i in 0..<(sampleW * sampleH) {
            let r = Double(bytes[i * 4]), g = Double(bytes[i * 4 + 1]), b = Double(bytes[i * 4 + 2])
            luma[i] = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        }
        guard let hit = find(luma: luma, width: sampleW, height: sampleH),
              let band = cleanBand(width: Double(cg.width), height: Double(cg.height), hit: hit,
                                   scale: Double(cg.width) / Double(sampleW)) else { return nil }
        return cg.cropping(to: CGRect(x: 0, y: band.y, width: Double(cg.width), height: band.height).integral)
    }
    #endif
}
