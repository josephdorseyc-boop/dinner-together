#if canImport(UIKit)
import XCTest
import UIKit
@testable import DinnerTogether

// A2-44 checks 4 and 5 (A1's priority list): the picture that leads Tonight
// is the recipe's plate photo, then its cover, then nothing (Tonight shows
// A2's notebook); both photos persist with the recipe; a missing or corrupt
// file falls back without touching the recipe. Decoding needs UIKit, so this
// file runs on the iOS simulator only (the Linux harness skips it).
//
// The two photos are told apart by their pixel sizes: plate 60 × 40, cover
// 30 × 50.

@MainActor
final class CoverPhotoTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dt-cover-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func jpeg(width: CGFloat, height: CGFloat, _ color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }.jpegData(compressionQuality: 0.9)!
    }
    private var plate: Data { jpeg(width: 60, height: 40, .systemOrange) }
    private var cover: Data { jpeg(width: 30, height: 50, .systemTeal) }

    private func addRecipe(_ library: RecipeLibrary, _ title: String = "Toast") throws -> Recipe {
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: "\(title)\nDirections\n1. Toast the bread for 5 minutes."), method: .text)
        XCTAssertTrue(library.add(recipe))
        return recipe
    }

    private func heroSize(_ id: UUID, _ library: RecipeLibrary) -> CGSize? {
        guard let recipe = library.recipe(id: id) else { return nil }
        return RecipePhotos.hero(recipe, from: library)?.image.size
    }

    func testPlateThenCoverThenNothing() throws {
        let library = RecipeLibrary(directory: try tempDir())
        let recipe = try addRecipe(library)
        XCTAssertNil(heroSize(recipe.id, library), "no photo: Tonight shows the notebook")

        XCTAssertNotNil(library.saveImage(cover, for: recipe.id))
        XCTAssertEqual(heroSize(recipe.id, library), CGSize(width: 30, height: 50), "the cover leads without a plate photo")

        XCTAssertNotNil(library.savePlatePhoto(plate, for: recipe.id))
        XCTAssertEqual(heroSize(recipe.id, library), CGSize(width: 60, height: 40), "the plate photo leads")
        XCTAssertEqual(library.recipe(id: recipe.id)?.imageFilename != nil, true, "the cover is kept for the page")

        // Replace the plate photo: the new one leads and the old file is gone.
        let oldPlate = try XCTUnwrap(library.recipe(id: recipe.id)?.platePhotoFilename)
        XCTAssertNotNil(library.savePlatePhoto(jpeg(width: 64, height: 48, .systemRed), for: recipe.id))
        XCTAssertEqual(heroSize(recipe.id, library), CGSize(width: 64, height: 48), "a replaced plate photo leads")
        XCTAssertNotEqual(library.recipe(id: recipe.id)?.platePhotoFilename, oldPlate)

        XCTAssertTrue(library.removePlatePhoto(for: recipe.id))
        XCTAssertEqual(heroSize(recipe.id, library), CGSize(width: 30, height: 50), "removing the plate photo falls back to the cover")
        XCTAssertTrue(library.removeCover(for: recipe.id))
        XCTAssertNil(heroSize(recipe.id, library), "removing the cover falls back to the notebook")
    }

    func testPhotosPersistWithTheRecipe() throws {
        let dir = try tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try addRecipe(library)
        XCTAssertNotNil(library.saveImage(cover, for: recipe.id))
        XCTAssertNotNil(library.savePlatePhoto(plate, for: recipe.id))

        // A fresh library from the same folder is what the app sees after a relaunch.
        let reopened = RecipeLibrary(directory: dir)
        let again = try XCTUnwrap(reopened.recipe(id: recipe.id))
        XCTAssertNotNil(reopened.imageURL(for: again), "the cover file is still there")
        XCTAssertNotNil(reopened.platePhotoURL(for: again), "the plate photo file is still there")
        XCTAssertEqual(heroSize(recipe.id, reopened), CGSize(width: 60, height: 40), "and the plate photo still leads")
    }

    func testMissingOrCorruptPhotoFallsBackAndKeepsTheRecipe() throws {
        let dir = try tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try addRecipe(library, "Corrupt photo toast")
        XCTAssertNotNil(library.saveImage(cover, for: recipe.id))

        // A plate photo whose file is not an image: the cover leads.
        let folder = dir.appendingPathComponent("recipe-images")
        let corrupt = "corrupt-\(UUID().uuidString).jpg"
        try Data("not a picture".utf8).write(to: folder.appendingPathComponent(corrupt))
        var edited = try XCTUnwrap(library.recipe(id: recipe.id))
        edited.platePhotoFilename = corrupt
        XCTAssertTrue(library.update(edited))
        XCTAssertEqual(heroSize(recipe.id, library), CGSize(width: 30, height: 50), "a corrupt plate photo falls back to the cover")

        // A corrupt cover with no plate must fall all the way back to the notebook.
        let corruptCover = "corrupt-cover-\(UUID().uuidString).jpg"
        try Data("not a cover picture".utf8).write(to: folder.appendingPathComponent(corruptCover))
        edited.platePhotoFilename = nil
        edited.imageFilename = corruptCover
        XCTAssertTrue(library.update(edited))
        XCTAssertNil(heroSize(recipe.id, library), "a corrupt cover falls back to the notebook")

        // Both files missing: nothing leads (Tonight shows the notebook).
        edited.platePhotoFilename = "missing-\(UUID().uuidString).jpg"
        edited.imageFilename = "missing-\(UUID().uuidString).jpg"
        XCTAssertTrue(library.update(edited))
        XCTAssertNil(heroSize(recipe.id, library), "missing files fall back to the notebook")

        let kept = try XCTUnwrap(RecipeLibrary(directory: dir).recipe(id: recipe.id))
        XCTAssertEqual(kept.title, "Corrupt photo toast", "the recipe's text is untouched")
        XCTAssertEqual(kept.directions, recipe.directions)
        XCTAssertEqual(kept.dishes.flatMap { $0 }.count, recipe.dishes.flatMap { $0 }.count)
    }

    // MARK: The ▶ baked into a video post's cover (Joe, build 19; A2, build 20)

    /// A 360 × 640 reel cover: warm above, cool below, a translucent dark
    /// disc with a white ▶ a little below the middle.
    private func reelCover() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 360, height: 640), format: format).image { ctx in
            UIColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 360, height: 320))
            UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 320, width: 360, height: 320))
            UIColor.black.withAlphaComponent(0.45).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 130, y: 290, width: 100, height: 100))
            UIColor.white.setFill()
            let play = UIBezierPath()
            play.move(to: CGPoint(x: 165, y: 318)); play.addLine(to: CGPoint(x: 165, y: 362)); play.addLine(to: CGPoint(x: 203, y: 340)); play.close()
            play.fill()
        }.jpegData(compressionQuality: 0.95)!
    }

    private func topLeft(_ image: UIImage) -> (r: Double, b: Double) {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // The picture's top-left pixel lands in the 1 × 1 context's only pixel.
        ctx.draw(image.cgImage!, in: CGRect(x: -10, y: -(image.size.height - 11), width: image.size.width, height: image.size.height))
        return (Double(px[0]) / 255, Double(px[2]) / 255)
    }

    private func coverSize(_ id: UUID, _ library: RecipeLibrary) -> CGSize? {
        library.recipe(id: id).flatMap { RecipePhotos.load($0, from: library)?.image.size }
    }

    func testPlayButtonIsCroppedOnceTheOriginalKeptAndRestorable() throws {
        let library = RecipeLibrary(directory: try tempDir())
        var recipe = try addRecipe(library, "Reel chicken")
        recipe.source.publisher = "Instagram"
        XCTAssertTrue(library.update(recipe))

        // Import: the cover is saved, then its ▶ cropped away.
        XCTAssertNotNil(library.saveImage(reelCover(), for: recipe.id))
        XCTAssertTrue(library.cropPlayButton(for: recipe.id), "the reel's play button is found")
        let cropped = try XCTUnwrap(library.recipe(id: recipe.id))
        XCTAssertNotNil(cropped.originalCoverFilename, "the picture as it came is kept")
        let size = try XCTUnwrap(coverSize(recipe.id, library))
        XCTAssertEqual(size.width, 360, "full width")
        XCTAssertLessThan(size.height, 300, "only the band above the button: \(size)")
        let image = try XCTUnwrap(RecipePhotos.load(cropped, from: library)?.image)
        let corner = topLeft(image)
        XCTAssertGreaterThan(corner.r, corner.b, "the warm top of the picture, right way up: \(corner)")
        XCTAssertFalse(library.cropPlayButton(for: recipe.id), "nothing left to crop")

        // Edit cover → Use the original picture.
        XCTAssertTrue(library.restoreOriginalCover(for: recipe.id))
        XCTAssertEqual(coverSize(recipe.id, library), CGSize(width: 360, height: 640), "the original, button and all")
        XCTAssertNil(library.recipe(id: recipe.id)?.originalCoverFilename)

        // A cover the cook chose is never cropped on its own…
        XCTAssertNotNil(library.saveImage(reelCover(), for: recipe.id))
        library.cleanVideoCovers()
        XCTAssertEqual(coverSize(recipe.id, library), CGSize(width: 360, height: 640), "the cook's own cover stays as chosen")
        // …while one saved before build 20 is checked once when the app opens.
        var old = try XCTUnwrap(library.recipe(id: recipe.id))
        old.coverChecked = nil
        XCTAssertTrue(library.update(old))
        library.cleanVideoCovers()
        XCTAssertLessThan(try XCTUnwrap(coverSize(recipe.id, library)).height, 300, "an older video cover is cleaned")
        XCTAssertEqual(library.recipe(id: recipe.id)?.coverChecked, true)
    }

    // Joe, October 15: the Instagram cover "came out a little unappealing".
    // The post's picture is marked as such; the gentle prompt shows until
    // the cook keeps it (then a quiet line) or replaces it (then nothing).
    func testAPostsCoverIsMarkedUntilTheCookKeepsOrReplacesIt() throws {
        let library = RecipeLibrary(directory: try tempDir())
        var recipe = try addRecipe(library, "Reel chicken")
        recipe.source.publisher = "Instagram"
        XCTAssertTrue(library.update(recipe))

        XCTAssertNotNil(library.saveImage(reelCover(), for: recipe.id, source: "post"))
        XCTAssertEqual(library.recipe(id: recipe.id)?.coverSource, "post")
        XCTAssertNil(library.recipe(id: recipe.id)?.coverPromptDismissed, "the prompt is due")
        XCTAssertTrue(library.cropPlayButton(for: recipe.id))
        XCTAssertEqual(library.recipe(id: recipe.id)?.coverSource, "post", "the ▶ crop keeps where the picture came from")

        XCTAssertTrue(library.keepPostCover(for: recipe.id))
        XCTAssertEqual(library.recipe(id: recipe.id)?.coverPromptDismissed, true, "kept: the quiet line only")
        XCTAssertEqual(library.recipe(id: recipe.id)?.coverSource, "post")

        XCTAssertNotNil(library.saveImage(cover, for: recipe.id), "the cook's own cover")
        XCTAssertNil(library.recipe(id: recipe.id)?.coverSource, "nothing to prompt about any more")
        XCTAssertNil(library.recipe(id: recipe.id)?.coverPromptDismissed)
        XCTAssertFalse(library.keepPostCover(for: recipe.id), "nothing to keep")

        XCTAssertTrue(library.removeCover(for: recipe.id))
        XCTAssertNil(library.recipe(id: recipe.id)?.coverSource)
    }

    func testOrdinaryPhotosAreNeverCropped() throws {
        let library = RecipeLibrary(directory: try tempDir())
        var recipe = try addRecipe(library, "Plain photo")
        recipe.source.publisher = "TikTok"
        XCTAssertTrue(library.update(recipe))
        XCTAssertNotNil(library.saveImage(cover, for: recipe.id))
        XCTAssertFalse(library.cropPlayButton(for: recipe.id))
        XCTAssertEqual(coverSize(recipe.id, library), CGSize(width: 30, height: 50))
        XCTAssertNil(library.recipe(id: recipe.id)?.originalCoverFilename)
    }
}

/// The durations a direction names, as the timer buttons read them
/// (Joe, October 15). TimedText lives with the views, so this runs on the
/// simulator only.
final class DirectionTimerTests: XCTestCase {
    func testEachDurationInAStepBecomesATimer() {
        XCTAssertEqual(TimedText.durations(in: "Pat the chicken dry. Roast at 375°F for 15 minutes."), ["15 minutes"])
        XCTAssertEqual(TimedText.durations(in: "Simmer 10 to 12 minutes, then rest for 5 min."), ["10 to 12 minutes", "5 min"])
        XCTAssertEqual(TimedText.durations(in: "Chill overnight."), [], "overnight is no kitchen timer")
        XCTAssertEqual(TimedText.durations(in: "Stir until smooth."), [])
    }

    func testTimerSecondsFollowTheDirection() {
        XCTAssertEqual(TimedText.seconds(in: "15 minutes"), 900)
        XCTAssertEqual(TimedText.seconds(in: "10 to 12 minutes"), 720, "a range takes its upper end")
        XCTAssertEqual(TimedText.seconds(in: "30 seconds"), 30, "not rounded up to a minute")
        XCTAssertEqual(TimedText.seconds(in: "1½ hours"), 90 * 60)
        XCTAssertEqual(TimedText.seconds(in: "an hour"), 3600)
        XCTAssertNil(TimedText.seconds(in: "a while"), "no duration, no timer")
    }
}

/// Kitchen timers keep their reminders (A2's review, issue #23): their
/// IDs have their own prefix, and a relaunch schedules the running ones
/// again at their original deadlines.
@MainActor
final class QuickTimerReminderTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "quick-timers-\(UUID().uuidString).json")
    }

    func testStartSchedulesAReminderInTheTimersOwnNamespace() {
        let notifications = MockNotifications()
        let store = QuickTimerStore(fileURL: temporaryFile(), notifications: notifications)
        let now = Date()
        let timer = store.start(recipeID: UUID(), dish: "Green beans", stepTitle: "Steam", durationText: "6 minutes", seconds: 360, now: now)
        XCTAssertNotNil(timer)
        XCTAssertEqual(notifications.scheduled.count, 1)
        XCTAssertTrue(notifications.scheduled[0].id.hasPrefix(QuickTimerStore.reminderPrefix), notifications.scheduled[0].id)
        XCTAssertEqual(notifications.scheduled[0].deadline, now.addingTimeInterval(360))
        store.stop(timer!.id)
        XCTAssertEqual(notifications.cancelled, [QuickTimerStore.reminderPrefix + timer!.id])
    }

    func testRelaunchSchedulesRunningTimersAgainAtTheirDeadlines() {
        let file = temporaryFile()
        let first = MockNotifications()
        let store = QuickTimerStore(fileURL: file, notifications: first)
        let now = Date()
        let running = store.start(recipeID: nil, dish: "Stew", stepTitle: "Simmer", durationText: "2 hours", seconds: 7200, now: now)!
        _ = store.start(recipeID: nil, dish: "Rolls", stepTitle: "Warm", durationText: "1 minute", seconds: 60, now: now.addingTimeInterval(-600))

        let second = MockNotifications()
        let relaunched = QuickTimerStore(fileURL: file, notifications: second)
        XCTAssertEqual(relaunched.timers.count, 2, "both timers come back; the one that's up is shown until dismissed")
        XCTAssertEqual(second.scheduled.map(\.id), [QuickTimerStore.reminderPrefix + running.id], "only the running one is reminded again")
        XCTAssertEqual(second.scheduled.first?.deadline, running.deadline, "…at its original deadline")
    }
}
#endif
