import SwiftUI
import UIKit

@main
struct DinnerTogetherApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: SessionStore
    @StateObject private var library: RecipeLibrary
    @StateObject private var timers = TimerCenter()
    @StateObject private var weekPlan: WeekPlanStore

    init() {
        #if DEBUG
        // UI-test seeding must land before SessionStore reads its file.
        LaunchOptions.writeSeedFileIfPresent()
        #endif
        // The library is created first: the store resolves `recipe:` menu ids
        // through it while loading the saved session.
        #if DEBUG
        LaunchOptions.writeRecipeSeedIfPresent()
        LaunchOptions.writeWeekPlanSeedIfPresent()
        #endif
        _weekPlan = StateObject(wrappedValue: WeekPlanStore())
        let library = RecipeLibrary()
        #if DEBUG
        library.simulateSaveFailure = LaunchOptions.failRecipeSaves
        library.simulateImageSaveFailure = LaunchOptions.failCoverSaves
        #endif
        _library = StateObject(wrappedValue: library)
        _store = StateObject(wrappedValue: SessionStore(notifications: LaunchOptions.notificationService(),
                                                        menuProvider: library))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(library)
                .environmentObject(timers)
                .environmentObject(weekPlan)
                #if DEBUG
                // UI-test forced type size (A1-T1); nil unless -dt-type-size
                // was passed, so release and ordinary debug builds are
                // unaffected.
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if let forced = LaunchOptions.forcedTypeSize { size = forced }
                }
                // ContentView combines the forced appearance with the active
                // recipe page's appearance at the presentation root.
                #endif
                .task {
                    adoptPlannedDinner()
                    await store.refreshNotificationSettings()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refreshNotificationSettings() }
                        library.checkSharedInbox()
                        adoptPlannedDinner()
                    }
                }
        }
    }
}

extension DinnerTogetherApp {
    /// When a planned day arrives, its dinner becomes tonight's — only if
    /// yesterday's choice is untouched and nothing is cooking (WeekPlan).
    /// UI tests seed their own session and keep it.
    @MainActor
    private func adoptPlannedDinner() {
        guard !LaunchOptions.seededSession, !store.needsStaleChoice else { return }
        if let id = WeekPlan.menuToAdopt(session: store.session, hasProgress: store.hasProgress, plan: weekPlan.plan,
                                         now: Date(), exists: { PlannedDinners.exists($0, library: library) },
                                         cookable: { PlannedDinners.cookable($0, library: library) }) {
            store.chooseMenu(id)
        }
    }
}

// MARK: - Debug launch options (simulator screenshots, UI tests)

/// Launch arguments honored only in DEBUG builds. Release builds ignore
/// them entirely: every accessor below is a constant `false`/`nil` there.
///
///   -dt-open-cooking      open on the Cooking screen instead of Tonight
///   -dt-inert-reminders   use a reminder service that never prompts or
///                         schedules, so no system alert covers the screen
///   -dt-type-size <name>  force a DynamicTypeSize (e.g. accessibility3);
///                         the -UIPreferredContentSizeCategoryName launch
///                         argument is not honored, this is (A1-T1)
///   DT_SEED_JSON          environment variable carrying a dinner-together-v2.json
///                         payload; written to the store's file before
///                         SessionStore is created (see writeSeedFileIfPresent).
///                         UI tests set it on every launch — it is never deleted,
///                         so a stale seed can only leak if a test forgets to set it.
///
/// Used by native-validation/screenshots.sh. Nothing here changes cooking
/// behavior: the inert service only replaces the permission/scheduling
/// layer, and the store's timers still run from their absolute deadlines.
enum LaunchOptions {
    #if DEBUG
    private static let arguments = Set(ProcessInfo.processInfo.arguments)
    static var openCooking: Bool { arguments.contains("-dt-open-cooking") }
    /// Every recipe-library save fails (UI test of the unsaved-change states).
    static var failRecipeSaves: Bool { arguments.contains("-dt-fail-recipe-saves") }
    /// -dt-solid-cards: the rendering Reduce Transparency and Increase
    /// Contrast select (the environment values are read-only; same code path).
    static var solidCards: Bool { arguments.contains("-dt-solid-cards") }
    /// Only the photo save fails (the recipe itself saves): A2-13's retry path.
    static var failCoverSaves: Bool { arguments.contains("-dt-fail-cover-saves") }
    /// The Add sheet's Screenshots option uses two drawn test screenshots
    /// instead of the system photo picker, which XCUITest can't operate.
    static var stubScreenshots: Bool { arguments.contains("-dt-stub-screenshots") }
    /// Link import answers apple.news URLs with the recorded "only available
    /// in Apple News" placeholder instead of the network.
    static var stubAppleNews: Bool { arguments.contains("-dt-stub-apple-news") }
    /// -dt-appearance dark|light: Dark Mode captures without touching the
    /// simulator's settings.
    static var forcedColorScheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-dt-appearance"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
    static var inertReminders: Bool { arguments.contains("-dt-inert-reminders") }
    /// A UI test seeded the session (DT_SEED_JSON): the week plan never
    /// replaces it, and the plan file is reset for the test.
    static var seededSession: Bool { ProcessInfo.processInfo.environment["DT_SEED_JSON"] != nil }

    /// DT_SEED_WEEK_PLAN: a week-plan.json payload ("{}" when unset) written
    /// whenever a UI test seeds the session, so no plan leaks between tests.
    static func writeWeekPlanSeedIfPresent() {
        guard seededSession else { return }
        let json = ProcessInfo.processInfo.environment["DT_SEED_WEEK_PLAN"] ?? "{}"
        let url = URL.documentsDirectory.appending(path: WeekPlanStore.fileName)
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Forces a DynamicTypeSize for accessibility-size UI-test renders.
    /// `-UIPreferredContentSizeCategoryName` is not honored by the app;
    /// `-dt-type-size accessibility3` is. nil in release builds.
    static var forcedTypeSize: DynamicTypeSize? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-dt-type-size"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "xsmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xlarge": return .xLarge
        case "xxlarge": return .xxLarge
        case "xxxlarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
    }
    #else
    static var openCooking: Bool { false }
    static var failRecipeSaves: Bool { false }
    static var solidCards: Bool { false }
    static var failCoverSaves: Bool { false }
    static var stubScreenshots: Bool { false }
    static var stubAppleNews: Bool { false }
    static var forcedColorScheme: ColorScheme? { nil }
    static var inertReminders: Bool { false }
    static var forcedTypeSize: DynamicTypeSize? { nil }
    static var seededSession: Bool { false }
    #endif

    /// nil means "the real NotificationManager". Main-actor isolated because
    /// `InertNotificationService` is; the only caller is `DinnerTogetherApp`'s
    /// initializer, which runs on the main actor (CI run 3: Xcode 16.4
    /// rejected the nonisolated call).
    @MainActor
    static func notificationService() -> NotificationService? {
        #if DEBUG
        return inertReminders ? InertNotificationService() : nil
        #else
        return nil
        #endif
    }

    /// The import service the Add sheet uses: the real network, or in UI
    /// tests the recorded Apple News placeholder.
    static func importService() -> RecipeImportService {
        #if DEBUG
        if stubAppleNews { return RecipeImportService(fetcher: AppleNewsPlaceholderFetcher()) }
        #endif
        return RecipeImportService()
    }

    #if DEBUG
    /// DT_SEED_RECIPE_TEXTS: a JSON array of pasted-recipe texts. Each is
    /// imported exactly as the Text option would, and the library file is
    /// replaced with the result ("[]" empties it). UI tests set it on every
    /// launch, so recipes never leak from one test into the next.
    static func writeRecipeSeedIfPresent() {
        guard let json = ProcessInfo.processInfo.environment["DT_SEED_RECIPE_TEXTS"],
              let texts = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) else { return }
        let base = Date()
        let recipes = texts.enumerated().compactMap { i, text -> Recipe? in
            guard let imported = try? RecipeImporter.parse(text: text) else { return nil }
            // Newest first in the library: the first text is listed first.
            return RecipeImporter.build(imported, method: .text, now: base.addingTimeInterval(-Double(i)))
        }
        var seeded = recipes
        // DT_SEED_RECIPE_WARNINGS: a JSON array of warning lists, parallel to
        // the texts — the text path never produces import warnings, so the
        // warning card's persistence is tested from a seed (A1 #20, A2 PR #16).
        if let wjson = ProcessInfo.processInfo.environment["DT_SEED_RECIPE_WARNINGS"],
           let lists = try? JSONDecoder().decode([[String]].self, from: Data(wjson.utf8)) {
            for (i, list) in lists.enumerated() where i < seeded.count && !list.isEmpty {
                seeded[i].importWarnings = list
            }
        }
        // DT_SEED_RECIPE_PHOTO=landscape (a wide, warm still life) or
        // =pastel (pale blue icing, a pale page): give the first recipe a
        // photo drawn here, so the test never depends on a publisher's image.
        let photoKind = ProcessInfo.processInfo.environment["DT_SEED_RECIPE_PHOTO"] ?? ""
        if ["landscape", "pastel"].contains(photoKind), !seeded.isEmpty {
            let folder = URL.documentsDirectory.appending(path: "recipe-images", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = "\(seeded[0].id.uuidString).jpg"
            let photo = photoKind == "pastel" ? pastelTestPhoto() : landscapeTestPhoto()
            if let jpeg = photo.jpegData(compressionQuality: 0.85),
               (try? jpeg.write(to: folder.appending(path: name), options: .atomic)) != nil {
                seeded[0].imageFilename = name
            }
        }
        let url = URL.documentsDirectory.appending(path: RecipeLibrary.fileName)
        if let data = try? JSONEncoder().encode(seeded) { try? data.write(to: url, options: .atomic) }
    }

    /// Two drawn "screenshots" for -dt-stub-screenshots: a recipe page of text
    /// (read by the real on-device recognizer) and a page with a food photo
    /// at the top (for the cover crop). PNG, phone-sized.
    static func stubScreenshotData() -> [Data] {
        guard stubScreenshots else { return [] }
        let size = CGSize(width: 1179, height: 2556)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let textPage = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 220
            func line(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight = .regular, gap: CGFloat = 26) {
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight),
                                                            .foregroundColor: UIColor.black]
                (text as NSString).draw(at: CGPoint(x: 70, y: y), withAttributes: attrs)
                y += size * 1.25 + gap
            }
            line("Stub Cider Slush", 96, .bold, gap: 80)
            line("Ingredients", 64, .bold)
            line("2 cups apple cider", 48)
            line("1 cinnamon stick", 48, gap: 80)
            line("Directions", 64, .bold)
            line("STEP 1", 44, .bold, gap: 8)
            line("Simmer the cider with the cinnamon", 48, gap: 4)
            line("for 10 minutes.", 48, gap: 60)
            line("STEP 2", 44, .bold, gap: 8)
            line("Freeze until solid, about 3 hours.", 48)
        }
        let photoPage = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            landscapeTestPhoto().draw(in: CGRect(x: 0, y: 300, width: size.width, height: size.width * 1000 / 1800))
        }
        return [textPage, photoPage].compactMap { $0.pngData() }
    }

    /// A 1200×1200 pastel: pale blue and lavender swirls on a white board,
    /// like Joe's meringue photo (build 11). Its page is pale.
    static func pastelTestPhoto() -> UIImage {
        let size = CGSize(width: 1200, height: 1200)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: size))
            let tints = [UIColor(red: 0.60, green: 0.69, blue: 0.79, alpha: 1), UIColor(red: 0.71, green: 0.80, blue: 0.88, alpha: 1),
                         UIColor(red: 0.71, green: 0.75, blue: 0.83, alpha: 1), UIColor(red: 0.81, green: 0.84, blue: 0.90, alpha: 1)]
            for row in 0..<6 {
                for col in 0..<4 {
                    tints[(row + col) % tints.count].setFill()
                    c.fillEllipse(in: CGRect(x: 40 + col * 290, y: 60 + row * 185, width: 250, height: 150))
                }
            }
            UIColor(white: 1, alpha: 0.55).setFill()
            for row in 0..<6 { c.fillEllipse(in: CGRect(x: 120, y: 95 + row * 185, width: 960, height: 60)) }
        }
    }

    /// A 1800×1000 still life (table, two glasses, a bowl) in the app's own
    /// palette. Wider than any screen on purpose: the hero must clip it.
    static func landscapeTestPhoto() -> UIImage {
        let size = CGSize(width: 1800, height: 1000)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(red: 0.93, green: 0.80, blue: 0.62, alpha: 1).cgColor,
                          UIColor(red: 0.66, green: 0.22, blue: 0.15, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 640, width: size.width, height: 360))
            UIColor(white: 1, alpha: 0.85).setFill()
            c.fillEllipse(in: CGRect(x: 380, y: 300, width: 260, height: 420))
            c.fillEllipse(in: CGRect(x: 1160, y: 300, width: 260, height: 420))
            UIColor(red: 0.28, green: 0.34, blue: 0.22, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 720, y: 600, width: 360, height: 180))
        }
    }

    /// Writes the DT_SEED_JSON payload to the store's file, if the variable
    /// is present. Called from `DinnerTogetherApp.init()` before SessionStore
    /// is created, so a UI test launches straight into its seeded state.
    /// Plain file I/O, deliberately nonisolated. Never deletes: screenshots.sh
    /// writes its own seeds via simctl and launches without the variable.
    static func writeSeedFileIfPresent() {
        guard let json = ProcessInfo.processInfo.environment["DT_SEED_JSON"],
              !json.isEmpty else { return }
        let url = URL.documentsDirectory.appending(path: "dinner-together-v2.json")
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }
    #else
    /// Release: the screenshot source is always the photo picker. (Build 9's
    /// first release archive failed on this symbol — validation builds Debug.)
    static func stubScreenshotData() -> [Data] { [] }
    #endif
}

#if DEBUG
/// Grants nothing, schedules nothing, never prompts. Debug only.
@MainActor
final class InertNotificationService: NotificationService {
    private(set) var denied = false
    var onStatusChange: ((Bool, String?) -> Void)?
    func ensureAuthorization() async -> Bool { false }
    func refreshAuthorization() async { }
    func schedule(stepID: String, title: String, deadline: Date) { }
    func cancel(stepID: String) { }
    func cancelAll() { }
}
#endif

#if DEBUG
/// What https://apple.news/… returned on October 11, 2026: a placeholder with
/// the title and no recipe. Lets the UI test exercise the Apple News message
/// without the network.
struct AppleNewsPlaceholderFetcher: RecipePageFetcher {
    func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
        let html = """
        <html><head><title>Whipped Frozen Apple Cider</title>
        <meta property="og:title" content="Whipped Frozen Apple Cider — EatingWell"></head>
        <body><p>This content is only available in Apple News.</p></body></html>
        """
        return (Data(html.utf8), url)
    }
}
#endif

extension View {
    /// Sheet content under UI test: the forced type size is an environment
    /// value the root sets, and a presented sheet does not inherit it (run
    /// 38330367116: the Page color sheet rendered at the default size under
    /// -dt-type-size). A cook's real Dynamic Type setting reaches sheets on
    /// its own; this only makes the test flag honest. No-op in release.
    @ViewBuilder
    func uiTestTypeSize() -> some View {
        #if DEBUG
        transformEnvironment(\.dynamicTypeSize) { size in
            if let forced = LaunchOptions.forcedTypeSize { size = forced }
        }
        #else
        self
        #endif
    }
}
