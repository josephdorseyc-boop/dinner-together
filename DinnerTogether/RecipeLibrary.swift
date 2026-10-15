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

/// What the share extension left for the app, ready for the Add sheet.
struct PendingShare: Identifiable, Equatable {
    let id = UUID()
    let item: SharedItem
    let images: [Data]
}

@MainActor
final class RecipeLibrary: ObservableObject, MenuProviding {
    @Published private(set) var recipes: [Recipe] = []
    @Published var saveError: String?
    /// Set when the app comes to the front and the share extension's inbox
    /// holds an item; ContentView opens Add recipe with it.
    @Published var pendingShare: PendingShare?

    private let fileURL: URL
    private let imagesURL: URL
    nonisolated static let fileName = "dinner-together-recipes-v1.json"
    /// UI tests only (-dt-fail-recipe-saves): every save fails, as a full or
    /// read-only disk would. Never set in release builds.
    var simulateSaveFailure = false
    /// UI tests only (-dt-fail-cover-saves): the recipe saves, its photo
    /// doesn't — the "retry / continue without cover" path (A2-13).
    var simulateImageSaveFailure = false

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

    // MARK: The share extension's inbox

    /// Looks in the App Group container (nil when the app is not entitled,
    /// e.g. an unsigned simulator build without the group).
    func checkSharedInbox(now: Date = Date()) {
        #if canImport(UIKit)
        guard pendingShare == nil, let bundle = Bundle.main.bundleIdentifier,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedInbox.groupIdentifier(bundleIdentifier: bundle)),
              let found = SharedInbox.take(from: container, now: now) else { return }
        pendingShare = PendingShare(item: found.item, images: found.images)
        #endif
    }

    // MARK: Lookup

    func menu(id: String) -> DinnerMenu? {
        if let catalog = DinnerCatalog.menu(id: id) { return catalog }
        #if DEBUG
        if SampleMenus.enabled, let sample = SampleMenus.menu(id: id) { return sample }
        #endif
        if let pair = PairedDinner.parse(id) {
            // Both recipes, or nothing: a deleted half is a missing dinner,
            // which Tonight says plainly.
            guard let main = recipe(id: pair.main), let side = recipe(id: pair.side) else { return nil }
            return PairedDinner.menu(main: main, side: side)
        }
        return recipe(menuID: id)?.menu
    }

    func recipe(id: UUID) -> Recipe? { recipes.first { $0.id == id } }

    /// The recipe a menu id names — for a paired dinner, its main recipe
    /// (Tonight's cover, title link and plate photo follow the main).
    func recipe(menuID: String) -> Recipe? {
        if let pair = PairedDinner.parse(menuID) { return recipe(id: pair.main) }
        guard menuID.hasPrefix(Recipe.menuIDPrefix),
              let uuid = UUID(uuidString: String(menuID.dropFirst(Recipe.menuIDPrefix.count))) else { return nil }
        return recipe(id: uuid)
    }

    var isEmpty: Bool { recipes.isEmpty }

    /// The cook's recipes with the starred ones first, each group in the
    /// order they were added (Joe, build 20).
    var recipesFavoritesFirst: [Recipe] {
        recipes.filter(\.isFavorite) + recipes.filter { !$0.isFavorite }
    }

    /// Stars or unstars a recipe; saved like every change.
    @discardableResult
    func setFavorite(id: UUID, _ on: Bool) -> Bool {
        guard var r = recipe(id: id) else { return false }
        r.favorite = on ? true : nil
        return update(r)
    }

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
        let gone = recipe(id: id)
        recipes.removeAll { $0.id == id }
        guard save() else { recipes = before; return false }
        for name in [gone?.imageFilename, gone?.platePhotoFilename].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: imagesURL.appending(path: name))
        }
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

    /// The recipe's own total time, entered by the cook when the import found
    /// none (Joe, build 11). nil clears it. Shown on the page and compared
    /// with the plan on the Timing tab; it never changes a step's estimate.
    @discardableResult
    func setTotalMinutes(recipeID: UUID, minutes: Int?) -> Bool {
        guard var r = recipe(id: recipeID) else { return false }
        r.totalMinutes = minutes.map { max(1, min(1440, $0)) }
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

    /// The cook's fix for a title or yield the import got wrong (Joe, build
    /// 12: the status bar in the title). The steps' dish labels follow the
    /// new title, so the Cooking screen shows it too. A blank title is
    /// refused; a blank yield clears it.
    @discardableResult
    /// Title, yield and — the cook's own notes (A2, build 19: "use extra
    /// garlic", "check five minutes earlier"), kept with the recipe in the
    /// same field an import's own notes arrive in. Notes never touch the
    /// directions, the steps or the timing. `notes` nil leaves them as they
    /// are; blank clears them.
    func rename(recipeID: UUID, title: String, yield: String?, notes: String? = nil) -> Bool {
        guard var r = recipe(id: recipeID) else { return false }
        let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { return false }
        let oldLabel = RecipeImporter.shortLabel(r.title, max: 32)
        let newLabel = RecipeImporter.shortLabel(newTitle, max: 32)
        func relabel(_ dish: String) -> String {
            if dish == oldLabel { return newLabel }
            if dish == oldLabel + " — meanwhile" { return newLabel + " — meanwhile" }
            return dish
        }
        r.title = String(newTitle.prefix(200))
        let y = yield?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        r.yield = y.isEmpty ? nil : String(y.prefix(120))
        if let notes {
            let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            r.notes = n.isEmpty ? nil : String(n.prefix(2000))
        }
        r.dishes = r.dishes.map { dish in
            dish.map { s in
                CookingStep(id: s.id, dish: relabel(s.dish), title: s.title, minutes: s.minutes,
                            detail: s.detail, handsOn: s.handsOn, estimated: s.estimated)
            }
        }
        return update(r)
    }

    /// Takes a step out of the plan and the directions: text the import
    /// mistook for a step (a story teaser, a repeated title) is the cook's
    /// to remove (A2 S2, build 11). Repeated text is matched by source
    /// occurrence, so removing a later duplicate preserves direction order.
    @discardableResult
    func removeStep(recipeID: UUID, stepID: String) -> Bool {
        guard var r = recipe(id: recipeID),
              let step = r.steps.first(where: { $0.id == stepID }) else { return false }
        let matches = r.steps.filter { $0.detail == step.detail }
        let directions = r.directions.indices.filter {
            RecipeImporter.stripStepPrefix(r.directions[$0]) == step.detail
        }
        var directionIndex: Int?
        if matches.count == 1, directions.count == 1 {
            directionIndex = directions[0]
        } else if matches.count > 1, directions.count == matches.count {
            // Imported IDs retain source order even when meanwhile work
            // lives in another dish, or earlier directions were removed.
            let prefix = "r\(String(r.id.uuidString.prefix(8)).lowercased())-"
            let ranked = matches.compactMap { candidate -> (step: CookingStep, ordinal: Int)? in
                guard candidate.id.hasPrefix(prefix),
                      let ordinal = Int(candidate.id.dropFirst(prefix.count)), ordinal > 0 else { return nil }
                return (candidate, ordinal)
            }.sorted { $0.ordinal < $1.ordinal }
            if ranked.count == matches.count,
               Set(ranked.map { $0.ordinal }).count == matches.count,
               let occurrence = ranked.firstIndex(where: { $0.step.id == stepID }) {
                directionIndex = directions[occurrence]
            }
        }
        guard let directionIndex else {
            saveError = "This step couldn’t be matched to a direction. Re-import the recipe before removing it."
            return false
        }
        r.dishes = r.dishes.map { $0.filter { $0.id != stepID } }.filter { !$0.isEmpty }
        r.directions.remove(at: directionIndex)
        return update(r)
    }

    // MARK: Images

    /// Writes a fresh image, commits its reference, then removes the old cover.
    @discardableResult
    func saveImage(_ data: Data, for recipeID: UUID, fileExtension: String = "jpg") -> String? {
        guard var r = recipe(id: recipeID) else { return nil }
        if simulateImageSaveFailure {
            saveError = "The recipe was saved, but its photo couldn’t be."
            return nil
        }
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

    /// The cook's plate photo: written fresh, committed, then the old one
    /// removed — the same contract as the cover.
    @discardableResult
    func savePlatePhoto(_ data: Data, for recipeID: UUID, fileExtension: String = "jpg") -> String? {
        guard var r = recipe(id: recipeID) else { return nil }
        if simulateImageSaveFailure {
            saveError = "Your plate photo couldn’t be saved."
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let previousName = r.platePhotoFilename
            let name = "\(recipeID.uuidString)-plate-\(UUID().uuidString).\(fileExtension)"
            let newURL = imagesURL.appending(path: name)
            try data.write(to: newURL, options: .atomic)
            r.platePhotoFilename = name
            guard update(r) else {
                try? FileManager.default.removeItem(at: newURL)
                return nil
            }
            if let previousName {
                try? FileManager.default.removeItem(at: imagesURL.appending(path: previousName))
            }
            return name
        } catch {
            saveError = "Your plate photo couldn’t be saved."
            return nil
        }
    }

    /// Removes the cover; the page goes back to the classic cream.
    @discardableResult
    func removeCover(for recipeID: UUID) -> Bool {
        guard var r = recipe(id: recipeID), let name = r.imageFilename else { return false }
        r.imageFilename = nil
        guard update(r) else { return false }
        try? FileManager.default.removeItem(at: imagesURL.appending(path: name))
        return true
    }

    /// Forgets the plate photo; the hero goes back to the cover.
    @discardableResult
    func removePlatePhoto(for recipeID: UUID) -> Bool {
        guard var r = recipe(id: recipeID), let name = r.platePhotoFilename else { return false }
        r.platePhotoFilename = nil
        guard update(r) else { return false }
        try? FileManager.default.removeItem(at: imagesURL.appending(path: name))
        return true
    }

    func platePhotoURL(for recipe: Recipe) -> URL? {
        guard let name = recipe.platePhotoFilename else { return nil }
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
        if let social = SocialLink.detect(url) {
            return try await importSocial(social, now: now)
        }
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

    /// A TikTok or Instagram post: caption → recipe, cover from the post.
    /// A caption that only links to the recipe elsewhere is followed once.
    func importSocial(_ link: SocialLink, now: Date) async throws -> (recipe: Recipe, imageData: Data?) {
        let post: SocialPost
        switch link {
        case .tiktok(var video):
            if link.isShortLink {
                // vm.tiktok.com/… → the video page; the oEmbed endpoint wants that.
                video = (try? await fetcher.fetch(video).finalURL) ?? video
            }
            guard let endpoint = SocialLink.tiktokOEmbedURL(for: video) else { throw RecipeImportError.tiktokUnavailable }
            let answer: (data: Data, finalURL: URL)
            do { answer = try await fetcher.fetch(endpoint) } catch RecipeFetchError.badStatus { throw RecipeImportError.tiktokUnavailable }
            guard let p = SocialImport.tiktokPost(fromOEmbed: answer.data, url: video) else { throw RecipeImportError.tiktokUnavailable }
            post = p
        case .instagram(let postURL):
            let page = try await fetcher.fetch(postURL)
            guard let p = SocialImport.instagramPost(fromHTML: String(decoding: page.data, as: UTF8.self), url: postURL) else {
                throw RecipeImportError.instagramLoginWall
            }
            post = p
        }
        var imported: ImportedRecipe
        do {
            imported = try SocialImport.recipe(from: post)
        } catch let captionError as RecipeImportError {
            // "Full recipe: https://…" — the page the creator pointed at.
            guard let linked = SocialImport.recipeLink(inCaption: post.caption) else { throw captionError }
            let page = try await fetcher.fetch(linked)
            do {
                imported = try RecipeImporter.parse(html: String(decoding: page.data, as: UTF8.self), url: page.finalURL)
            } catch { throw captionError }
            if imported.imageURL == nil { imported.imageURL = post.imageURL }
        }
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
