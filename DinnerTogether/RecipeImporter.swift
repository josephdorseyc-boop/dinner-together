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

    var directions: [String] { sections.flatMap { $0.steps } }
}

struct ImportedSection: Equatable {
    var name: String?
    var steps: [String]
}

enum RecipeImportError: Error, Equatable, LocalizedError {
    case noRecipeData
    case emptyText

    var errorDescription: String? {
        switch self {
        case .noRecipeData:
            return "This page doesn’t include recipe data the app can read. Copy the recipe text and paste it instead."
        case .emptyText:
            return "Paste the recipe’s ingredients and directions first."
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
        recipe.sections = instructionSections(dict["recipeInstructions"])
        guard !recipe.ingredients.isEmpty || !recipe.sections.isEmpty else { return nil }
        return recipe
    }

    private static func sum(_ a: Int?, _ b: Int?) -> Int? {
        if a == nil && b == nil { return nil }
        return (a ?? 0) + (b ?? 0)
    }

    private static func instructionSections(_ any: Any?) -> [ImportedSection] {
        guard let any = any else { return [] }
        if let s = any as? String {
            return [ImportedSection(name: nil, steps: splitSteps(from: s))]
        }
        if let dict = any as? [String: Any] {
            return instructionSections(dict["itemListElement"] ?? dict["text"])
        }
        guard let array = any as? [Any] else { return [] }
        var sections: [ImportedSection] = []
        var loose: [String] = []
        for item in array {
            if let s = item as? String {
                loose.append(contentsOf: splitSteps(from: s))
            } else if let dict = item as? [String: Any] {
                let types = typeNames(dict["@type"])
                if types.contains("howtosection") || dict["itemListElement"] != nil {
                    if !loose.isEmpty { sections.append(ImportedSection(name: nil, steps: loose)); loose = [] }
                    let inner = instructionSections(dict["itemListElement"]).flatMap { $0.steps }
                    sections.append(ImportedSection(name: text(dict["name"]), steps: inner))
                } else if let t = text(dict["text"]) ?? text(dict["name"]) {
                    loose.append(contentsOf: splitSteps(from: t))
                }
            }
        }
        if !loose.isEmpty { sections.append(ImportedSection(name: nil, steps: loose)) }
        return sections.filter { !$0.steps.isEmpty }
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
            case 2: steps.append(stripStepPrefix(line))
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
        let passive = #"\b(bake|baking|roast|roasting|simmer|simmering|freeze|freezing|chill|chilling|refrigerate|refrigerating|rest|resting|let (?:it |them |the \w+ )?(?:stand|sit|rest|cool|rise|steep|soak)|cool (?:completely|slightly|to room)|marinate|marinating|rise|proof|prove|proving|soak|soaking|steep|braise|braising|slow[- ]cook|preheat|until (?:set|firm|solid|frozen|doubled)|in the oven|in the fridge|in the freezer|overnight|boil (?:the )?(?:potatoes|pasta|eggs|rice)|cook,? covered|covered,? (?:for|until))\b"#
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
        recipe.directions = directions
        recipe.dishes = dishes
        recipe.importedAt = now
        recipe.importMethod = method
        recipe.needsTimingReview = true
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
