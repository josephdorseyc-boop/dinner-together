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

