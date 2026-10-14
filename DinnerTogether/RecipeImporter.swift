import Foundation

// Turns a recipe page or pasted text into a `Recipe` the engine can plan.
// Everything here is a pure function of its input: no network, no UI, no
// clock. `RecipePageFetcher` (in RecipeLibrary.swift) does the one network
// call and hands the HTML to `parse(html:url:)`.
//
// Two honest limits, by design:
// - A parsed recipe is a *draft*. Times found in the text are kept; times
//   that had to be guessed are marked `estimated` so the Timing tab can ask.
// - Sections are cooked in order (one dish). Only an explicit "meanwhile"
//   becomes a parallel dish. Being slow is a plan; being wrong is not.

/// What a page or a block of text said, before timing is attached.
struct ImportedRecipe: Equatable {
    var title: String
    var source: RecipeSource = RecipeSource()
    var imageURL: URL?
    var yield: String?
    var totalMinutes: Int?
    var ingredients: [String] = []
    var sections: [ImportedSection] = []
    /// "Do Ahead", "Editor's note", storage tips: kept with the recipe, never
    /// scheduled as a cooking step.
    var notes: [String] = []
    /// What the screenshots could not establish: text left out because it
    /// could not be read, step numbers never seen, a last step cut short.
    /// Shown with the timing review; never silently absorbed into the plan.
    var warnings: [String] = []

    var directions: [String] { sections.flatMap { $0.steps } }
}

struct ImportedSection: Equatable {
    var name: String?
    var steps: [String]
}

enum RecipeImportError: Error, Equatable, LocalizedError {
    case noRecipeData
    case emptyText
    /// An apple.news link: News serves a placeholder page, never the recipe.
    case appleNewsOnly(title: String?)
    case noTextInScreenshots
    /// A TikTok or Instagram post whose caption carries no recipe.
    case captionWithoutRecipe(platform: String)
    /// Instagram served its sign-in page instead of the post.
    case instagramLoginWall
    /// TikTok's endpoint had nothing for this link (private, removed, or not a video).
    case tiktokUnavailable

    var errorDescription: String? {
        switch self {
        case .captionWithoutRecipe(let platform):
            return "This \(platform) post’s caption doesn’t include the recipe. If it’s in the comments or spoken in the video, take screenshots of it and choose them, or paste the text."
        case .instagramLoginWall:
            return "Instagram doesn’t let apps read posts without signing in. Take screenshots of the caption and recipe and choose them, or paste the caption text."
        case .tiktokUnavailable:
            return "TikTok couldn’t provide this video’s details — it may be private or removed. Take screenshots of the caption and choose them, or paste the text."
        case .noRecipeData:
            return "This page doesn’t include recipe data the app can read. Copy the recipe text and paste it instead."
        case .emptyText:
            return "Paste the recipe’s ingredients and directions first."
        case .appleNewsOnly(let title):
            let name = title.map { "“\($0)” " } ?? "This recipe "
            return name + "isn’t available through this Apple News link. Choose screenshots of the full recipe, or paste its text."
        case .noTextInScreenshots:
            return "We couldn’t find recipe text in those images. Choose screenshots that show the ingredients and steps."
        }
    }
}

enum RecipeImporter {

    // MARK: - Pages (schema.org Recipe JSON-LD, microdata fallback)

    static func parse(html: String, url: URL?) throws -> ImportedRecipe {
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let object = findRecipeObject(in: json), let parsed = recipe(from: object, url: url) {
                return parsed
            }
        }
        if let parsed = microdataRecipe(in: html, url: url) { return parsed }
        throw RecipeImportError.noRecipeData
    }

    /// Where a wrapper page (apple.news, link shorteners with an HTML
    /// interstitial) sends the reader next. Nil for an ordinary page.
    static func redirectTarget(inHTML html: String, from url: URL) -> URL? {
        if let m = firstMatch(#"<meta[^>]+http-equiv\s*=\s*["']?refresh["']?[^>]*content\s*=\s*["'][^"']*url\s*=\s*([^"'\s>]+)"#, in: html, group: 1),
           let target = URL(string: m), target.host != nil { return target }
        let host = (url.host ?? "").lowercased()
        guard host.hasSuffix("apple.news") || host.hasSuffix("apple.com") else { return nil }
        for pattern in [#"location\.replace\(\s*["']([^"']+)["']"#,
                        #"location\.href\s*=\s*["']([^"']+)["']"#,
                        #"<link[^>]+rel\s*=\s*["']canonical["'][^>]*href\s*=\s*["']([^"']+)["']"#,
                        #"(https?://[^"'\s<>]+)"#] {
            for candidate in allMatches(pattern, in: html, group: 1) {
                guard let target = URL(string: decodeEntities(candidate)),
                      let targetHost = target.host?.lowercased(),
                      !targetHost.hasSuffix("apple.news"), !targetHost.hasSuffix("apple.com"),
                      !targetHost.contains("mzstatic"), !targetHost.contains("w3.org"),
                      !targetHost.contains("schema.org") else { continue }
                return target
            }
        }
        return nil
    }

    /// apple.news links open a "only available in Apple News" placeholder that
    /// carries the title and nothing else (checked October 11, 2026).
    static func isAppleNewsPlaceholder(url: URL, html: String) -> Bool {
        let host = (url.host ?? "").lowercased()
        return host.hasSuffix("apple.news") || html.contains("only available in Apple News")
    }

    /// og:title without the " — Publisher" suffix.
    static func placeholderTitle(_ html: String) -> String? {
        let raw = firstMatch(#"<meta[^>]+property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']+)["']"#, in: html, group: 1, caseInsensitive: true)
            ?? firstMatch(#"<title[^>]*>([\s\S]*?)</title>"#, in: html, group: 1, caseInsensitive: true)
        guard let t = raw.map(decodeEntities).map(cleanLine), !t.isEmpty else { return nil }
        return t.components(separatedBy: " — ").first?.components(separatedBy: " - ").first ?? t
    }

    static func jsonLDBlocks(in html: String) -> [String] {
        allMatches(#"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#,
                   in: html, group: 1, caseInsensitive: true)
            .map { $0.replacingOccurrences(of: "<!--", with: "").replacingOccurrences(of: "-->", with: "")
                     .replacingOccurrences(of: "//<![CDATA[", with: "").replacingOccurrences(of: "//]]>", with: "")
                     .trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Finds the first object whose @type is (or includes) "Recipe", looking
    /// through arrays and @graph wrappers.
    static func findRecipeObject(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if typeNames(dict["@type"]).contains("recipe") { return dict }
            if let graph = dict["@graph"] { if let found = findRecipeObject(in: graph) { return found } }
            if let main = dict["mainEntity"] { if let found = findRecipeObject(in: main) { return found } }
            return nil
        }
        if let array = json as? [Any] {
            for item in array { if let found = findRecipeObject(in: item) { return found } }
        }
        return nil
    }

    private static func typeNames(_ any: Any?) -> [String] {
        if let s = any as? String { return [s.lowercased()] }
        if let a = any as? [Any] { return a.compactMap { ($0 as? String)?.lowercased() } }
        return []
    }

    private static func recipe(from dict: [String: Any], url: URL?) -> ImportedRecipe? {
        guard let title = text(dict["name"]).flatMap({ $0.isEmpty ? nil : $0 }) else { return nil }
        var recipe = ImportedRecipe(title: title)
        recipe.source.url = url
        recipe.source.author = text(dict["author"])
        recipe.source.publisher = text(dict["publisher"]) ?? publisherName(from: url)
        recipe.imageURL = imageURL(dict["image"])
        recipe.yield = yieldText(dict["recipeYield"])
        recipe.totalMinutes = duration(dict["totalTime"]) ?? sum(duration(dict["prepTime"]), duration(dict["cookTime"]))
        recipe.ingredients = stringList(dict["recipeIngredient"] ?? dict["ingredients"]).map(cleanLine)
            .filter { !$0.isEmpty }
        var notes: [String] = []
        recipe.sections = instructionSections(dict["recipeInstructions"], notes: &notes)
        recipe.notes = notes
        guard !recipe.ingredients.isEmpty || !recipe.sections.isEmpty else { return nil }
        return recipe
    }

    private static func sum(_ a: Int?, _ b: Int?) -> Int? {
        if a == nil && b == nil { return nil }
        return (a ?? 0) + (b ?? 0)
    }

    private static func instructionSections(_ any: Any?, notes: inout [String]) -> [ImportedSection] {
        guard let any = any else { return [] }
        if let s = any as? String {
            return [ImportedSection(name: nil, steps: separatingNotes(splitSteps(from: s), into: &notes))]
        }
        if let dict = any as? [String: Any] {
            return instructionSections(dict["itemListElement"] ?? dict["text"], notes: &notes)
        }
        guard let array = any as? [Any] else { return [] }
        var sections: [ImportedSection] = []
        var loose: [String] = []
        for item in array {
            if let s = item as? String {
                loose.append(contentsOf: separatingNotes(splitSteps(from: s), into: &notes))
            } else if let dict = item as? [String: Any] {
                let types = typeNames(dict["@type"])
                if types.contains("howtosection") || dict["itemListElement"] != nil {
                    if !loose.isEmpty { sections.append(ImportedSection(name: nil, steps: loose)); loose = [] }
                    let inner = instructionSections(dict["itemListElement"], notes: &notes).flatMap { $0.steps }
                    sections.append(ImportedSection(name: text(dict["name"]), steps: inner))
                } else if let t = text(dict["text"]) ?? text(dict["name"]) {
                    // One HowToStep is one step: its paragraphs stay together,
                    // except paragraphs that are notes (A1-R1: Bon Appétit's
                    // "Do Ahead:" and "Editor’s note:" became cooking steps).
                    let paragraphs = cleanLine(t).components(separatedBy: .newlines).map(cleanLine).filter { !$0.isEmpty }
                    let body = separatingNotes(paragraphs, into: &notes)
                    let step = stripStepPrefix(joinLines(body))
                    if !step.isEmpty { loose.append(step) }
                }
            }
        }
        if !loose.isEmpty { sections.append(ImportedSection(name: nil, steps: loose)) }
        return sections.filter { !$0.steps.isEmpty }
    }

    /// Paragraphs that annotate a recipe rather than instruct.
    static func isNoteLine(_ line: String) -> Bool {
        line.range(of: #"^\s*(?:do[- ]ahead|make[- ]ahead|editor[’']?s note|cook[’']?s note|recipe note|notes?|tips?|storage|to store|leftovers|variations?|substitutions?|head this way)\b\s*[:.—–-]?"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func separatingNotes(_ lines: [String], into notes: inout [String]) -> [String] {
        var kept: [String] = []
        for line in lines { if isNoteLine(line) { notes.append(line) } else { kept.append(line) } }
        return kept
    }

    /// A single instruction string often holds several steps.
    static func splitSteps(from raw: String) -> [String] {
        let cleaned = cleanLine(raw)
        guard !cleaned.isEmpty else { return [] }
        let lines = cleaned.components(separatedBy: .newlines).map(cleanLine).filter { !$0.isEmpty }
        if lines.count > 1 { return lines.map(stripStepPrefix).filter { !$0.isEmpty } }
        // One line with "1. … 2. …" markers inside it.
        guard let regex = try? NSRegularExpression(pattern: #"(?:^|\s)\d{1,2}[.)]\s+"#) else { return [stripStepPrefix(cleaned)] }
        let ns = NSString(string: cleaned)
        let marks = regex.matches(in: cleaned, options: [], range: NSRange(location: 0, length: ns.length))
        guard marks.count >= 2 else { return [stripStepPrefix(cleaned)] }
        var parts: [String] = []
        var start = 0
        for (i, m) in marks.enumerated() {
            let end = m.range.location
            if i == 0 {
                let head = ns.substring(with: NSRange(location: 0, length: end)).trimmingCharacters(in: .whitespaces)
                if !head.isEmpty { parts.append(head) }
            } else {
                parts.append(ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespaces))
            }
            start = m.range.location + m.range.length
        }
        parts.append(ns.substring(from: start).trimmingCharacters(in: .whitespaces))
        return parts.filter { !$0.isEmpty }
    }

    static func stripStepPrefix(_ line: String) -> String {
        line.replacingOccurrences(of: #"^\s*(?:step\s*\d+\s*[:.)-]?\s*|\d{1,2}\s*[.):-]\s+|[-•*·]\s+)"#,
                                  with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func microdataRecipe(in html: String, url: URL?) -> ImportedRecipe? {
        let ingredients = allMatches(#"itemprop\s*=\s*["'](?:recipeIngredient|ingredients)["'][^>]*>([\s\S]*?)</"#,
                                     in: html, group: 1, caseInsensitive: true).map(cleanLine).filter { !$0.isEmpty }
        let steps = allMatches(#"itemprop\s*=\s*["']recipeInstructions["'][^>]*>([\s\S]*?)</(?:li|p|div|ol)>"#,
                               in: html, group: 1, caseInsensitive: true).flatMap(splitSteps)
        guard !ingredients.isEmpty, !steps.isEmpty else { return nil }
        let title = firstMatch(#"<title[^>]*>([\s\S]*?)</title>"#, in: html, group: 1, caseInsensitive: true)
            .map(cleanLine).map { $0.components(separatedBy: " | ").first ?? $0 }
            .map { $0.components(separatedBy: " - ").first ?? $0 } ?? "Recipe"
        var recipe = ImportedRecipe(title: title)
        recipe.source.url = url
        recipe.source.publisher = publisherName(from: url)
        recipe.ingredients = ingredients
        recipe.sections = [ImportedSection(name: nil, steps: steps)]
        return recipe
    }

    // MARK: - Pasted text

    static func parse(text raw: String) throws -> ImportedRecipe {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").map { cleanLine($0) }
        let nonEmpty = lines.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { throw RecipeImportError.emptyText }

        var title = "Untitled recipe"
        var ingredients: [String] = []
        var steps: [String] = []
        var yield: String?
        var totalMinutes: Int?
        var notes: [String] = []
        var mode = 0 // 0 unknown, 1 ingredients, 2 steps
        var first = true

        for line in nonEmpty {
            let lower = line.lowercased()
            if let y = firstMatch(#"^(?:yield|serves|servings|makes)\s*[:：]?\s*(.+)$"#, in: line, group: 1, caseInsensitive: true) {
                yield = yield ?? cleanLine(y); continue
            }
            if lower.hasPrefix("total time") || lower.hasPrefix("time:") {
                totalMinutes = totalMinutes ?? minutes(in: line); continue
            }
            if lower.hasPrefix("prep time") || lower.hasPrefix("cook time") || lower.hasPrefix("active time") {
                continue
            }
            if isIngredientsHeader(line) { mode = 1; first = false; continue }
            if isDirectionsHeader(line) { mode = 2; first = false; continue }
            if first {
                first = false
                // A long first line can still be a title (A2 R5 finding): reject
                // it only when it reads like an instruction — numbered, starts
                // with a cooking verb, or ends in a full stop.
                if line.count <= 120, !looksLikeIngredient(line), !looksLikeInstruction(line) { title = stripStepPrefix(line); continue }
            }
            switch mode {
            case 1: ingredients.append(stripStepPrefix(line))
            case 2:
                if isNoteLine(line) { notes.append(line) } else { steps.append(stripStepPrefix(line)) }
            default:
                if looksLikeIngredient(line) { ingredients.append(stripStepPrefix(line)) }
                else if looksLikeStep(line) || line.count > 60 { steps.append(stripStepPrefix(line)) }
                else if steps.isEmpty { ingredients.append(stripStepPrefix(line)) }
                else { steps.append(stripStepPrefix(line)) }
            }
        }
        ingredients = ingredients.filter { !$0.isEmpty }
        steps = steps.filter { !$0.isEmpty && $0.count > 1 }
        guard !ingredients.isEmpty || !steps.isEmpty else { throw RecipeImportError.emptyText }
        var recipe = ImportedRecipe(title: title)
        recipe.ingredients = ingredients
        recipe.sections = steps.isEmpty ? [] : [ImportedSection(name: nil, steps: steps)]
        recipe.yield = yield
        recipe.totalMinutes = totalMinutes
        recipe.notes = notes
        return recipe
    }

    static func isIngredientsHeader(_ line: String) -> Bool {
        line.range(of: #"^(?:ingredients?|what you(?:'ll| will)? need|you will need|shopping list)\s*[:：]?\s*$"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isDirectionsHeader(_ line: String) -> Bool {
        line.range(of: #"^(?:directions?|instructions?|method|steps?|preparation|how to make it|to prepare|procedure)\s*[:：]?\s*$"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func looksLikeIngredient(_ line: String) -> Bool {
        let l = line.lowercased()
        if l.range(of: #"^\s*(?:[-•*·]\s*)?(?:\d|½|¼|¾|⅓|⅔|⅛|a pinch|pinch of|salt|pepper|juice of|zest of)"#, options: .regularExpression) != nil { return true }
        let units = #"\b(?:cups?|tbsp|tsp|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|grams?|g|kg|ml|liters?|cloves?|cans?|packages?|bunch|sprigs?|pinch|slices?|sticks?|heads?)\b"#
        return line.count <= 70 && !l.hasSuffix(".") && l.range(of: units, options: .regularExpression) != nil
    }

    /// `looksLikeStep` without its "any long line" fallback: used for titles.
    static func looksLikeInstruction(_ line: String) -> Bool {
        let l = line.lowercased().trimmingCharacters(in: .whitespaces)
        if l.hasSuffix(".") || l.hasSuffix("!") { return true }
        if l.range(of: #"^\s*(?:step\s*\d+|\d{1,2}\s*[.):-]\s+)"#, options: .regularExpression) != nil { return true }
        return l.range(of: stepVerbs, options: .regularExpression) != nil
    }

    static let stepVerbs = #"^\s*(?:preheat|heat|combine|mix|stir|whisk|add|cook|bake|roast|simmer|boil|bring|place|put|pour|season|serve|remove|transfer|drain|let|cover|reduce|melt|sauté|saute|fry|chop|slice|dice|toss|fold|beat|cut|divide|spread|sprinkle|garnish|meanwhile|while|once|when|in a|using)\b"#

    static func looksLikeStep(_ line: String) -> Bool {
        let l = line.lowercased()
        if l.range(of: #"^\s*(?:step\s*\d+|\d{1,2}\s*[.):-]\s+)"#, options: .regularExpression) != nil { return true }
        let verbs = #"^\s*(?:preheat|heat|combine|mix|stir|whisk|add|cook|bake|roast|simmer|boil|bring|place|put|pour|season|serve|remove|transfer|drain|let|cover|reduce|melt|sauté|saute|fry|chop|slice|dice|toss|fold|beat|cut|divide|spread|sprinkle|garnish|meanwhile|while|once|when|in a|using)\b"#
        return l.range(of: verbs, options: .regularExpression) != nil || (line.count > 60 && l.contains(" "))
    }

    // MARK: - Durations and attention

    /// Every duration mentioned in the text, summed, in whole minutes
    /// (seconds round up to 1). Ranges take the upper bound: "8–10 minutes"
    /// plans as 10. Nil when the text states no time at all.
    static func minutes(in text: String) -> Int? {
        let t = text.lowercased()
            .replacingOccurrences(of: "½", with: " 1/2").replacingOccurrences(of: "¼", with: " 1/4")
            .replacingOccurrences(of: "¾", with: " 3/4").replacingOccurrences(of: "⅓", with: " 1/3")
            .replacingOccurrences(of: "⅔", with: " 2/3").replacingOccurrences(of: "⅛", with: " 1/8")
        var total = 0.0
        var found = false
        let number = #"(?:(\d+(?:[.,]\d+)?)(?:\s+(\d)/(\d))?|(\d)/(\d)|(one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|forty|forty-five|sixty|ninety|an|a|half an|a half|one and a half|one-and-a-half))"#
        let unit = #"\s*(seconds?|secs?|minutes?|mins?|min\b|hours?|hrs?|hr\b|h\b)"#
        let pattern = number + #"(?:\s*(?:to|-|–|—|or)\s*"# + number + #")?"# + unit
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = NSString(string: t)
        for m in regex.matches(in: t, options: [], range: NSRange(location: 0, length: ns.length)) {
            func group(_ i: Int) -> String? {
                let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            // Groups: 1-6 first number, 7-12 second number, 13 unit.
            let first = numberValue(whole: group(1), fracN: group(2), fracD: group(3), loneN: group(4), loneD: group(5), word: group(6))
            let second = numberValue(whole: group(7), fracN: group(8), fracD: group(9), loneN: group(10), loneD: group(11), word: group(12))
            guard let unitText = group(13), let value = second ?? first else { continue }
            let mins: Double
            if unitText.hasPrefix("s") { mins = value / 60 }
            else if unitText.hasPrefix("h") { mins = value * 60 }
            else { mins = value }
            total += mins; found = true
        }
        if t.contains("overnight") { total += 8 * 60; found = true }
        else if !found && t.range(of: #"\ba few minutes\b"#, options: .regularExpression) != nil { total += 3; found = true }
        else if !found && t.range(of: #"\ba couple of minutes\b"#, options: .regularExpression) != nil { total += 2; found = true }
        guard found else { return nil }
        return max(1, min(Int(total.rounded(.up)), 480))
    }

    private static func numberValue(whole: String?, fracN: String?, fracD: String?, loneN: String?, loneD: String?, word: String?) -> Double? {
        if let w = whole, let v = Double(w.replacingOccurrences(of: ",", with: ".")) {
            var value = v
            if let n = fracN, let d = fracD, let nn = Double(n), let dd = Double(d), dd > 0 { value += nn / dd }
            return value
        }
        if let n = loneN, let d = loneD, let nn = Double(n), let dd = Double(d), dd > 0 { return nn / dd }
        switch word {
        case "one", "an", "a": return 1
        case "two": return 2
        case "three": return 3
        case "four": return 4
        case "five": return 5
        case "six": return 6
        case "seven": return 7
        case "eight": return 8
        case "nine": return 9
        case "ten": return 10
        case "twelve": return 12
        case "fifteen": return 15
        case "twenty": return 20
        case "thirty": return 30
        case "forty": return 40
        case "forty-five": return 45
        case "sixty": return 60
        case "ninety": return 90
        case "half an", "a half": return 0.5
        case "one and a half", "one-and-a-half": return 1.5
        default: return nil
        }
    }

    /// Hands-off when the cook can walk away: oven, fridge, freezer, resting,
    /// simmering, marinating. Anything that must be stirred or watched
    /// constantly stays hands-on, as does anything under 3 minutes.
    static func isHandsOff(_ text: String, minutes: Int?) -> Bool {
        if let m = minutes, m < 3 { return false }
        let l = text.lowercased()
        let passive = #"\b(bake|baking|roast|roasting|simmer|simmering|freeze|freezing|chill|chilling|refrigerate|refrigerating|rest|resting|let (?:it |them |the \w+ )?(?:stand|sit|rest|cool|rise|steep|soak)|cool (?:completely|slightly|to room)|cool,? (?:about|for)|marinate|marinating|rise|proof|prove|proving|soak|soaking|steep|braise|braising|slow[- ]cook|preheat|until (?:set|firm|solid|frozen|doubled)|in the oven|in the fridge|in the freezer|overnight|boil (?:the )?(?:potatoes|pasta|eggs|rice)|cook,? covered|covered,? (?:for|until))\b"#
        let active = #"\b(stir(?:ring)? (?:constantly|continuously|frequently)|whisk(?:ing)? (?:constantly|continuously)|constantly|continuously)\b"#
        guard l.range(of: passive, options: .regularExpression) != nil else { return false }
        return l.range(of: active, options: .regularExpression) == nil
    }

    /// A title cut at a word boundary, for dish labels on step cards.
    static func shortLabel(_ s: String, max: Int) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let cut = t.index(t.startIndex, offsetBy: max - 1)
        if let space = t[..<cut].lastIndex(of: " "), t.distance(from: t.startIndex, to: space) >= max / 2 {
            return String(t[..<space]) + "…"
        }
        return String(t[..<cut]) + "…"
    }

    /// First clause of a direction, trimmed to fit a step card.
    static func stepTitle(from sentence: String) -> String {
        var s = stripStepPrefix(sentence)
        if let r = s.range(of: #"[.;:!]\s"#, options: .regularExpression) { s = String(s[..<r.lowerBound]) }
        if let r = s.range(of: #",\s(?:about|until|stirring|then|and cook|and bake|for)\b"#, options: [.regularExpression, .caseInsensitive]) { s = String(s[..<r.lowerBound]) }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        if s.count > 64 {
            let cut = s.index(s.startIndex, offsetBy: 61)
            if let space = s[..<cut].lastIndex(of: " ") { s = String(s[..<space]) + "…" } else { s = String(s[..<cut]) + "…" }
        }
        if let f = s.first { s = String(f).uppercased() + s.dropFirst() }
        return s.isEmpty ? "Step" : s
    }

    // MARK: - Build the Recipe (timing attached)

    static func build(_ imported: ImportedRecipe, method: ImportMethod, id: UUID = UUID(), now: Date = Date()) -> Recipe {
        let short = String(id.uuidString.prefix(8)).lowercased()
        var dishes: [[CookingStep]] = []
        var current: [CookingStep] = []
        var meanwhile: [CookingStep] = []
        var inMeanwhile = false
        var joinAt: Int?
        var rejoins = false
        var n = 0
        let directions = imported.directions
        let dishLabel = shortLabel(imported.title, max: 32)

        for raw in directions {
            n += 1
            let stated = minutes(in: raw)
            let handsOff = isHandsOff(raw, minutes: stated)
            let guess = handsOff ? (raw.lowercased().contains("preheat") ? 15 : 20) : 5
            let step = CookingStep(
                id: "r\(short)-\(n)", dish: dishLabel,
                title: stepTitle(from: raw), minutes: stated ?? guess, detail: stripStepPrefix(raw),
                handsOn: !handsOff, estimated: stated == nil)
            let startsMeanwhile = raw.range(of: #"^\s*(?:meanwhile|while (?:the|that|it|this)\b|at the same time|in the meantime)"#,
                                            options: [.regularExpression, .caseInsensitive]) != nil
            if startsMeanwhile { inMeanwhile = true }
            else if inMeanwhile, raw.range(of: #"^\s*(?:when|once|after|return|add the \w+ to|combine|serve|drain|toss|plate|divide|top|spoon|pour|transfer|stir (?:in|together))\b"#,
                                           options: [.regularExpression, .caseInsensitive]) != nil { inMeanwhile = false }
            if inMeanwhile {
                meanwhile.append(CookingStep(id: step.id, dish: dishLabel + " — meanwhile", title: step.title,
                                             minutes: step.minutes, detail: step.detail, handsOn: step.handsOn, estimated: step.estimated))
            } else {
                if !meanwhile.isEmpty {
                    if joinAt == nil { joinAt = current.count }
                    if raw.range(of: rejoinPattern, options: [.regularExpression, .caseInsensitive]) != nil { rejoins = true }
                }
                current.append(step)
            }
        }
        // The engine has no cross-dish prerequisites. A meanwhile section that a
        // later step combines back in ("toss the pasta with the sauce") would be
        // planned to finish at dinner time, after the step that needs it. So it
        // only becomes a parallel dish when nothing combines it back; otherwise
        // it is cooked in order. Slower, never wrong (A2 R5 finding).
        if rejoins, let at = joinAt {
            current.insert(contentsOf: meanwhile.map {
                CookingStep(id: $0.id, dish: dishLabel, title: $0.title, minutes: $0.minutes,
                            detail: $0.detail, handsOn: $0.handsOn, estimated: $0.estimated)
            }, at: at)
            meanwhile = []
        }
        if !current.isEmpty { dishes.append(current) }
        if !meanwhile.isEmpty { dishes.append(meanwhile) }
        dishes = scaleEstimates(dishes, toTotal: imported.totalMinutes)

        var recipe = Recipe(id: id, title: imported.title)
        recipe.source = imported.source
        recipe.yield = imported.yield
        recipe.totalMinutes = imported.totalMinutes
        recipe.ingredients = imported.ingredients
        recipe.notes = imported.notes.isEmpty ? nil : imported.notes.joined(separator: "\n\n")
        recipe.directions = directions
        recipe.dishes = dishes
        recipe.importedAt = now
        recipe.importMethod = method
        recipe.needsTimingReview = true
        recipe.importWarnings = imported.warnings.isEmpty ? nil : imported.warnings
        return recipe
    }

    /// Steps that put a meanwhile component back into the main dish.
    static let rejoinPattern = #"^\s*(?:combine|toss|return|add the [\w\s]{1,30}? to|stir (?:in|together|the \w+ into)|pour (?:the \w+ )?over|spoon (?:the \w+ )?over|top (?:the|with)|fold in|transfer the \w+ to the)\b|\b(?:toss|combine)\b.*\b(?:with|together)\b"#

    /// When the recipe states a total time and the guessed steps leave the
    /// plan short of it, grow the guesses (never the stated times) to meet it.
    static func scaleEstimates(_ dishes: [[CookingStep]], toTotal total: Int?) -> [[CookingStep]] {
        guard let total = total, total > 0, let main = dishes.first else { return dishes }
        let stated = main.filter { $0.estimated != true }.reduce(0) { $0 + $1.minutes }
        let guessed = main.filter { $0.estimated == true }
        let guessedSum = guessed.reduce(0) { $0 + $1.minutes }
        guard !guessed.isEmpty, stated + guessedSum < total else { return dishes }
        let factor = Double(total - stated) / Double(guessedSum)
        var out = dishes
        out[0] = main.map { step in
            guard step.estimated == true else { return step }
            let scaled = max(1, min(240, Int((Double(step.minutes) * factor).rounded())))
            return CookingStep(id: step.id, dish: step.dish, title: step.title, minutes: scaled,
                               detail: step.detail, handsOn: step.handsOn, estimated: true)
        }
        return out
    }

    // MARK: - JSON-LD value helpers

    static func text(_ any: Any?) -> String? {
        guard let any = any else { return nil }
        if let s = any as? String { let c = cleanLine(s); return c.isEmpty ? nil : c }
        if let n = any as? NSNumber { return n.stringValue }
        if let dict = any as? [String: Any] { return text(dict["name"] ?? dict["text"] ?? dict["@value"]) }
        if let array = any as? [Any] { return array.compactMap { text($0) }.first }
        return nil
    }

    static func stringList(_ any: Any?) -> [String] {
        guard let any = any else { return [] }
        if let s = any as? String { return s.components(separatedBy: .newlines) }
        if let array = any as? [Any] { return array.compactMap { text($0) } }
        if let dict = any as? [String: Any] { return stringList(dict["itemListElement"]) }
        return []
    }

    static func imageURL(_ any: Any?) -> URL? {
        guard let any = any else { return nil }
        if let s = any as? String { return URL(string: s) }
        if let dict = any as? [String: Any] { return imageURL(dict["url"] ?? dict["contentUrl"]) }
        if let array = any as? [Any] { return array.compactMap { imageURL($0) }.first }
        return nil
    }

    static func yieldText(_ any: Any?) -> String? {
        guard let any = any else { return nil }
        if let n = any as? NSNumber { return n.stringValue }
        if let array = any as? [Any] {
            // Sites give ["4", "4 servings"]; keep the most descriptive.
            return array.compactMap { text($0) }.max(by: { $0.count < $1.count })
        }
        return text(any)
    }

    /// ISO-8601 durations ("PT1H30M", "P0DT0H25M", "PT90M"), or plain
    /// English ("1 hr 30 min") as a fallback. Whole minutes.
    static func duration(_ any: Any?) -> Int? {
        guard let s = text(any) else { return nil }
        let upper = s.uppercased().replacingOccurrences(of: " ", with: "")
        if upper.hasPrefix("P"),
           let regex = try? NSRegularExpression(pattern: #"^P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$"#) {
            let ns = NSString(string: upper)
            if let m = regex.firstMatch(in: upper, options: [], range: NSRange(location: 0, length: ns.length)) {
                func g(_ i: Int) -> Double { let r = m.range(at: i); return r.location == NSNotFound ? 0 : (Double(ns.substring(with: r)) ?? 0) }
                let minutes = g(1) * 1440 + g(2) * 60 + g(3) + g(4) / 60
                return minutes > 0 ? Int(minutes.rounded(.up)) : nil
            }
        }
        return minutes(in: s)
    }

    static func publisherName(from url: URL?) -> String? {
        guard var host = url?.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let known: [String: String] = [
            "eatingwell.com": "EatingWell", "allrecipes.com": "Allrecipes", "foodandwine.com": "Food & Wine",
            "seriouseats.com": "Serious Eats", "cooking.nytimes.com": "NYT Cooking", "bonappetit.com": "Bon Appétit",
            "epicurious.com": "Epicurious", "bbcgoodfood.com": "BBC Good Food", "food52.com": "Food52",
            "simplyrecipes.com": "Simply Recipes", "thekitchn.com": "The Kitchn", "foodnetwork.com": "Food Network",
            "smittenkitchen.com": "Smitten Kitchen", "budgetbytes.com": "Budget Bytes", "delish.com": "Delish",
            "tasty.co": "Tasty", "marthastewart.com": "Martha Stewart", "southernliving.com": "Southern Living",
            "myrecipes.com": "MyRecipes", "halfbakedharvest.com": "Half Baked Harvest",
        ]
        if let name = known[host] { return name }
        let base = host.components(separatedBy: ".").dropLast().last ?? host
        return base.isEmpty ? host : base.prefix(1).uppercased() + base.dropFirst()
    }

    // MARK: - Text helpers

    static func cleanLine(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        t = decodeEntities(t)
        t = t.replacingOccurrences(of: "\u{00A0}", with: " ")
        t = t.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ s: String) -> String {
        var t = s
        let named: [String: String] = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'",
                                       "&nbsp;": " ", "&deg;": "°", "&frac12;": "½", "&frac14;": "¼", "&frac34;": "¾",
                                       "&ndash;": "–", "&mdash;": "—", "&rsquo;": "’", "&lsquo;": "‘", "&rdquo;": "”", "&ldquo;": "“", "&hellip;": "…"]
        for (k, v) in named { t = t.replacingOccurrences(of: k, with: v) }
        for m in allMatches(#"&#(\d+);"#, in: t, group: 0) {
            if let code = Int(m.dropFirst(2).dropLast()), let scalar = Unicode.Scalar(code) {
                t = t.replacingOccurrences(of: m, with: String(Character(scalar)))
            }
        }
        for m in allMatches(#"&#[xX]([0-9a-fA-F]+);"#, in: t, group: 0) {
            if let code = Int(m.dropFirst(3).dropLast(), radix: 16), let scalar = Unicode.Scalar(code) {
                t = t.replacingOccurrences(of: m, with: String(Character(scalar)))
            }
        }
        return t
    }

    static func firstMatch(_ pattern: String, in s: String, group: Int, caseInsensitive: Bool = false) -> String? {
        allMatches(pattern, in: s, group: group, caseInsensitive: caseInsensitive).first
    }

    static func allMatches(_ pattern: String, in s: String, group: Int, caseInsensitive: Bool = false) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else { return [] }
        let ns = NSString(string: s)
        return regex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let r = m.range(at: group)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }
}

// MARK: - Screenshots (text recognized on the device)

/// One line of text recognized in a screenshot or photo. Coordinates are
/// fractions of the image: 0 is the top/left edge, 1 the bottom/right.
struct OCRLine: Equatable {
    var text: String
    var top: Double
    var left: Double = 0.06
    var height: Double = 0.015
    /// Set by `markUnreliable`: the line mixes writing systems on a page that
    /// is otherwise one script — text read through a blur, not real words.
    var unreliable = false
    var bottom: Double { top + height }
}

extension RecipeImporter {

    /// Builds a recipe from screenshots of a recipe page — Apple News+ Food,
    /// a cookbook app, a website. Directions labeled "STEP n" are keyed by
    /// number and survive any selection order; unnumbered directions are kept
    /// in screenshot-selection order and overlapping unnumbered text is not
    /// deduplicated. Callers must ask for images in recipe order and for a
    /// post-import check of missing or repeated text.
    ///
    /// - The title is the heading repeated at the top of several screenshots
    ///   (a navigation bar), or else the tallest text.
    /// - "STEP n" labels key the directions, so a step cut across two
    ///   screenshots is stitched back together and duplicates collapse.
    /// - Ingredient lines are grouped by spacing: a wrapped line joins the
    ///   ingredient above it; a gap starts a new one.
    /// - App chrome (status bar, tabs, buttons) is dropped.
    static func parse(screenshots pages: [[OCRLine]]) throws -> ImportedRecipe {
        let cleaned = markUnreliable(pages.map { dropStatusBar(readingOrder($0.map(cleanOCR).filter { !$0.text.isEmpty })) })
        guard cleaned.contains(where: { !$0.isEmpty }) else { throw RecipeImportError.noTextInScreenshots }

        let title = screenshotTitle(cleaned)
        let titleKey = title.map(normalizedKey) ?? ""
        var recipe = ImportedRecipe(title: title ?? "Untitled recipe")

        var ingredients: [String] = []
        var stepHeads: [Int: [String]] = [:]
        var stepTails: [Int: [String]] = [:]
        /// Unnumbered directions, each anchored to the numbered step most
        /// recently seen (in selection order) when it was read — nil before
        /// any. Mixed imports keep their visible order instead of pushing every
        /// unnumbered direction after every numbered one (A2-10 finding).
        var looseSteps: [(after: Int?, text: String)] = []
        var lastStepSeen: Int?
        var unreadableLines = 0

        /// The recipe's own title, wherever the page repeats it: the
        /// navigation bar, Cook mode's subtitle under "Step n", the cover's
        /// "Read the Story" card.
        func isTitleLine(_ line: OCRLine) -> Bool {
            let k = normalizedKey(line.text)
            return k.count >= 4 && !titleKey.isEmpty && titleKey.contains(k)
        }
        /// The title itself (or its first line when it wraps), never a word of it.
        func isWholeTitle(_ line: OCRLine) -> Bool {
            let k = normalizedKey(line.text)
            return !titleKey.isEmpty && (k == titleKey || (titleKey.hasPrefix(k) && k.split(separator: " ").count >= 2))
        }

        for page in cleaned {
            let tabRow = tabBarRow(page)
            let chromeRows = chromeRowIndices(page)
            let firstMarker = page.compactMap { stepNumber($0.text) }.first
            let hasHeader = page.contains { isIngredientsHeader($0.text) || isDirectionsHeader($0.text) }
            // A recipe's summary page — title, the app's own buttons and the
            // time/yield labels or a byline, no section or step — supplies
            // metadata only. Its other text (a story teaser, "Saved", the row
            // of tabs bleeding through the glass) is not a direction (Joe,
            // build 10: "Saved" and a garbled teaser arrived as steps 1 and
            // 2; build 11: a Southern Living cover with no time or yield
            // labels put the title twice and the teaser into the steps).
            let buttonHits = Set(page.map { normalizedKey($0.text) }.filter { coverButtons.contains($0) })
            let hasMetadata = page.contains { metadataLabels.contains(normalizedKey($0.text)) }
            let hasByline = page.contains { firstMatch(#"^(.{2,40}?)\s+[•·∙●–]\s+(.{2,60})$"#, in: $0.text, group: 0) != nil }
            let isCover = firstMarker == nil && !hasHeader && !buttonHits.isEmpty
                && (hasMetadata || hasByline || buttonHits.count >= 2)
            enum Mode { case unknown, ingredients, directions, step(Int) }
            var mode = Mode.unknown
            var preMarker: [String] = []
            var preMarkerUnreliable = false
            var looseBlock: [String] = []
            var previous: OCRLine?
            var takenValues = Set<Int>()
            var i = 0

            func flushLoose() {
                if !looseBlock.isEmpty { looseSteps.append((after: lastStepSeen, text: joinLines(looseBlock))); looseBlock = [] }
            }

            while i < page.count {
                let line = page[i]
                defer { previous = line; i += 1 }
                let text = line.text
                if takenValues.contains(i) { continue }
                if line.unreliable {
                    // Never schedule text read through a blur. A step's tail
                    // with such a line is dropped whole: the step keeps what
                    // was read cleanly and its time stays an honest estimate.
                    // The cook is told (A1, build 11: a silent drop could
                    // have hidden a whole short step).
                    unreadableLines += 1
                    if case .unknown = mode, firstMarker != nil { preMarkerUnreliable = true }
                    continue
                }
                let key = normalizedKey(text)
                if let row = tabRow, abs(line.top - row) < 0.012 { continue }
                if chromeRows.contains(i) { continue }
                if isChrome(key) { continue }
                if isTitleLine(line) {
                    // Inside the directions only the whole title is a repeat:
                    // "Roast." under "Roast Chicken" is a step (A1, PR #16).
                    switch mode {
                    case .step, .directions: if key == titleKey { continue }
                    default: continue
                    }
                }
                // Cook mode's navigation header: a small "Step n" with the
                // recipe title under it, above the real "STEP n". Not a step
                // boundary — as one, it collected the title as a copy of the
                // step, and the longer copy beat "Set aside." (Joe, build 11).
                if stepNumber(text) != nil, i + 1 < page.count, isWholeTitle(page[i + 1]) { continue }

                // Metadata, inline ("Yield: 2") or as label/value rows.
                if let v = firstMatch(#"^(?:total time|total)\s*[:：]\s*(.+)$"#, in: text, group: 1, caseInsensitive: true) {
                    recipe.totalMinutes = recipe.totalMinutes ?? minutes(in: v); continue
                }
                if let v = firstMatch(#"^(?:yield|serves|servings|makes)\s*[:：]?\s*(.+)$"#, in: text, group: 1, caseInsensitive: true),
                   !["yield", "serves", "servings", "makes"].contains(key) {
                    assignMetadata("yield", cleanLine(v), to: &recipe); continue
                }
                if metadataLabels.contains(key) {
                    // Each label takes the value under it in its own column (or
                    // beside it on its row), by position, not reading order:
                    // "Yield" read a hair higher than "Total Time" came first,
                    // and the time landed under Yield (Joe, build 11).
                    if let j = metadataValue(for: i, in: page, taken: takenValues) {
                        takenValues.insert(j)
                        assignMetadata(key, page[j].text, to: &recipe)
                    }
                    continue
                }
                if case .unknown = mode,
                   firstMatch(#"^(.{2,40}?)\s+[•·∙●–]\s+(.{2,60})$"#, in: text, group: 0) != nil,
                   recipe.source.publisher == nil {
                    let parts = text.components(separatedBy: CharacterSet(charactersIn: "•·∙●–")).map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 { recipe.source.publisher = parts[0]; recipe.source.author = parts[1]; continue }
                }

                if isIngredientsHeader(text) { flushLoose(); mode = .ingredients; continue }
                if isDirectionsHeader(text) { flushLoose(); mode = .directions; continue }
                if let n = stepNumber(text) { flushLoose(); mode = .step(n); lastStepSeen = n; stepHeads[n, default: []].append(""); continue }

                switch mode {
                case .unknown:
                    if firstMarker != nil { preMarker.append(text) }
                    else if !hasHeader && !isCover {
                        // A bare screenshot (cookbook page, scrolled list): sort by shape.
                        if looksLikeIngredient(text) && !looksLikeInstruction(text) { ingredients.append(stripStepPrefix(text)) }
                        else {
                            if startsParagraph(text, line, previous, blockIsEmpty: looseBlock.isEmpty) { flushLoose() }
                            looseBlock.append(text)
                        }
                    }
                case .ingredients:
                    let gap = previous.map { line.top - $0.bottom } ?? 1
                    let startsNew = gap > line.height * 1.0 || startsWithQuantity(text) || ingredients.isEmpty
                    if startsNew || previousWasHeader(previous) { ingredients.append(stripStepPrefix(text)) }
                    else { ingredients[ingredients.count - 1] = joinLines([ingredients[ingredients.count - 1], text]) }
                case .directions:
                    if startsParagraph(text, line, previous, blockIsEmpty: looseBlock.isEmpty) { flushLoose() }
                    looseBlock.append(text)
                case .step(let n):
                    var heads = stepHeads[n] ?? [""]
                    heads[heads.count - 1] = joinLines([heads[heads.count - 1], text])
                    stepHeads[n] = heads
                }
            }
            flushLoose()
            if let m = firstMarker, m > 1, !preMarker.isEmpty, !preMarkerUnreliable {
                stepTails[m - 1, default: []].append(joinLines(preMarker))
            }
        }

        // Ingredients: drop fragments, collapse duplicates across screenshots.
        var merged: [String] = []
        for item in ingredients.map(cleanLine) where item.filter({ $0.isLetter }).count >= 3 {
            let k = normalizedKey(item)
            if let idx = merged.firstIndex(where: { normalizedKey($0).hasPrefix(k) }) { _ = idx; continue }
            if let idx = merged.firstIndex(where: { k.hasPrefix(normalizedKey($0)) }) { merged[idx] = item; continue }
            merged.append(item)
        }
        recipe.ingredients = merged

        // Directions: the longest copy of each numbered step, plus any tail
        // that a later screenshot showed and the longest copy lacks.
        // Keep text keyed by its number: a heading with no recognized text
        // must not shift later text to a different number or lose its anchor.
        var numberedText: [Int: String] = [:]
        for n in Set(stepHeads.keys).union(stepTails.keys).sorted() {
            var text = (stepHeads[n] ?? []).max(by: { $0.count < $1.count }) ?? ""
            for tail in stepTails[n] ?? [] where !normalizedKey(text).contains(normalizedKey(tail)) {
                text = mergeOverlapping(text, tail)
            }
            text = cleanLine(text)
            if !text.isEmpty { numberedText[n] = text }
        }
        // A step's last lines can be the next step's first lines when its
        // "STEP n" label was hidden under a floating button (Joe, build 10:
        // step 1 ended with "Pour the cider mixture evenly into 12 ice",
        // which is how step 2 begins). The later step keeps the text.
        let numbered = Set(stepHeads.keys).union(stepTails.keys).sorted()
        for (a, b) in zip(numbered, numbered.dropFirst()) {
            if let prev = numberedText[a], let next = numberedText[b] {
                let trimmed = trimOverlap(prev, next: next)
                numberedText[a] = trimmed.isEmpty ? nil : trimmed
            }
        }
        // Weave the unnumbered directions back in where they were seen.
        var woven: [String] = []
        func loose(after n: Int?) -> [String] {
            looseSteps.filter { $0.after == n }.map { stripStepPrefix($0.text) }.filter { !$0.isEmpty }
        }
        woven.append(contentsOf: loose(after: nil))
        for n in numbered {
            if let text = numberedText[n] { woven.append(text) }
            // An empty heading still has a position in the recipe: directions
            // seen after it must stay here, before the next numbered step.
            woven.append(contentsOf: loose(after: n))
        }
        // Anchored to a step number that never got a heading (unlikely): keep them, at the end.
        woven.append(contentsOf: looseSteps.filter { a in a.after != nil && !numbered.contains(a.after!) }.map { stripStepPrefix($0.text) }.filter { !$0.isEmpty })
        let steps = woven
        if !steps.isEmpty { recipe.sections = [ImportedSection(name: nil, steps: steps)] }

        // What the screenshots did not establish (A2 S2: a gap is told, never
        // closed by renumbering; A1: dropped text is told, never silent).
        if unreadableLines > 0 {
            recipe.warnings.append(unreadableLines == 1
                ? "One line couldn’t be read clearly and was left out."
                : "\(unreadableLines) lines couldn’t be read clearly and were left out.")
        }
        if let first = numbered.first, let last = numbered.last {
            var missing = numbered.filter { numberedText[$0] == nil }
            missing.append(contentsOf: (first...last).filter { !numbered.contains($0) })
            if first > 1 { missing.append(contentsOf: 1..<first) }
            let gaps = Set(missing).sorted()
            if !gaps.isEmpty {
                let list = gaps.map(String.init).joined(separator: ", ")
                recipe.warnings.append(gaps.count == 1
                    ? "Source step \(list) wasn’t found in the screenshots."
                    : "Source steps \(list) weren’t found in the screenshots.")
            }
            if let text = numberedText[last], text.range(of: #"[.!?)”"]$"#, options: .regularExpression) == nil {
                recipe.warnings.append("The last step may be cut off — check it against your recipe.")
            }
        }

        guard !recipe.ingredients.isEmpty || !recipe.sections.isEmpty else { throw RecipeImportError.noTextInScreenshots }
        return recipe
    }

    // MARK: Screenshot helpers

    /// Greek and Cyrillic letters look like Latin ones; a recognizer reading a
    /// blurred English line can mix them in ("about плоагу. ou am апа").
    static func scriptCounts(_ s: String) -> (latin: Int, confusable: Int) {
        var latin = 0, other = 0
        for u in s.unicodeScalars where CharacterSet.letters.contains(u) {
            switch u.value {
            case 0x0041...0x024F: latin += 1
            case 0x0370...0x03FF, 0x0400...0x052F: other += 1
            default: break
            }
        }
        return (latin, other)
    }

    /// On screenshots that are overwhelmingly Latin script, a line containing
    /// Greek or Cyrillic letters is unreliable (and vice versa).
    static func markUnreliable(_ pages: [[OCRLine]]) -> [[OCRLine]] {
        let totals = pages.joined().reduce((latin: 0, confusable: 0)) { acc, line in
            let c = scriptCounts(line.text); return (acc.latin + c.latin, acc.confusable + c.confusable)
        }
        let all = totals.latin + totals.confusable
        guard all > 0 else { return pages }
        let latinPage = Double(totals.latin) / Double(all) >= 0.85
        let otherPage = Double(totals.confusable) / Double(all) >= 0.85
        guard latinPage || otherPage else { return pages }
        return pages.map { page in
            page.map { line in
                let c = scriptCounts(line.text)
                var out = line
                out.unreliable = latinPage ? c.confusable > 0 : (c.latin > 0 && c.confusable > 0)
                return out
            }
        }
    }

    /// Removes recognition artifacts around Apple's inline timer chips
    /// ("about © 30 seconds ." → "about 30 seconds.").
    static func cleanOCR(_ line: OCRLine) -> OCRLine {
        var t = line.text
        t = t.replacingOccurrences(of: #"[©®⏱◷⌚⏲]"#, with: " ", options: .regularExpression)
        // A timer chip's icon read as a bullet: "about • 30 seconds" (Joe's
        // device, build 8). Only before a number, so "EatingWell • Julia Levy"
        // keeps its separator.
        t = t.replacingOccurrences(of: #"[•◦∙●○]\s*(?=\d)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\(\s*(\d[^()]{0,24}?(?:seconds?|minutes?|mins?|hours?|hrs?))\s*\)"#, with: "$1", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"\s+([.,;:!?)])"#, with: "$1", options: .regularExpression)
        // A dropped space before a parenthesized size: "14(6-inch)" (Joe's
        // meringue import, 1.0 (17)) → "14 (6-inch)".
        t = t.replacingOccurrences(of: #"(\d)\((?=\d)"#, with: "$1 (", options: .regularExpression)
        var out = line
        out.text = cleanLine(t)
        return out
    }

    /// Top-to-bottom, and left-to-right within a row.
    static func readingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        let sorted = lines.sorted { $0.top < $1.top }
        var rows: [[OCRLine]] = []
        for line in sorted {
            if let last = rows.last?.first, abs(line.top - last.top) < max(0.004, min(line.height, last.height) * 0.5) {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.left < $1.left } }
    }

    static func normalizedKey(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: #"[^\p{L}\p{N}½¼¾⅓⅔⅛]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func stepNumber(_ text: String) -> Int? {
        firstMatch(#"^\s*step\s*(\d{1,2})\s*[:.]?\s*$"#, in: text, group: 1, caseInsensitive: true).flatMap { Int($0) }
    }

    static func startsWithQuantity(_ text: String) -> Bool {
        text.range(of: #"^\s*(?:[-•*·]\s*)?(?:\d|½|¼|¾|⅓|⅔|⅛)"#, options: .regularExpression) != nil
    }

    static let metadataLabels: Set<String> = ["total time", "yield", "servings", "serves", "prep time", "cook time"]
    /// The buttons a recipe app shows under its title.
    static let coverButtons: Set<String> = ["cook", "save", "saved", "share", "cook save share", "cook saved share",
                                            "read the story", "start cooking", "jump to recipe", "print"]
    /// Words a row of tabs is made of; a line of nothing else is a tab bar.
    static let tabWords: Set<String> = ["ingredients", "directions", "instructions", "method", "nutrition", "more", "notes",
                                        "reviews", "steps", "overview", "tips", "today", "news", "audio", "following", "search"]
    /// The News app's own tabs: two of them in one line means the line was
    /// read through the tab bar ("…colo Up Following Search retreshing…").
    static let newsTabs: Set<String> = ["today", "audio", "following", "search"]

    static func isChrome(_ key: String) -> Bool {
        if key.isEmpty { return true }
        if key.range(of: #"^\d{1,2} \d{2}$"#, options: .regularExpression) != nil { return true }   // 6:09
        if key.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil { return true }         // battery
        if key.count <= 2 && key.range(of: #"\d"#, options: .regularExpression) == nil { return true }
        let exact: Set<String> = ["nutrition", "more", "scale", "cook", "save", "saved", "share", "start cooking", "read the story",
                                  "customize units", "recipe units are from the publisher", "in reminders", "print",
                                  "jump to recipe", "cook save share", "cook saved share", "show more", "see more", "notes", "reviews",
                                  "mark as cooked", "done", "close"]
        if exact.contains(key) { return true }
        if key.contains("grocery list") || key.hasPrefix("add to grocery") { return true }
        let words = key.split(separator: " ").map(String.init)
        // "Ingredients Directions" read as one line; "Today News+ Audio Following Search".
        if words.count >= 2 && words.allSatisfy({ tabWords.contains($0) }) { return true }
        if words.filter({ newsTabs.contains($0) }).count >= 2 { return true }
        return false
    }

    /// The phone's status bar: a line near the top edge that holds a clock,
    /// and everything on its row. Recognized as one line it was
    /// "10:08 1 ••ll 5GW" — clock, location arrow, signal bars, network —
    /// and became the front of the title (Joe, build 12). The clock alone
    /// was already dropped as chrome; the row it sits on now goes with it.
    static func dropStatusBar(_ page: [OCRLine]) -> [OCRLine] {
        let clocks = page.filter { line in
            guard line.top < 0.05 else { return false }
            // One word is the clock ("10:08", "9:41"); the rest are status
            // items (signal, network, battery, a date on iPad), not a sentence.
            let words = line.text.split(whereSeparator: { $0 == " " }).map(String.init)
            guard let c = words.firstIndex(where: isClockWord) else { return false }
            let rest = words.enumerated().filter { $0.offset != c }.map(\.element)
                .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            return rest.count <= 5 && !rest.contains { $0.filter(\.isLetter).count >= 8 }
        }
        guard !clocks.isEmpty else { return page }
        return page.filter { line in
            !clocks.contains { c in abs(line.top - c.top) < max(0.012, c.height * 0.8) && line.top < 0.06 }
        }
    }

    /// "10:08", "9:41", "9.41", with at most two marks after it (a location
    /// arrow read as a glyph). Plain character checks, no pattern.
    static func isClockWord(_ word: String) -> Bool {
        var chars = Array(word)
        var trailing = 0
        while let last = chars.last, !last.isASCII || !last.isNumber { chars.removeLast(); trailing += 1 }
        guard trailing <= 2, let sep = chars.firstIndex(where: { $0 == ":" || $0 == "." }) else { return false }
        let hours = chars[..<sep], minutes = chars[(sep + 1)...]
        func digits<C: Collection>(_ c: C) -> Bool where C.Element == Character { c.allSatisfy { $0.isASCII && $0.isNumber } }
        return (1...2).contains(hours.count) && minutes.count == 2 && digits(hours) && digits(minutes)
    }

    /// The value for the metadata label at `index`: the nearest unclaimed
    /// line below it in its column, else the nearest to its right on its
    /// row. Never another label.
    static func metadataValue(for index: Int, in page: [OCRLine], taken: Set<Int>) -> Int? {
        let label = page[index]
        // Not `isChrome`: a yield of "2" looks like a battery level to it.
        func usable(_ k: Int) -> Bool {
            k != index && !taken.contains(k) && !metadataLabels.contains(normalizedKey(page[k].text))
                && !coverButtons.contains(normalizedKey(page[k].text)) && stepNumber(page[k].text) == nil
        }
        let below = page.indices.filter { k in
            usable(k) && page[k].top > label.top + label.height * 0.5 && page[k].top - label.bottom < 0.05
                && abs(page[k].left - label.left) < 0.15
        }
        if let k = below.min(by: { (page[$0].top, abs(page[$0].left - label.left)) < (page[$1].top, abs(page[$1].left - label.left)) }) {
            return k
        }
        let beside = page.indices.filter { k in
            usable(k) && abs(page[k].top - label.top) < max(0.012, label.height * 0.6) && page[k].left > label.left
        }
        return beside.min(by: { page[$0].left < page[$1].left })
    }

    /// A duration is never a yield: under "Yield" it is the recipe's time.
    static func assignMetadata(_ label: String, _ value: String, to recipe: inout ImportedRecipe) {
        let looksLikeTime = value.range(of: #"^\s*\d+(?:\s*[½¼¾⅓⅔])?\s*(?:hr|hrs|hour|hours|h|min|mins|minutes|m)\b"#,
                                        options: [.regularExpression, .caseInsensitive]) != nil
        switch label {
        case "total time", "total":
            recipe.totalMinutes = recipe.totalMinutes ?? minutes(in: value)
        case "yield", "servings", "serves", "makes":
            if looksLikeTime { recipe.totalMinutes = recipe.totalMinutes ?? minutes(in: value) }
            else { recipe.yield = recipe.yield ?? value }
        default: break
        }
    }

    /// Rows of two or more tab words recognized as separate lines: the News
    /// tab bar read as "Today", "News+", "Audio", "Following", "Search"
    /// (one line per tab) escapes `isChrome`, which sees one word at a time
    /// (A1, build 11). The whole row is chrome; a single word on its own
    /// row ("Search" in a sentence's line) is not.
    static func chromeRowIndices(_ page: [OCRLine]) -> Set<Int> {
        var out = Set<Int>()
        var i = 0
        while i < page.count {
            var j = i + 1
            while j < page.count, abs(page[j].top - page[i].top) < 0.012 { j += 1 }
            let row = Array(i..<j)
            let hits = row.filter { tabWords.contains(normalizedKey(page[$0].text)) }.count
            if row.count >= 2, hits >= 2 { out.formUnion(row) }
            i = j
        }
        return out
    }

    /// Removes from `prev` a suffix of three or more words that is also the
    /// start of `next`.
    static func trimOverlap(_ prev: String, next: String) -> String {
        let a = prev.split(separator: " ").map(String.init)
        let b = next.split(separator: " ").map(String.init)
        guard a.count > 3, b.count >= 3 else { return prev }
        for k in stride(from: min(a.count - 1, b.count), through: 3, by: -1)
        where a.suffix(k).map(normalizedKey) == b.prefix(k).map(normalizedKey) {
            return cleanLine(a.prefix(a.count - k).joined(separator: " "))
        }
        return prev
    }

    /// The row holding both "Ingredients" and "Directions" side by side is a
    /// tab bar, not a section header.
    static func tabBarRow(_ page: [OCRLine]) -> Double? {
        let ing = page.filter { normalizedKey($0.text) == "ingredients" }
        let dir = page.filter { normalizedKey($0.text) == "directions" || normalizedKey($0.text) == "instructions" || normalizedKey($0.text) == "method" }
        for a in ing { if dir.contains(where: { abs($0.top - a.top) < 0.012 }) { return a.top } }
        return nil
    }

    /// The heading repeated near the top of two or more screenshots wins —
    /// above the tab bar (the Recipes view's navigation bar) or just below
    /// it (Cook mode shows "Step n" and the recipe title under the tabs; the
    /// "Step n" line splits the run so it never joins the title). A single
    /// heading directly above a tab bar also counts. Otherwise the run of
    /// tallest text on a screenshot, if it has letters and is not the step
    /// under a "STEP n" label (Joe, build 11: "0001 -", read off the cover
    /// photo, was the tallest text and became the title).
    static func screenshotTitle(_ pages: [[OCRLine]]) -> String? {
        var counts: [String: (count: Int, text: String, aboveTabs: Bool)] = [:]
        for page in pages {
            let tab = tabBarRow(page)
            let chromeRows = chromeRowIndices(page)
            func chrome(_ i: Int) -> Bool {
                chromeRows.contains(i) || isChrome(normalizedKey(page[i].text)) || (tab.map { abs(page[i].top - $0) < 0.012 } ?? false)
            }
            func excluded(_ i: Int) -> Bool {
                chrome(i) || stepNumber(page[i].text) != nil || isIngredientsHeader(page[i].text) || isDirectionsHeader(page[i].text)
            }
            var runStart: Int?
            func close(at end: Int) {
                guard let start = runStart else { return }
                runStart = nil
                let lines = page[start..<end]
                let joined = joinLines(lines.map { $0.text })
                let k = normalizedKey(joined)
                guard k.count >= 4, joined.filter({ $0.isLetter }).count >= 3 else { return }
                // A heading directly under the tab bar with "STEP n" after it
                // is Cook mode's subtitle; a single one still names the
                // recipe. Only chrome and the small "Step n" label may sit
                // between the tabs and it, so an ingredient list's "Yield: 2"
                // under an Ingredients header never qualifies.
                var nearTabs = false
                let shortHeading = lines.count == 1 && k.split(separator: " ").count <= 8
                    && joined.rangeOfCharacter(from: CharacterSet(charactersIn: ".;:")) == nil
                if shortHeading, let t = tab, page[start].top > t, page[start].top - t < 0.10 {
                    var j = start - 1, clean = true
                    while j >= 0, page[j].top > t + 0.012 {
                        if !(chrome(j) || stepNumber(page[j].text) != nil) { clean = false; break }
                        j -= 1
                    }
                    var n = end
                    while n < page.count, chrome(n) { n += 1 }
                    nearTabs = clean && n < page.count && stepNumber(page[n].text) != nil
                }
                let above = tab.map { lines.last!.top < $0 } ?? false
                let seen = counts[k]
                let text = (seen?.text.count ?? 0) >= joined.count ? seen!.text : joined
                counts[k] = ((seen?.count ?? 0) + 1, text, (seen?.aboveTabs ?? false) || above || nearTabs)
            }
            for i in page.indices {
                if page[i].top >= 0.20 { close(at: i); break }
                if excluded(i) { close(at: i) } else if runStart == nil { runStart = i }
            }
            close(at: page.count)
        }
        if let best = counts.values.filter({ $0.count >= 2 || $0.aboveTabs })
            .max(by: { ($0.count, $0.text.count) < ($1.count, $1.text.count) }) { return best.text }

        for page in pages {
            let heights = page.map { $0.height }.sorted()
            guard heights.count >= 3 else { continue }
            let median = heights[heights.count / 2]
            var run: [String] = []
            var afterMarker = false
            for line in page {
                let k = normalizedKey(line.text)
                if stepNumber(line.text) != nil { afterMarker = true; if !run.isEmpty { break }; continue }
                let tall = line.height >= median * 1.35 && !isChrome(k) && !isIngredientsHeader(line.text) && !isDirectionsHeader(line.text)
                // Tall marks without letters are the photo, not words.
                if tall, !line.text.contains(where: { $0.isLetter }) { continue }
                if tall && !(afterMarker && run.isEmpty) {
                    run.append(line.text)
                } else if !run.isEmpty { break }
                if !tall { afterMarker = false }
            }
            let joined = joinLines(run)
            if joined.filter({ $0.isLetter }).count >= 3 { return joined }
        }
        return nil
    }

    /// A hyphen ending a line is a word broken by the wrap ("show-" +
    /// "stopper"), unless it follows a number: "½-" + "inch", "18-" +
    /// "inch" keep it (Joe, build 11: "½inch hole").
    static func joinLines(_ parts: [String]) -> String {
        var out = ""
        for p in parts.map({ $0.trimmingCharacters(in: .whitespaces) }) where !p.isEmpty {
            if out.isEmpty { out = p }
            else if out.hasSuffix("-") && !out.hasSuffix(" -") {
                let before = out.dropLast().last
                if let c = before, c.isNumber || "½¼¾⅓⅔⅛".contains(c) { out += p } else { out.removeLast(); out += p }
            }
            else { out += " " + p }
        }
        return out
    }

    /// Joins a head and a tail that may overlap ("…medium heat. Remove" +
    /// "Remove from heat…").
    static func mergeOverlapping(_ head: String, _ tail: String) -> String {
        let a = head.split(separator: " ").map(String.init)
        let b = tail.split(separator: " ").map(String.init)
        for k in stride(from: min(a.count, b.count), through: 2, by: -1) {
            if a.suffix(k).map(normalizedKey) == b.prefix(k).map(normalizedKey) {
                return joinLines([head, b.dropFirst(k).joined(separator: " ")])
            }
        }
        return joinLines([head, tail])
    }

    private static func previousWasHeader(_ previous: OCRLine?) -> Bool {
        guard let p = previous?.text else { return true }
        return isIngredientsHeader(p) || normalizedKey(p).hasPrefix("yield") || normalizedKey(p) == "scale"
    }

    private static func startsParagraph(_ text: String, _ line: OCRLine, _ previous: OCRLine?, blockIsEmpty: Bool) -> Bool {
        guard !blockIsEmpty else { return false }
        let gap = previous.map { line.top - $0.bottom } ?? 1
        let numbered = text.range(of: #"^\s*\d{1,2}\s*[.)]\s+"#, options: .regularExpression) != nil
        return gap > line.height * 1.0 || numbered
    }
}
