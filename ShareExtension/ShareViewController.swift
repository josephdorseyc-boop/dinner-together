import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// The "Dinner, Together" entry in the share sheet. Takes a link (TikTok,
/// Instagram, a recipe site), text, or screenshots, puts them in the App
/// Group inbox, and tells the cook to open the app — an extension cannot
/// open its app itself, and the import (network, text recognition) belongs
/// in the app where the result can be reviewed and saved.
final class ShareViewController: UIViewController {
    private var state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: ShareSheetView(state: state, done: { [weak self] in self?.finish() }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await collect() }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Reads what was shared, in order: a URL, else text, else images.
    private func collect() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        var url: URL?
        var text: String?
        var images: [Data] = []
        for p in providers {
            if url == nil, p.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let loaded = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL { url = loaded; continue }
            if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let data = try? await loadImageData(p) { images.append(data) }
                continue
            }
            if text == nil, p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let loaded = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { text = loaded }
        }
        // A URL typed into a text share counts as a link.
        if url == nil, let t = text, let found = SharedInbox.firstURL(in: t) { url = found; text = nil }
        let item: SharedItem
        if let url { item = SharedItem(kind: .link, url: url) }
        else if !images.isEmpty { item = SharedItem(kind: .images) }
        else if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { item = SharedItem(kind: .text, text: text) }
        else { state.outcome = .nothing; return }
        guard let bundle = Bundle.main.bundleIdentifier,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedInbox.groupIdentifier(bundleIdentifier: bundle)) else {
            state.outcome = .failed("The shared container isn’t available."); return
        }
        do {
            try SharedInbox.write(item, images: images, in: container)
            state.outcome = .saved(item.kind, images.count)
        } catch {
            state.outcome = .failed(error.localizedDescription)
        }
    }

    private func loadImageData(_ provider: NSItemProvider) async throws -> Data? {
        if let data = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? Data { return data }
        if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL { return try Data(contentsOf: url) }
        if let image = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? UIImage { return image.pngData() }
        return try await withCheckedThrowingContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: data) }
            }
        }
    }
}

@MainActor
final class ShareState: ObservableObject {
    enum Outcome: Equatable { case working, saved(SharedItem.Kind, Int), nothing, failed(String) }
    @Published var outcome: Outcome = .working
}

struct ShareSheetView: View {
    @ObservedObject var state: ShareState
    var done: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "frying.pan").font(.largeTitle).foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(red: 0.659, green: 0.220, blue: 0.153), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            switch state.outcome {
            case .working:
                ProgressView("Saving…")
            case .saved(let kind, let count):
                Text("Saved to Dinner, Together").font(.title3.weight(.semibold))
                Text(message(kind, count)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .nothing:
                Text("Nothing to import").font(.title3.weight(.semibold))
                Text("Share a recipe link, recipe text, or screenshots of a recipe.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .failed(let why):
                Text("Couldn’t save").font(.title3.weight(.semibold))
                Text(why).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button(action: done) {
                Text("Done").font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.659, green: 0.220, blue: 0.153))
            .disabled(state.outcome == .working)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }

    private func message(_ kind: SharedItem.Kind, _ count: Int) -> String {
        switch kind {
        case .link: return "Open Dinner, Together to read the recipe and add it to your recipes."
        case .text: return "Open Dinner, Together to review the recipe text and add it."
        case .images: return "\(count) screenshot\(count == 1 ? "" : "s") ready. Open Dinner, Together to read them and add the recipe."
        }
    }
}
