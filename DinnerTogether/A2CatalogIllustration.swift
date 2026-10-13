import Foundation
import SwiftUI

/// Optional, additive adapter for A2CatalogArtwork.json. No recipe, session,
/// navigation or timing logic. Add the JSON to the APP target's resources.
/// Native compilation/rendering is pending A3's Xcode verification.
@MainActor
enum A2CatalogArtworkStore {
    struct Command: Decodable, Sendable {
        let op: String
        let values: [Double]
    }
    struct Layer: Decodable, Sendable {
        let kind: String
        let values: [Double]
        let commands: [Command]
        let fill: String?
        let stroke: String?
        let strokeWidth: Double
        let detail: Bool
        let opacity: Double
    }
    struct Drawing: Decodable, Sendable {
        let id: String
        let label: String
        let viewBox: [Double]
        let layers: [Layer]
    }
    private struct Document: Decodable {
        let schemaVersion: Int
        let drawings: [Drawing]
    }
    enum LoadFailure: String {
        case missingResource, unreadableResource, unsupportedSchema, invalidDrawing
    }
    private struct Loaded {
        let drawings: [String: Drawing]
        let failure: LoadFailure?
    }
    private static let loaded: Loaded = load()

    /// Diagnostics for integration: missing resource must not look like a
    /// successful conversion of the pack. The neutral glyph is a fallback.
    static var loadFailure: LoadFailure? { loaded.failure }
    static var drawingCount: Int { loaded.drawings.count }
    static func drawing(id: String) -> Drawing? { loaded.drawings[id] }
    static func menu(_ id: String) -> Drawing? { drawing(id: "menu:" + id) }
    /// Use the catalog's exact dish label. Never infer food from recipe prose.
    static func dish(_ label: String) -> Drawing? { drawing(id: "dish:" + label) }

    private static func load() -> Loaded {
        guard let url = Bundle.main.url(forResource: "A2CatalogArtwork", withExtension: "json") else {
            return Loaded(drawings: [:], failure: .missingResource)
        }
        guard let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data) else {
            return Loaded(drawings: [:], failure: .unreadableResource)
        }
        guard doc.schemaVersion == 1 else {
            return Loaded(drawings: [:], failure: .unsupportedSchema)
        }
        var result: [String: Drawing] = [:]
        let lengths = ["M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0]
        for drawing in doc.drawings {
            guard !drawing.id.isEmpty, result[drawing.id] == nil,
                  drawing.viewBox == [0, 0, 256, 256], !drawing.layers.isEmpty else {
                return Loaded(drawings: [:], failure: .invalidDrawing)
            }
            for layer in drawing.layers {
                guard layer.opacity.isFinite, (0...1).contains(layer.opacity),
                      layer.strokeWidth.isFinite, layer.strokeWidth >= 0,
                      layer.values.allSatisfy({ $0.isFinite }),
                      [layer.fill, layer.stroke].allSatisfy({ hex in
                          guard let hex else { return true }
                          return validHex(hex)
                      }) else {
                    return Loaded(drawings: [:], failure: .invalidDrawing)
                }
                switch layer.kind {
                case "ellipse":
                    guard layer.values.count == 4,
                          layer.values[2] > 0, layer.values[3] > 0 else {
                        return Loaded(drawings: [:], failure: .invalidDrawing)
                    }
                case "path":
                    guard !layer.commands.isEmpty else {
                        return Loaded(drawings: [:], failure: .invalidDrawing)
                    }
                    for command in layer.commands {
                        guard lengths[command.op] == command.values.count,
                              command.values.allSatisfy({ $0.isFinite }) else {
                            return Loaded(drawings: [:], failure: .invalidDrawing)
                        }
                    }
                default: return Loaded(drawings: [:], failure: .invalidDrawing)
                }
            }
            result[drawing.id] = drawing
        }
        guard !result.isEmpty else { return Loaded(drawings: [:], failure: .invalidDrawing) }
        return Loaded(drawings: result, failure: nil)
    }

    private static func validHex(_ value: String) -> Bool {
        value.count == 7 && value.first == "#" && UInt32(value.dropFirst(), radix: 16) != nil
    }
}

/// Decoration only. The surrounding row/card supplies its actual dish/menu
/// label, selection and cooking status; the illustration never implies Done.
@MainActor
struct A2CatalogIllustration: View {
    let artworkID: String

    init(menuID: String) { artworkID = "menu:" + menuID }
    init(dish: String) { artworkID = "dish:" + dish }

    var body: some View {
        Group {
            if let drawing = A2CatalogArtworkStore.drawing(id: artworkID) {
                Canvas { context, size in
                    let side = min(size.width, size.height)
                    guard side.isFinite, side > 0 else { return }
                    var base = context
                    base.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
                    base.scaleBy(x: side / 256, y: side / 256)
                    for layer in drawing.layers where side > 64 || !layer.detail {
                        let path = Self.path(layer)
                        var paint = base
                        paint.opacity *= layer.opacity
                        if let fill = Self.color(layer.fill) {
                            paint.fill(path, with: .color(fill))
                        }
                        if let stroke = Self.color(layer.stroke), layer.strokeWidth > 0 {
                            paint.stroke(path, with: .color(stroke),
                                         style: StrokeStyle(lineWidth: CGFloat(layer.strokeWidth),
                                                            lineCap: .round, lineJoin: .round))
                        }
                    }
                }
            } else {
                // Unknown recipes or missing resources never borrow another
                // dinner's illustration. Callers can retain their own fallback.
                Image(systemName: "fork.knife")
                    .resizable().scaledToFit().padding(10)
                    .foregroundStyle(Theme.olive)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    nonisolated private static func color(_ hex: String?) -> Color? {
        guard let hex, let number = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return Color(.sRGB, red: Double((number >> 16) & 255) / 255,
                     green: Double((number >> 8) & 255) / 255,
                     blue: Double(number & 255) / 255, opacity: 1)
    }

    nonisolated private static func path(_ layer: A2CatalogArtworkStore.Layer) -> Path {
        if layer.kind == "ellipse" {
            let v = layer.values
            return Path(ellipseIn: CGRect(x: CGFloat(v[0] - v[2]), y: CGFloat(v[1] - v[3]),
                                           width: CGFloat(v[2] * 2), height: CGFloat(v[3] * 2)))
        }
        var path = Path()
        for command in layer.commands {
            let v = command.values
            func point(_ start: Int) -> CGPoint {
                CGPoint(x: CGFloat(v[start]), y: CGFloat(v[start + 1]))
            }
            switch command.op {
            case "M": path.move(to: point(0))
            case "L": path.addLine(to: point(0))
            case "Q": path.addQuadCurve(to: point(2), control: point(0))
            case "C": path.addCurve(to: point(4), control1: point(0), control2: point(2))
            case "Z": path.closeSubpath()
            default: break // Rejected by the loader before rendering.
            }
        }
        return path
    }
}
