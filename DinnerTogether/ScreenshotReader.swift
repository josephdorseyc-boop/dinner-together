import Foundation
import Vision
import CoreGraphics
import ImageIO

/// Reads the text in screenshots or photos with Apple's on-device text
/// recognition. Nothing leaves the phone. iOS only (not in the Linux harness):
/// the parsing it feeds, `RecipeImporter.parse(screenshots:)`, is pure and
/// tested there.
enum ScreenshotReader {

    static func lines(in data: Data) async throws -> [OCRLine] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let orientation = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])?[kCGImagePropertyOrientation]
            .flatMap { ($0 as? UInt32).flatMap(CGImagePropertyOrientation.init(rawValue:)) } ?? .up
        return try await lines(in: image, orientation: orientation)
    }

    static func lines(in image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> [OCRLine] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
            return (request.results ?? []).compactMap { obs -> OCRLine? in
                guard let best = obs.topCandidates(1).first else { return nil }
                let box = obs.boundingBox // normalized, origin bottom-left
                return OCRLine(text: best.string,
                               top: Double(1 - box.origin.y - box.height),
                               left: Double(box.origin.x),
                               height: Double(box.height))
            }
        }.value
    }
}
