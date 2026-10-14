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
}
#endif
