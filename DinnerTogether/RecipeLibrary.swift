import Foundation
import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The cook's own recipes: stored on this device as one JSON file plus an
// image folder, and resolved into menus for the session store. Nothing here
// talks to a server except `URLSessionRecipeFetcher`, which fetches exactly
// the page the cook pasted and nothing else.

/// How the session store turns a menu id into a menu. Catalog ids resolve to
/// the catalog; `recipe:<uuid>` ids resolve through the library.
@MainActor
protocol MenuProviding: AnyObject {
    func menu(id: String) -> DinnerMenu?
}

@MainActor
final class RecipeLibrary: ObservableObject, MenuProviding {
    @Published private(set) var recipes: [Recipe] = []
    @Published var saveError: String?

    private let fileURL: URL
    private let imagesURL: URL
    nonisolated static let fileName = "dinner-together-recipes-v1.json"
    /// UI tests only (-dt-fail-recipe-saves): every save fails, as a full or
    /// read-only disk would. Never set in release builds.
    var simulateSaveFailure = false

    /// `directory` defaults to the app's Documents folder (same place as the
    /// session file). Tests pass a temporary directory.
    init(directory: URL? = nil) {
        let dir = directory ?? URL.documentsDirectory
        fileURL = dir.appending(path: RecipeLibrary.fileName)
        imagesURL = dir.appending(path: "recipe-images", directoryHint: .isDirectory)
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([Recipe].self, from: data) {
            recipes = loaded.sorted { $0.importedAt > $1.importedAt }
        }
    }

    // MARK: Lookup

    func menu(id: String) -> DinnerMenu? {
        if let catalog = DinnerCatalog.menus.first(where: { $0.id == id }) { return catalog }
        return recipe(menuID: id)?.menu
    }

    func recipe(id: UUID) -> Recipe? { recipes.first { $0.id == id } }

    func recipe(menuID: String) -> Recipe? {
        guard menuID.hasPrefix(Recipe.menuIDPrefix),
              let uuid = UUID(uuidString: String(menuID.dropFirst(Recipe.menuIDPrefix.count))) else { return nil }
        return recipe(id: uuid)
    }

    var isEmpty: Bool { recipes.isEmpty }

    // MARK: Changes (every one saves)

    /// Adds and saves. If the file can't be written, the add is rolled back
    /// so memory never shows a recipe that a relaunch would lose.
    @discardableResult
    func add(_ recipe: Recipe) -> Bool {
        let before = recipes
        recipes.removeAll { $0.id == recipe.id }
        recipes.insert(recipe, at: 0)
        guard save() else { recipes = before; return false }
        return true
    }

    /// Same rollback rule as `add`: memory never shows an edit the file lacks.
    @discardableResult
    func update(_ recipe: Recipe) -> Bool {
        guard let i = recipes.firstIndex(where: { $0.id == recipe.id }) else { return add(recipe) }
        let before = recipes
        recipes[i] = recipe
        guard save() else { recipes = before; return false }
        return true
    }

    /// Removes the recipe, then its image — the image only once the library
    /// file no longer lists the recipe, so a failed save can't leave a recipe
    /// pointing at a deleted photo. The caller decides what happens to a
    /// session that was using it; the library never reaches into the session.
    @discardableResult
    func remove(id: UUID) -> Bool {
        let before = recipes
        let imageName = recipe(id: id)?.imageFilename
        recipes.removeAll { $0.id == id }
        guard save() else { recipes = before; return false }
        if let name = imageName { try? FileManager.default.removeItem(at: imagesURL.appending(path: name)) }
        return true
    }

    @discardableResult
    func markTimingReviewed(id: UUID) -> Bool {
        guard var r = recipe(id: id) else { return false }
        r.needsTimingReview = false
        r.dishes = r.dishes.map { dish in
            dish.map { step in
                CookingStep(id: step.id, dish: step.dish, title: step.title, minutes: step.minutes,
                            detail: step.detail, handsOn: step.handsOn, estimated: false)
            }
        }
        return update(r)
    }

    /// Edits one step's timing. Confirming a value clears its `estimated` mark.
    @discardableResult
    func setStep(recipeID: UUID, stepID: String, minutes: Int? = nil, handsOn: Bool? = nil) -> Bool {
        guard var r = recipe(id: recipeID) else { return false }
        r.dishes = r.dishes.map { dish in
            dish.map { step in
                guard step.id == stepID else { return step }
                return CookingStep(id: step.id, dish: step.dish, title: step.title,
                                   minutes: max(1, min(480, minutes ?? step.minutes)),
                                   detail: step.detail, handsOn: handsOn ?? step.handsOn,
                                   estimated: minutes == nil ? step.estimated : false)
            }
        }
        return update(r)
    }

    // MARK: Images

    /// Writes a fresh image, commits its reference, then removes the old cover.
    @discardableResult
    func saveImage(_ data: Data, for recipeID: UUID, fileExtension: String = "jpg") -> String? {
        guard var r = recipe(id: recipeID) else { return nil }
        do {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let previousName = r.imageFilename
            let name = "\(recipeID.uuidString)-\(UUID().uuidString).\(fileExtension)"
            let newURL = imagesURL.appending(path: name)
            try data.write(to: newURL, options: .atomic)
            r.imageFilename = name
            guard update(r) else {
                try? FileManager.default.removeItem(at: newURL)
                return nil
            }
            if let previousName {
                try? FileManager.default.removeItem(at: imagesURL.appending(path: previousName))
            }
            return name
        } catch {
            saveError = "The recipe was saved, but its photo couldn’t be."
            return nil
        }
    }

    func imageURL(for recipe: Recipe) -> URL? {
        guard let name = recipe.imageFilename else { return nil }
        let url = imagesURL.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: Persistence

    @discardableResult
    func save() -> Bool {
        if simulateSaveFailure {
            saveError = "Your recipes couldn’t be saved. Keep the app open and try again."
            return false
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(recipes).write(to: fileURL, options: .atomic)
            saveError = nil
            return true
        } catch {
            saveError = "Your recipes couldn’t be saved. Keep the app open and try again."
            return false
        }
    }
}

// Pure geometry shared by the cover preview/export and portable tests.
enum RecipeCoverCrop {
    struct Rect: Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    static func rect(width: Double, height: Double, zoom: Double,
                     horizontal: Double, vertical: Double) -> Rect? {
        guard [width, height, zoom, horizontal, vertical].allSatisfy({ $0.isFinite }),
              width > 0, height > 0 else { return nil }
        let ratio = 4.0 / 3.0
        let cropWidth = min(width, height * ratio) / max(1, min(4, zoom))
        let cropHeight = cropWidth / ratio
        return Rect(x: max(0, width - cropWidth) * max(0, min(1, horizontal)),
                    y: max(0, height - cropHeight) * max(0, min(1, vertical)),
                    width: cropWidth, height: cropHeight)
    }
}

// MARK: - Fetching a pasted link

/// The single network dependency, behind a protocol so tests never touch it.
protocol RecipePageFetcher {
    func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL)
}

enum RecipeFetchError: Error, LocalizedError {
    case notHTTP, badStatus(Int), tooLarge, offline

    var errorDescription: String? {
        switch self {
        case .notHTTP: return "That link isn’t a web address the app can open."
        case .badStatus(let code): return "The site answered with an error (\(code)). Try the link in Safari, then copy the recipe text instead."
        case .tooLarge: return "That page is too large to read here. Copy the recipe text and paste it instead."
        case .offline: return "The page couldn’t be loaded. Check your connection and try again."
        }
    }
}

struct URLSessionRecipeFetcher: RecipePageFetcher {
    var maxBytes = 6_000_000

    func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RecipeFetchError.notHTTP
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        // Some recipe sites refuse requests without a browser-looking agent.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,*/*;q=0.8", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config)
        // A continuation around the callback API: available everywhere the
        // harness builds, unlike the async `data(for:)` overload.
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let data = data, let response = response, error == nil {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: RecipeFetchError.offline)
                }
            }
            task.resume()
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecipeFetchError.badStatus(http.statusCode)
        }
        guard data.count <= maxBytes else { throw RecipeFetchError.tooLarge }
        return (data, response.url ?? url)
    }
}

/// Paste-a-link, end to end: fetch, follow one wrapper redirect (apple.news
/// and the like), parse, then fetch the photo. Returns the recipe draft and
/// the image bytes (the app downscales them before the library stores them).
struct RecipeImportService {
    var fetcher: RecipePageFetcher = URLSessionRecipeFetcher()

    func importLink(_ url: URL, now: Date = Date()) async throws -> (recipe: Recipe, imageData: Data?) {
        let page = try await fetcher.fetch(url)
        var html = String(decoding: page.data, as: UTF8.self)
        var pageURL = page.finalURL
        var imported: ImportedRecipe
        do {
            imported = try RecipeImporter.parse(html: html, url: pageURL)
        } catch RecipeImportError.noRecipeData {
            let newsPlaceholder = RecipeImporter.isAppleNewsPlaceholder(url: pageURL, html: html)
            let newsError = RecipeImportError.appleNewsOnly(title: RecipeImporter.placeholderTitle(html))
            guard let next = RecipeImporter.redirectTarget(inHTML: html, from: pageURL), next != pageURL else {
                throw newsPlaceholder ? newsError : RecipeImportError.noRecipeData
            }
            do {
                let second = try await fetcher.fetch(next)
                html = String(decoding: second.data, as: UTF8.self)
                pageURL = second.finalURL
                imported = try RecipeImporter.parse(html: html, url: pageURL)
            } catch {
                throw newsPlaceholder ? newsError : error
            }
        }
        if imported.source.url == nil { imported.source.url = pageURL }
        let recipe = RecipeImporter.build(imported, method: .link, now: now)
        var imageData: Data?
        if let imageURL = imported.imageURL, let fetched = try? await fetcher.fetch(imageURL), fetched.data.count > 1_000 {
            imageData = fetched.data
        }
        return (recipe, imageData)
    }

    func importText(_ text: String, now: Date = Date()) throws -> Recipe {
        RecipeImporter.build(try RecipeImporter.parse(text: text), method: .text, now: now)
    }
}
