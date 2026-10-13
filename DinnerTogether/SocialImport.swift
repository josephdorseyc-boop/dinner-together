import Foundation

// TikTok and Instagram links (Joe, October 12: "automatically scan TikTok and
// Instagram videos when the user shares the link… add the cover and
// information"). Phase 1: the post's caption and cover image. Most recipe
// creators write the full recipe in the caption; this reads it with the text
// importer. When the caption has no recipe, the import says so and points at
// screenshots or pasted text — it never invents one. Pure parsing lives here
// so the Linux harness tests it; the network calls stay in
// RecipeImportService.

/// Which social site a link points at, and the canonical post URL.
enum SocialLink: Equatable {
    case tiktok(URL)
    case instagram(URL)

    var platform: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        }
    }

    var url: URL {
        switch self {
        case .tiktok(let u), .instagram(let u): return u
        }
    }

    /// TikTok short links (vm./vt.tiktok.com/…) must be followed to the
    /// video page before the oEmbed endpoint accepts them.
    var isShortLink: Bool {
        guard case .tiktok(let u) = self, let host = u.host?.lowercased() else { return false }
        return host.hasPrefix("vm.") || host.hasPrefix("vt.")
    }

    static func detect(_ url: URL) -> SocialLink? {
        guard let host = url.host?.lowercased() else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if bare == "tiktok.com" || bare.hasSuffix(".tiktok.com") { return .tiktok(url) }
        if bare == "instagram.com" || bare.hasSuffix(".instagram.com") || bare == "instagr.am" { return .instagram(url) }
        return nil
    }

    /// TikTok's public oEmbed endpoint: caption, author and cover, no sign-in.
    static func tiktokOEmbedURL(for video: URL) -> URL? {
        var components = URLComponents(string: "https://www.tiktok.com/oembed")
        components?.queryItems = [URLQueryItem(name: "url", value: video.absoluteString)]
        return components?.url
    }
}

/// What a post gives us before any recipe parsing.
struct SocialPost: Equatable {
    var platform: String
    var caption: String
    var author: String?
    var imageURL: URL?
    var url: URL
}

enum SocialImport {

    // MARK: TikTok oEmbed

    /// `{"title": "<caption>", "author_name": "…", "thumbnail_url": "…", …}`
    static func tiktokPost(fromOEmbed data: Data, url: URL) -> SocialPost? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let caption = json["title"] as? String else { return nil }
        let author = (json["author_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let image = (json["thumbnail_url"] as? String).flatMap(URL.init(string:))
        return SocialPost(platform: "TikTok", caption: caption, author: author, imageURL: image, url: url)
    }

    // MARK: Instagram page meta tags

    /// Public posts expose the caption to a plain fetch in their Open Graph
    /// tags: og:title is `Name on Instagram: "caption"`, og:description is
    /// `12 likes, 3 comments - name on October 1, 2026: "caption"`. A login
    /// wall has neither, so nil means "Instagram wouldn't show it".
    static func instagramPost(fromHTML html: String, url: URL) -> SocialPost? {
        let description = metaContent("og:description", in: html).map(RecipeImporter.decodeEntities)
        let title = metaContent("og:title", in: html).map(RecipeImporter.decodeEntities)
        var caption: String?
        var author: String?
        if let d = description,
           let m = RecipeImporter.firstMatch(#"(?s)^(?:[\d.,]+[KM]?\s+likes?,\s*)?(?:[\d.,]+[KM]?\s+comments?\s+-\s+)?(.+?)\s+on\s+\w+\s+\d{1,2},\s+\d{4}:\s*[“"](.*)[”"]\s*$"#, in: d, group: 2) {
            caption = m
            author = RecipeImporter.firstMatch(#"(?s)^(?:[\d.,]+[KM]?\s+likes?,\s*)?(?:[\d.,]+[KM]?\s+comments?\s+-\s+)?(.+?)\s+on\s+\w+\s+\d{1,2},\s+\d{4}:"#, in: d, group: 1)
        }
        if caption == nil, let t = title,
           let m = RecipeImporter.firstMatch(#"(?s)^(.+?)\s+on Instagram:\s*[“"](.*)[”"]\s*$"#, in: t, group: 2) {
            caption = m
            author = author ?? RecipeImporter.firstMatch(#"^(.+?)\s+on Instagram:"#, in: t, group: 1)
        }
        guard let caption, !caption.isEmpty else { return nil }
        let image = metaContent("og:image", in: html).map(RecipeImporter.decodeEntities).flatMap(URL.init(string:))
        return SocialPost(platform: "Instagram", caption: caption, author: author?.trimmingCharacters(in: .whitespaces), imageURL: image, url: url)
    }

    static func metaContent(_ property: String, in html: String) -> String? {
        let p = NSRegularExpression.escapedPattern(for: property)
        for q in ["\"", "'"] {
            let other = q == "\"" ? "'" : "\""
            let value = "\(q)([^\(q)]*)\(q)"
            let key = #"(?:property|name)\s*=\s*"# + "[\(q)\(other)]" + p + "[\(q)\(other)]"
            if let m = RecipeImporter.firstMatch(#"<meta\s+(?:[^>]*?\s)?"# + key + #"[^>]*?\scontent\s*=\s*"# + value, in: html, group: 1, caseInsensitive: true) { return m }
            if let m = RecipeImporter.firstMatch(#"<meta\s+(?:[^>]*?\s)?content\s*=\s*"# + value + #"[^>]*?\s"# + key, in: html, group: 1, caseInsensitive: true) { return m }
        }
        return nil
    }

    // MARK: Caption → recipe

    /// A caption as creators write it — emoji bullets, keycap step numbers,
    /// hashtag blocks, "Recipe 👇" — rewritten as the plain text the text
    /// importer reads. Emoji that only decorate are removed; words stay.
    static func cleanCaption(_ raw: String) -> String {
        var lines: [String] = []
        for rawLine in raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            var line = rawLine
            // Keycap digits ("1️⃣") → "1." so numbered steps read as steps.
            line = line.replacingOccurrences(of: #"(\d)️?⃣"#, with: "$1.", options: .regularExpression)
            // Hashtags and @mentions anywhere; a line that was only tags goes away.
            line = line.replacingOccurrences(of: #"(?<!\w)[#@][\p{L}\p{N}_]+"#, with: "", options: .regularExpression)
            line = stripEmoji(line)
            // Emoji or symbol bullets become list dashes.
            line = line.replacingOccurrences(of: #"^\s*[•●▪◦➡→✓✔☑▶►\-–—*]+\s*"#, with: "- ", options: .regularExpression)
            line = line.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// Removes pictographs and their modifiers; keeps letters, digits and
    /// punctuation (including ½ and °).
    static func stripEmoji(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            let v = u.value
            let isPictograph = u.properties.isEmojiPresentation
                || (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0x2B00...0x2BFF).contains(v)
            let isModifier = v == 0xFE0F || v == 0x200D || (0x1F3FB...0x1F3FF).contains(v) || (0xE0020...0xE007F).contains(v)
            if isPictograph || isModifier { continue }
            out.append(u)
        }
        return String(out)
    }

    /// The caption read as a recipe. Throws when it carries no recipe (then
    /// the comments or the video hold it, and the app says so).
    static func recipe(from post: SocialPost) throws -> ImportedRecipe {
        let text = cleanCaption(post.caption)
        var parsed: ImportedRecipe
        do {
            parsed = try RecipeImporter.parse(text: text)
        } catch {
            throw RecipeImportError.captionWithoutRecipe(platform: post.platform)
        }
        // A caption that only names the dish is not a recipe.
        guard !parsed.ingredients.isEmpty, !parsed.directions.isEmpty else {
            throw RecipeImportError.captionWithoutRecipe(platform: post.platform)
        }
        let firstLine = text.components(separatedBy: "\n").first { !$0.isEmpty } ?? ""
        if parsed.title == "Untitled recipe" {
            parsed.title = post.author.map { "Recipe from \($0)" } ?? "\(post.platform) recipe"
        } else if parsed.title == RecipeImporter.stripStepPrefix(firstLine) {
            parsed.title = captionTitle(firstLine)
        }
        parsed.source.publisher = post.platform
        parsed.source.author = post.author
        parsed.source.url = post.url
        parsed.imageURL = post.imageURL
        return parsed
    }

    /// The dish's name out of a caption's first line: up to its first
    /// sentence end, without a trailing "recipe below"/"recipe 👇".
    static func captionTitle(_ line: String) -> String {
        var t = line
        if let r = t.range(of: #"\s*[.!?|]+.*$"#, options: .regularExpression) {
            let head = String(t[..<r.lowerBound])
            if head.split(separator: " ").count >= 2 { t = head }
        }
        t = t.replacingOccurrences(of: #"\s*[-–—:(]*\s*(?:full\s+)?recipe\s*(?:below|down|in\s+(?:the\s+)?comments|here|is\s+here)?[\s:)]*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:,"))
        if t.isEmpty { t = line }
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    /// A non-social link inside the caption ("full recipe: https://…"): the
    /// recipe page is likely there, and the link importer reads those.
    static func recipeLink(inCaption caption: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>()]+"#) else { return nil }
        let ns = NSString(string: caption)
        return regex.matches(in: caption, options: [], range: NSRange(location: 0, length: ns.length))
            .compactMap { URL(string: ns.substring(with: $0.range).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))) }
            .first { url in SocialLink.detect(url) == nil && !(url.host ?? "").contains("linktr.ee") }
    }
}
