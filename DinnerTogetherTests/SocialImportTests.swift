import XCTest
@testable import DinnerTogether

// TikTok and Instagram links (phase 1: caption + cover). Fixtures are in the
// shape the services return — TikTok's public oEmbed JSON and Instagram's
// Open Graph tags for a public post — with captions written the way recipe
// creators write them.

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

/// A creator's caption: emoji bullets, keycap steps, hashtags, a "Recipe 👇".
private let ciderCaption = """
Whipped frozen apple cider 🍎🍂 the coziest fall drink!! Recipe 👇

Ingredients:
🍎 1½ cups apple cider
• 1½ tablespoons maple syrup
• 1 cinnamon stick
• ½ cup coconut milk

Steps:
1️⃣ Simmer the cider with the maple syrup and cinnamon for 10 minutes, then cool.
2️⃣ Freeze in an ice cube tray for 3 hours.
3️⃣ Blend with the coconut milk until slushy, about 30 seconds.

#fallrecipes #applecider #easyrecipe @eatingwell
"""

private func tiktokOEmbed(caption: String, author: String = "cozykitchen", thumb: String = "https://p16-sign.tiktokcdn.com/cover.jpeg") -> Data {
    let json: [String: Any] = ["version": "1.0", "type": "video", "title": caption, "author_name": author,
                               "author_url": "https://www.tiktok.com/@\(author)", "thumbnail_url": thumb,
                               "thumbnail_width": 720, "thumbnail_height": 1280, "provider_name": "TikTok",
                               "html": "<blockquote class=\"tiktok-embed\"></blockquote>"]
    return try! JSONSerialization.data(withJSONObject: json)
}

/// A publisher page with schema.org recipe data, the kind a caption links to.
private let linkedRecipeHTML = """
<html><head><script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Whipped Frozen Apple Cider","author":{"@type":"Person","name":"Julia Levy"},
 "image":"https://www.example.com/images/cider.jpg","totalTime":"PT4H10M","recipeYield":"2",
 "recipeIngredient":["1½ cups apple cider","1½ tablespoons maple syrup"],
 "recipeInstructions":[{"@type":"HowToStep","text":"Simmer the cider for 10 minutes."},{"@type":"HowToStep","text":"Freeze for 3 hours."}]}
</script></head><body></body></html>
"""

private func instagramHTML(caption: String?, author: String = "cozy.kitchen") -> String {
    guard let caption else {
        return "<html><head><title>Login • Instagram</title><meta property=\"og:title\" content=\"Instagram\"></head><body>Log in</body></html>"
    }
    let escaped = caption.replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "\n", with: "&#10;")
    return """
    <html><head>
    <meta property="og:title" content="\(author) on Instagram: &quot;\(escaped)&quot;" />
    <meta property="og:description" content="1,204 likes, 38 comments - \(author) on October 1, 2026: &quot;\(escaped)&quot;" />
    <meta property="og:image" content="https://scontent.cdninstagram.com/v/cover.jpg?x=1" />
    </head><body></body></html>
    """
}

final class SocialImportTests: XCTestCase {

    func testLinkDetection() {
        XCTAssertEqual(SocialLink.detect(URL(string: "https://www.tiktok.com/@cozykitchen/video/7291")!)?.platform, "TikTok")
        XCTAssertEqual(SocialLink.detect(URL(string: "https://vm.tiktok.com/ZM8abc/")!)?.isShortLink, true)
        XCTAssertEqual(SocialLink.detect(URL(string: "https://www.tiktok.com/@a/video/1")!)?.isShortLink, false)
        XCTAssertEqual(SocialLink.detect(URL(string: "https://www.instagram.com/reel/C1a2b3/")!)?.platform, "Instagram")
        XCTAssertEqual(SocialLink.detect(URL(string: "https://instagram.com/p/C1a2b3/?igsh=x")!)?.platform, "Instagram")
        XCTAssertNil(SocialLink.detect(URL(string: "https://www.eatingwell.com/recipe/1")!))
        XCTAssertNil(SocialLink.detect(URL(string: "https://nottiktok.com/x")!))
        let endpoint = SocialLink.tiktokOEmbedURL(for: URL(string: "https://www.tiktok.com/@a/video/1?lang=en")!)
        XCTAssertEqual(endpoint?.host, "www.tiktok.com")
        XCTAssertEqual(endpoint?.path, "/oembed")
        XCTAssertEqual(endpoint.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first?.value },
                       "https://www.tiktok.com/@a/video/1?lang=en", "the video URL survives the round trip")
    }

    func testCaptionCleaning() {
        let cleaned = SocialImport.cleanCaption(ciderCaption)
        XCTAssertTrue(cleaned.hasPrefix("Whipped frozen apple cider the coziest fall drink!! Recipe"), cleaned)
        XCTAssertTrue(cleaned.contains("\n1½ cups apple cider\n- 1½ tablespoons maple syrup"), "emoji bullets go, dot bullets become dashes: \(cleaned)")
        XCTAssertTrue(cleaned.contains("\n1. Simmer the cider"), "keycap numbers become step numbers: \(cleaned)")
        XCTAssertFalse(cleaned.contains("#") || cleaned.contains("@eatingwell") || cleaned.contains("🍎"), cleaned)
        XCTAssertEqual(SocialImport.stripEmoji("Bake at 350°F for ½ hour ✨ then 🧑‍🍳 serve"), "Bake at 350°F for ½ hour  then  serve")
    }

    func testTikTokCaptionBecomesARecipeWithItsCover() async throws {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                if url.host == "www.tiktok.com", url.path == "/oembed" {
                    XCTAssertTrue(url.query?.contains("video/7291") == true, "oEmbed asked about the video: \(url)")
                    return (tiktokOEmbed(caption: ciderCaption), url)
                }
                if url.host == "p16-sign.tiktokcdn.com" { return (Data(repeating: 0xCD, count: 40_000), url) }
                throw RecipeFetchError.badStatus(404)
            }
        }
        let result = try await RecipeImportService(fetcher: Fake())
            .importLink(URL(string: "https://www.tiktok.com/@cozykitchen/video/7291")!, now: t0)
        let r = result.recipe
        XCTAssertEqual(r.title, "Whipped frozen apple cider the coziest fall drink", "the first line up to its first sentence end, minus the 'recipe below' tail")
        XCTAssertEqual(r.ingredients, ["1½ cups apple cider", "1½ tablespoons maple syrup", "1 cinnamon stick", "½ cup coconut milk"])
        XCTAssertEqual(r.directions.count, 3, "\(r.directions)")
        XCTAssertEqual(r.directions[1], "Freeze in an ice cube tray for 3 hours.")
        XCTAssertEqual(r.source.publisher, "TikTok")
        XCTAssertEqual(r.source.author, "cozykitchen")
        XCTAssertEqual(r.source.url?.absoluteString, "https://www.tiktok.com/@cozykitchen/video/7291")
        XCTAssertEqual(result.imageData?.count, 40_000, "the post's cover is the recipe's photo")
        XCTAssertEqual(r.importMethod, .link)
        XCTAssertEqual(r.steps.map(\.minutes), [10, 180, 1], "step times come from the caption")
    }

    func testShortTikTokLinkIsFollowedFirst() async throws {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                if url.host == "vm.tiktok.com" { return (Data("<html></html>".utf8), URL(string: "https://www.tiktok.com/@cozykitchen/video/7291?_r=1")!) }
                if url.path == "/oembed" {
                    XCTAssertTrue(url.query?.contains("video/7291") == true, "oEmbed got the resolved video URL, not the short link: \(url)")
                    return (tiktokOEmbed(caption: ciderCaption), url)
                }
                throw RecipeFetchError.badStatus(404)
            }
        }
        let result = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://vm.tiktok.com/ZM8abc/")!, now: t0)
        XCTAssertEqual(result.recipe.ingredients.count, 4)
    }

    func testTikTokCaptionWithoutRecipeSaysSo() async {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                (tiktokOEmbed(caption: "The coziest fall drink 🍎 recipe in the comments 👇 #fall #cider"), url)
            }
        }
        do {
            _ = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://www.tiktok.com/@a/video/1")!, now: t0)
            XCTFail("a caption without a recipe must not become one")
        } catch {
            XCTAssertEqual(error as? RecipeImportError, .captionWithoutRecipe(platform: "TikTok"))
            XCTAssertTrue((error as? LocalizedError)?.errorDescription?.contains("TikTok post’s caption doesn’t include the recipe") == true)
        }
    }

    func testTikTokPrivateOrRemovedSaysSo() async {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) { throw RecipeFetchError.badStatus(404) }
        }
        do {
            _ = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://www.tiktok.com/@a/video/1")!, now: t0)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? RecipeImportError, .tiktokUnavailable)
        }
    }

    func testCaptionThatLinksToTheRecipePageFollowsIt() async throws {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                if url.path == "/oembed" { return (tiktokOEmbed(caption: "Full recipe here 👉 https://www.example.com/recipe/whipped-cider ✨ #cider"), url) }
                if url.host == "www.example.com" {
                    if url.path.hasSuffix(".jpg") { return (Data(repeating: 0xAB, count: 5_000), url) }
                    return (Data(linkedRecipeHTML.utf8), url)
                }
                throw RecipeFetchError.badStatus(404)
            }
        }
        let result = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://www.tiktok.com/@a/video/1")!, now: t0)
        XCTAssertEqual(result.recipe.title, "Whipped Frozen Apple Cider")
        XCTAssertEqual(result.recipe.source.url?.host, "www.example.com", "the recipe page the caption pointed at")
        XCTAssertEqual(result.recipe.totalMinutes, 250)
        XCTAssertEqual(result.imageData?.count, 5_000)
    }

    func testInstagramPublicPostCaption() async throws {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                if url.host == "www.instagram.com" { return (Data(instagramHTML(caption: ciderCaption).utf8), url) }
                if url.host == "scontent.cdninstagram.com" { return (Data(repeating: 0xEF, count: 12_000), url) }
                throw RecipeFetchError.badStatus(404)
            }
        }
        let result = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://www.instagram.com/reel/C1a2b3/")!, now: t0)
        XCTAssertEqual(result.recipe.source.publisher, "Instagram")
        XCTAssertEqual(result.recipe.source.author, "cozy.kitchen")
        XCTAssertEqual(result.recipe.ingredients.count, 4)
        XCTAssertEqual(result.recipe.directions.count, 3)
        XCTAssertEqual(result.imageData?.count, 12_000)
    }

    func testInstagramLoginWallSaysSo() async {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) { (Data(instagramHTML(caption: nil).utf8), url) }
        }
        do {
            _ = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://www.instagram.com/p/C1a2b3/")!, now: t0)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? RecipeImportError, .instagramLoginWall)
        }
    }

    func testInstagramMetaParsing() {
        let html = instagramHTML(caption: "Garlic butter noodles 🍝\n\nIngredients\n- 200 g noodles\n- 2 cloves garlic\n\nMethod\n1. Boil the noodles for 8 minutes.\n2. Toss with garlic butter.")
        let post = SocialImport.instagramPost(fromHTML: html, url: URL(string: "https://www.instagram.com/p/x/")!)
        XCTAssertEqual(post?.author, "cozy.kitchen")
        XCTAssertEqual(post?.imageURL?.host, "scontent.cdninstagram.com")
        XCTAssertTrue(post?.caption.hasPrefix("Garlic butter noodles") == true, post?.caption ?? "nil")
        let recipe = try? SocialImport.recipe(from: post!)
        XCTAssertEqual(recipe?.title, "Garlic butter noodles")
        XCTAssertEqual(recipe?.ingredients, ["200 g noodles", "2 cloves garlic"])
        XCTAssertEqual(recipe?.directions, ["Boil the noodles for 8 minutes.", "Toss with garlic butter."])
    }

    func testRecipeLinkInCaption() {
        XCTAssertEqual(SocialImport.recipeLink(inCaption: "recipe 👉 https://www.example.com/cider-recipe. enjoy! https://www.tiktok.com/@a")?.absoluteString,
                       "https://www.example.com/cider-recipe")
        XCTAssertNil(SocialImport.recipeLink(inCaption: "link in bio https://linktr.ee/cozykitchen"))
        XCTAssertNil(SocialImport.recipeLink(inCaption: "no links here"))
    }
}

// MARK: - The share extension's inbox (phase 1b)

final class SharedInboxTests: XCTestCase {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "dt-inbox-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testGroupIdentifierIsTheAppsForBothTargets() {
        XCTAssertEqual(SharedInbox.groupIdentifier(bundleIdentifier: "com.josephdorsey.dinnertogether"), "group.com.josephdorsey.dinnertogether")
        XCTAssertEqual(SharedInbox.groupIdentifier(bundleIdentifier: "com.josephdorsey.dinnertogether.share"), "group.com.josephdorsey.dinnertogether")
    }

    func testLinkRoundTripAndTakeClears() throws {
        let dir = tempDir()
        let item = SharedItem(kind: .link, url: URL(string: "https://www.tiktok.com/@a/video/1")!, createdAt: Date(timeIntervalSince1970: 1_760_000_000))
        try SharedInbox.write(item, images: [], in: dir)
        let taken = SharedInbox.take(from: dir, now: Date(timeIntervalSince1970: 1_760_000_100))
        XCTAssertEqual(taken?.item, item)
        XCTAssertEqual(taken?.images.count, 0)
        XCTAssertNil(SharedInbox.take(from: dir, now: Date(timeIntervalSince1970: 1_760_000_100)), "taken once")
    }

    func testImagesRoundTripInOrder() throws {
        let dir = tempDir()
        let a = Data(repeating: 0xA1, count: 3_000), b = Data(repeating: 0xB2, count: 2_000)
        try SharedInbox.write(SharedItem(kind: .images, createdAt: Date()), images: [a, b], in: dir)
        let taken = try XCTUnwrap(SharedInbox.take(from: dir))
        XCTAssertEqual(taken.item.kind, .images)
        XCTAssertEqual(taken.item.imageFiles, ["shared-1.img", "shared-2.img"])
        XCTAssertEqual(taken.images, [a, b])
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appending(path: SharedInbox.imagesFolder).path), "images are removed with the item")
    }

    func testStaleItemIsDropped() throws {
        let dir = tempDir()
        try SharedInbox.write(SharedItem(kind: .text, text: "old", createdAt: Date(timeIntervalSince1970: 1_760_000_000)), images: [], in: dir)
        XCTAssertNil(SharedInbox.take(from: dir, now: Date(timeIntervalSince1970: 1_760_000_000 + 90_000)), "a day-old hand-off does not pop up")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appending(path: SharedInbox.fileName).path), "…and is cleaned up")
    }

    func testFirstURLInSharedText() {
        XCTAssertEqual(SharedInbox.firstURL(in: "Check this out https://vm.tiktok.com/ZM8abc/ 🔥")?.absoluteString, "https://vm.tiktok.com/ZM8abc/")
        XCTAssertNil(SharedInbox.firstURL(in: "2 cups flour\n1 egg"))
    }
}


// MARK: - Joe's Instagram import (build 19): a caption laid out as a recipe

/// The shape of the post Joe imported: the dish's name running straight into
/// the creator's story, a "Comment BOMB" call to action, a lead-in, groups
/// headed "For the …:", amounts without numbers, an "(optional, …)" line under
/// its ingredient, the method, and "Save this…" at the end.
private let auPoivreCaption = """
Creamy Chicken Au Poivre 🍗🔥 This might be one of the best ways I’ve ever prepared a whole chicken. Listen it’s juicy, crispy skin and that creamy peppercorn sauce is EVERYTHINGGG thank you for sharing this recipe with us!

Interested in trying a Kickin’ Chicken Seasoning Bomb? Comment “BOMB” and I’ll send you the link!

My version of the viral chicken au poivre:

For the chicken:
1 whole young chicken (4–5 lb), spatchcocked, cleaned and pat dry
Salt, to taste
drizzle of good quality olive oil

For the creamy au poivre sauce:
1½ cups heavy cream (I used lactose free)
2 sprigs fresh rosemary, chopped
3 cloves garlic, chopped
1 shallot, sliced
2 tbsp crushed black peppercorns (more or less, and you can ground the texture as coarse or as fine as you like. This is entirely based on preference since they add a kick)
Generous pinch of salt
½ Kickin’ Chicken Seasoning Bomb
(optional, yes you can sub with a bouillon cube or seasoning)
Splash of sherry cooking wine

Pat the chicken dry, massage with olive oil and season with salt on both sides. Roast at 375°F for 15 minutes.
Meanwhile, steep the heavy cream with the rosemary, garlic, shallot, cracked peppercorns, salt and ½ Kickin’ Chicken Seasoning Bomb. You want to make sure this is simmering, not boiling, so steam coming off the pot and some *small* bubbles are okay!
Once the 15 minute timer is up, remove the chicken from the oven and pour the creamy au poivre sauce all over. Add a splash of sherry cooking wine and pop it back in the oven to finish roasting at 400 F. Let it roast until the chicken is golden brown and fully cooked through to 165°F.
Save this for your next chicken dinner! 🍗 #chickenaupoivre #wholechicken
"""

final class InstagramCaptionLayoutTests: XCTestCase {
    private func post(_ caption: String) -> SocialPost {
        SocialPost(platform: "Instagram", caption: caption, author: "Call Me Candace", imageURL: nil,
                   url: URL(string: "https://www.instagram.com/reel/C9x/")!)
    }

    func testJoesAuPoivreCaptionReadsAsTheRecipe() throws {
        let r = try SocialImport.recipe(from: post(auPoivreCaption))
        XCTAssertEqual(r.title, "Creamy Chicken Au Poivre", "the dish's name, not the story after it, nor “Recipe from Call Me Candace”")
        XCTAssertEqual(r.ingredients, [
            "For the chicken:",
            "1 whole young chicken (4–5 lb), spatchcocked, cleaned and pat dry",
            "Salt, to taste",
            "drizzle of good quality olive oil",
            "For the creamy au poivre sauce:",
            "1½ cups heavy cream (I used lactose free)",
            "2 sprigs fresh rosemary, chopped",
            "3 cloves garlic, chopped",
            "1 shallot, sliced",
            "2 tbsp crushed black peppercorns (more or less, and you can ground the texture as coarse or as fine as you like. This is entirely based on preference since they add a kick)",
            "Generous pinch of salt",
            "½ Kickin’ Chicken Seasoning Bomb (optional, yes you can sub with a bouillon cube or seasoning)",
            "Splash of sherry cooking wine",
        ])
        let steps = r.sections.flatMap(\.steps)
        XCTAssertEqual(steps.count, 3, "only the method: \(steps)")
        XCTAssertTrue(steps[0].hasPrefix("Pat the chicken dry"), steps[0])
        XCTAssertTrue(steps[1].hasPrefix("Meanwhile, steep the heavy cream"), steps[1])
        XCTAssertTrue(steps[2].hasPrefix("Once the 15 minute timer is up"), steps[2])
        let all = steps.joined(separator: " ")
        for gone in ["This might be one", "Comment", "My version", "For the chicken", "Save this"] {
            XCTAssertFalse(all.contains(gone), "“\(gone)…” is not a step")
        }
    }

    func testCallsToActionAndHeaders() {
        XCTAssertTrue(SocialImport.isCallToAction("Interested? Comment “BOMB” and I’ll send you the link!"))
        XCTAssertTrue(SocialImport.isCallToAction("Save this for your next chicken dinner!"))
        XCTAssertTrue(SocialImport.isCallToAction("Follow for more easy dinners"))
        XCTAssertFalse(SocialImport.isCallToAction("Save the remaining sauce in the fridge."), "a step that keeps food is not a call to action")
        XCTAssertFalse(SocialImport.isCallToAction("Save this marinade for basting the chicken later."), "nor saving part of the food (A2)")
        XCTAssertEqual(SocialImport.removingCallsToAction("Serve hot with the sauce. Save this for later!"), "Serve hot with the sauce.",
                       "a step with a call to action after it keeps the step (A2)")
        XCTAssertEqual(SocialImport.removingCallsToAction("Want the link? Comment “LINK” and I’ll DM you!"), "", "a question leading into one goes with it")
        XCTAssertEqual(SocialImport.removingCallsToAction("Bake for 1.5 hours."), "Bake for 1.5 hours.", "untouched without a call to action")
        XCTAssertTrue(SocialImport.isGroupHeader("For the creamy au poivre sauce:"))
        XCTAssertTrue(SocialImport.isGroupHeader("Sauce:"))
        XCTAssertFalse(SocialImport.isGroupHeader("My version of the viral chicken au poivre:"))
        XCTAssertFalse(SocialImport.isGroupHeader("1 cup flour"))
        XCTAssertTrue(SocialImport.isAmountPhrase("drizzle of good quality olive oil"))
        XCTAssertTrue(SocialImport.isAmountPhrase("Splash of sherry cooking wine"))
        XCTAssertFalse(SocialImport.isAmountPhrase("Drizzle the sauce over the chicken."))
    }

    func testFoodStorageStepsStayAndPromotionsGo() throws {
        let caption = """
        Herby Grilled Chicken
        2 lb chicken thighs
        1 cup yogurt marinade
        Marinate the chicken for 2 hours. Save this marinade for basting the chicken later.
        Grill for 12 minutes, basting twice. Save this for your next cookout!
        Follow for more easy dinners
        """
        let r = try SocialImport.recipe(from: post(caption))
        let steps = r.sections.flatMap(\.steps)
        XCTAssertEqual(steps, ["Marinate the chicken for 2 hours. Save this marinade for basting the chicken later.",
                               "Grill for 12 minutes, basting twice."], "\(steps)")
    }

    func testLeadingTitle() {
        XCTAssertEqual(SocialImport.leadingTitle("Creamy Chicken Au Poivre This might be one of the best"), "Creamy Chicken Au Poivre")
        XCTAssertEqual(SocialImport.leadingTitle("Garlic Butter Steak Bites Recipe below"), "Garlic Butter Steak Bites")
        XCTAssertEqual(SocialImport.leadingTitle("Lemon Herb Chicken"), "Lemon Herb Chicken")
        XCTAssertEqual(SocialImport.leadingTitle("Whipped frozen apple cider the coziest fall drink!! Recipe"),
                       "Whipped frozen apple cider the coziest fall drink", "a sentence-case first line keeps the old rule")
    }
}

// MARK: - The ▶ baked into a video post's cover (Joe, build 19)

final class PlayOverlayTests: XCTestCase {
    /// A 160 × 284 picture: a textured mid-tone photo, optionally with a
    /// dark disc and a white right-pointing triangle at its centre.
    private func picture(button: Bool, triangle: Bool = true, pointsLeft: Bool = false, square: Bool = false) -> [Double] {
        let w = 160, h = 284
        var luma = [Double](repeating: 0, count: w * h)
        let cx = Double(w) / 2, cy = Double(h) / 2, r = 22.0
        for y in 0..<h {
            for x in 0..<w {
                // Texture: a soft pattern between 0.35 and 0.75, never white.
                var l = 0.55 + 0.2 * sin(Double(x) * 0.21) * cos(Double(y) * 0.17)
                if button {
                    let dx = Double(x) - cx, dy = Double(y) - cy
                    if hypot(dx, dy) <= r { l *= 0.55 } // the translucent dark disc
                    let tx = pointsLeft ? -dx : dx
                    let inTriangle = tx >= -7 && tx <= 10 && abs(dy) <= (10 - tx) * 11 / 17
                    let inSquare = abs(dx) <= 8 && abs(dy) <= 8
                    if triangle ? inTriangle : (square ? inSquare : hypot(dx, dy) <= 8) { l = 0.97 }
                }
                luma[y * w + x] = l
            }
        }
        return luma
    }

    func testFindsThePlayButtonAtTheCentre() throws {
        let hit = try XCTUnwrap(PlayOverlay.find(luma: picture(button: true), width: 160, height: 284))
        XCTAssertEqual(hit.centerX, 80, accuracy: 4)
        XCTAssertEqual(hit.centerY, 142, accuracy: 4)
        XCTAssertGreaterThan(hit.radius, 20, "clears the disc")
    }

    func testLeavesOtherPicturesAlone() {
        XCTAssertNil(PlayOverlay.find(luma: picture(button: false), width: 160, height: 284), "a photo without a button")
        XCTAssertNil(PlayOverlay.find(luma: picture(button: true, triangle: false), width: 160, height: 284), "a white dot is not a ▶")
        XCTAssertNil(PlayOverlay.find(luma: picture(button: true, triangle: false, square: true), width: 160, height: 284), "nor a white square")
        XCTAssertNil(PlayOverlay.find(luma: picture(button: true, pointsLeft: true), width: 160, height: 284), "nor a ◀")
    }

    func testKeepsTheTallerCleanBand() throws {
        // A 1080 × 1920 reel cover sampled at 160 wide (scale 6.75), the
        // button a little below the middle: more picture above it.
        let below = PlayOverlay.Hit(centerX: 80, centerY: 150, radius: 30)
        let band = try XCTUnwrap(PlayOverlay.cleanBand(width: 1080, height: 1920, hit: below, scale: 6.75))
        XCTAssertEqual(band.y, 0, "above the button")
        XCTAssertEqual(band.height, (150 - 30) * 6.75, accuracy: 0.5)
        // A little above the middle: more below it.
        let above = PlayOverlay.Hit(centerX: 80, centerY: 134, radius: 30)
        let lower = try XCTUnwrap(PlayOverlay.cleanBand(width: 1080, height: 1920, hit: above, scale: 6.75))
        XCTAssertEqual(lower.y, (134 + 30) * 6.75, accuracy: 0.5, "below the button")
        XCTAssertEqual(lower.y + lower.height, 1920, accuracy: 0.5)
        XCTAssertNil(PlayOverlay.cleanBand(width: 1080, height: 400, hit: PlayOverlay.Hit(centerX: 80, centerY: 30, radius: 25), scale: 6.75),
                     "too thin either side: the cover stays as it was")
    }
}


/// Regression reconstructed from Joe's screenshots of reel DdmzFTjpZLL.
/// The live Instagram caption could not be fetched; this is not a network test.
final class SocialCaptionSeparatorTests: XCTestCase {
    private let source = URL(string: "https://www.instagram.com/reel/DdmzFTjpZLL/")!
    private let ingredients = "1 lb fresh green beans • 8 oz mushrooms, sliced • 3 tbsp butter • 4 cloves garlic, minced • 1 tbsp olive oil • ½ tsp Italian seasoning • ½ tsp red pepper flakes, optional • Salt & black pepper • 1 tbsp lemon juice • Fresh parsley"
    private let directions = "1. Blanch green beans in boiling water for 3–4 minutes, then drain. 2. Heat olive oil in a skillet and sauté mushrooms until golden. 3. Add butter and garlic, cooking for 1 minute until fragrant. 4. Stir in green beans, Italian seasoning, salt, and pepper. 5. Cook for 3–5 minutes, tossing until well coated and tender. 6. Finish with lemon juice and fresh parsley."

    private func parse(_ caption: String, platform: String = "Instagram") throws -> ImportedRecipe {
        try SocialImport.recipe(from: SocialPost(platform: platform, caption: caption, author: nil,
                                                 imageURL: nil, url: source))
    }

    func testGreenBeanScreenshotBecomesTenIngredientsAndSixSteps() throws {
        let r = try parse("Garlic Butter Green Beans\nIngredients:\n\(ingredients)\nDirections:\n\(directions)\nSAVE this easy garlic butter side dish!")
        XCTAssertEqual(r.ingredients.count, 10, "\(r.ingredients)")
        XCTAssertEqual(r.ingredients[1], "8 oz mushrooms, sliced")
        XCTAssertEqual(r.ingredients[6], "½ tsp red pepper flakes, optional")
        XCTAssertEqual(r.ingredients[7], "Salt & black pepper")
        XCTAssertEqual(r.ingredients.last, "Fresh parsley")
        XCTAssertEqual(r.directions.count, 6, "\(r.directions)")
        XCTAssertEqual(r.directions.first, "Blanch green beans in boiling water for 3–4 minutes, then drain.")
        XCTAssertEqual(r.directions.last, "Finish with lemon juice and fresh parsley.")
        XCTAssertEqual(r.directions.map { RecipeImporter.minutes(in: $0) }, [4, nil, 1, nil, 5, nil])
        XCTAssertFalse(r.directions.joined().contains("SAVE"))
        XCTAssertEqual(r.source.url, source)
    }

    func testInlineHeadingsAndTrailingPromotionOnSameLine() throws {
        let r = try parse("Garlic Butter Green Beans\nIngredients: \(ingredients)\nDirections: \(directions) SAVE this easy garlic butter side dish!")
        XCTAssertEqual(r.ingredients.count, 10)
        XCTAssertEqual(r.directions.count, 6)
        XCTAssertEqual(r.directions.last, "Finish with lemon juice and fresh parsley.")
    }

    func testHeaderlessCaptionAndTikTokUseSameCleanup() throws {
        let r = try parse("Garlic Butter Green Beans\n\(ingredients)\n\(directions)\nSAVE this easy garlic butter side dish!", platform: "TikTok")
        XCTAssertEqual(r.ingredients.count, 10)
        XCTAssertEqual(r.directions.count, 6)
        XCTAssertEqual(r.source.publisher, "TikTok")
    }

    func testParenthesizedAndKeycapNumberedLists() throws {
        for method in ["1) Boil for 4 minutes. 2) Drain and serve.",
                       "1️⃣ Boil for 4 minutes. 2️⃣ Drain and serve."] {
            let r = try parse("Green Beans\nIngredients: 1 lb beans • ½ tsp salt\nSteps: \(method)")
            XCTAssertEqual(r.ingredients.count, 2)
            XCTAssertEqual(r.directions, ["Boil for 4 minutes.", "Drain and serve."])
        }
    }

    func testFractionsDecimalsCommasAndRangesStayIntact() throws {
        let r = try parse("Slow Cooked Beans\nIngredients: 1.5 lb beans, trimmed • 1 1/2 tbsp oil • ½ tsp salt\nDirections: 1. Cook at 350°F for 1.5 hours. 2. Rest for 3–5 minutes. Save this easy recipe!")
        XCTAssertEqual(r.ingredients, ["1.5 lb beans, trimmed", "1 1/2 tbsp oil", "½ tsp salt"])
        XCTAssertEqual(r.directions, ["Cook at 350°F for 1.5 hours.", "Rest for 3–5 minutes."])
        XCTAssertEqual(RecipeImporter.minutes(in: r.directions[0]), 90)
        XCTAssertEqual(SocialImport.removingCallsToAction("Bake for 1.5 hours. Save this easy recipe!"), "Bake for 1.5 hours.")
    }

    func testFoodSavingInstructionsArePreserved() throws {
        let r = try parse("Marinated Beans\nIngredients: 1 lb beans • 1 cup marinade\nDirections: 1. Cook for 4 minutes. Save this marinade for basting later. 2. Save the remaining beans in the fridge.\nSave this easy side dish!")
        XCTAssertEqual(r.directions, ["Cook for 4 minutes. Save this marinade for basting later.", "Save the remaining beans in the fridge."])
    }

    func testAmbiguousNumbersAndOrdinarySentencesAreNotSplit() {
        for line in ["Cook for 1.5 hours. Rest, then serve.",
                     "Use dish 1. Cook for 2 minutes.",
                     "1. Cook for 4 minutes. 3. Serve.",
                     "1.5 tbsp oil", "1. Cook and serve."] {
            XCTAssertEqual(SocialImport.splitNumberedCaptionSteps(line), [line])
        }
        XCTAssertEqual(SocialImport.captionLayoutLines("A cozy dinner • perfect for fall"), ["A cozy dinner • perfect for fall"])
    }

    func testNumberedStepsOnSeparateLinesStillWork() throws {
        let r = try parse("Simple Beans\nIngredients\n1 lb beans\n½ tsp salt\nDirections\n1. Boil for 4 minutes.\n2. Drain.\n3. Serve.")
        XCTAssertEqual(r.ingredients, ["1 lb beans", "½ tsp salt"])
        XCTAssertEqual(r.directions, ["Boil for 4 minutes.", "Drain.", "Serve."])
    }
}
