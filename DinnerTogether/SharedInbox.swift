import Foundation

// The hand-off between the share extension and the app (phase 1b of the
// TikTok/Instagram request, modeled on Mela): Share → "Dinner, Together"
// drops the shared link, text or images into an App Group container; the
// app picks it up the next time it comes to the front and opens Add recipe
// with it. Compiled into both targets; no UIKit so the Linux harness can
// test the file format.

/// One shared item, as the share sheet delivered it.
struct SharedItem: Codable, Equatable {
    enum Kind: String, Codable { case link, text, images }
    var kind: Kind
    var url: URL?
    var text: String?
    /// File names inside the inbox folder, in the order shared.
    var imageFiles: [String] = []
    var createdAt: Date = Date()
}

enum SharedInbox {
    static let fileName = "shared-import.json"

    /// The first http(s) link in shared text (a TikTok share arrives as text
    /// on some versions).
    static func firstURL(in text: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>()]+"#) else { return nil }
        let ns = NSString(string: text)
        return regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            .compactMap { URL(string: ns.substring(with: $0.range).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))) }
            .first
    }
    static let imagesFolder = "shared-import-images"

    /// `group.<app bundle id>`; the extension's own id ends in ".share".
    static func groupIdentifier(bundleIdentifier: String) -> String {
        var base = bundleIdentifier
        if base.hasSuffix(".share") { base = String(base.dropLast(6)) }
        return "group." + base
    }

    /// Writes the item (and its images) so the app finds exactly one.
    static func write(_ item: SharedItem, images: [Data], in container: URL) throws {
        let folder = container.appending(path: imagesFolder, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        var stored = item
        if !images.isEmpty {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            stored.imageFiles = []
            for (i, data) in images.enumerated() {
                let name = "shared-\(i + 1).img"
                try data.write(to: folder.appending(path: name), options: .atomic)
                stored.imageFiles.append(name)
            }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(stored).write(to: container.appending(path: fileName), options: .atomic)
    }

    /// Reads and removes the pending item, with its images' bytes. Nil when
    /// nothing is waiting or the file is older than a day (a stale hand-off
    /// should not pop up a sheet out of nowhere).
    static func take(from container: URL, now: Date = Date()) -> (item: SharedItem, images: [Data])? {
        let file = container.appending(path: fileName)
        guard let data = try? Data(contentsOf: file) else { return nil }
        defer { try? FileManager.default.removeItem(at: file) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let item = try? decoder.decode(SharedItem.self, from: data) else { return nil }
        let folder = container.appending(path: imagesFolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        guard now.timeIntervalSince(item.createdAt) < 86_400 else { return nil }
        let images = item.imageFiles.compactMap { try? Data(contentsOf: folder.appending(path: $0)) }
        return (item, images)
    }
}
