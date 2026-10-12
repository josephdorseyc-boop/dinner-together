import SwiftUI
import UIKit
import PhotosUI

// The Recipes destination, its collection, the
// Add-a-recipe sheet, and the recipe page (Ingredients · Directions · Timing).
// House style throughout: cream/paper surfaces, serif display type, tomato
// accents — the reference is Apple News+ Food's layout, not its look.

// MARK: - Recipes destination

struct RecipesView: View {
    @EnvironmentObject private var store: SessionStore
    @Binding var path: [UUID]
    var goTonight: () -> Void
    var goCooking: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your kitchen, collected.")
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text("Your favorites, ready for dinner.")
                        .foregroundStyle(Theme.muted)
                }
                if store.session.records.values.contains(where: { $0.state != .notStarted }) {
                    Button(action: goCooking) {
                        Label("Back to cooking", systemImage: "timer")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                YourRecipesSection(onOpenRecipe: { path.append($0) }, onChoose: goTonight)
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.recipeBackground)
        .foregroundStyle(Theme.ink)
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("recipe-library")
    }
}

// MARK: - Your recipes

struct YourRecipesSection: View {
    var onOpenRecipe: (UUID) -> Void
    var onChoose: () -> Void
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore
    @State private var adding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "YOUR RECIPES")
                Spacer()
                Button { adding = true } label: {
                    Label("Add a recipe", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("add-recipe")
            }
            if library.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cook your own recipes, on time.")
                        .font(.headline)
                    Text("Add a recipe link, screenshots, or text. Check the imported steps and timing before cooking.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dtCard()
            } else {
                ForEach(library.recipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        RecipeRow(recipe: recipe, selected: store.session.menuID == recipe.menuID)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            RecipeDetailView(recipeID: id, onChoose: onChoose)
        }
        .sheet(isPresented: $adding) {
            AddRecipeSheet { id in onOpenRecipe(id) }
        }
    }
}

struct RecipeRow: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    let selected: Bool

    var body: some View {
        HStack(spacing: 14) {
            RecipeThumbnail(recipe: recipe, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                if let byline = recipe.source.byline {
                    Text(byline).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                if recipe.needsTimingReview {
                    Label("Check the timing", systemImage: "clock.badge.questionmark")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.warning)
                } else {
                    Text(RecipeFormat.duration(recipe.plannedMinutes)).font(.caption).foregroundStyle(Theme.olive)
                }
            }
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.tomato).font(.title3)
                    .accessibilityLabel("Tonight’s dinner")
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(selected ? Theme.tomato.opacity(0.65) : .clear, lineWidth: 1.25))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RecipeThumbnail: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    let size: CGFloat

    var body: some View {
        Group {
            if let url = library.imageURL(for: recipe), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "book.closed").font(.title3.weight(.medium)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.cream)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum RecipeFormat {
    static func duration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "Timing not set" }
        if minutes < 60 { return "About \(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "About \(h) hr" : "About \(h) hr \(m) min"
    }

    static func compact(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    /// Downscales a downloaded or picked photo before it is stored, so the
    /// library never keeps a 6 MB hero image for a 390-point-wide screen.
    static func storableJPEG(_ data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

// MARK: - Add a recipe

struct AddRecipeSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case link = "Link", screenshots = "Screenshots", text = "Text"
        var id: String { rawValue }
    }

    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    var onAdded: (UUID) -> Void

    @State private var mode: Mode = .link
    @State private var link = ""
    @State private var text = ""
    @State private var working = false
    @State private var error: String?
    @State private var picked: [PhotosPickerItem] = []
    @State private var choosingCover = false
    @State private var coverData: Data?
    @State private var pendingCoverSave: PendingCoverSave?

    private struct PendingCoverSave {
        let recipe: Recipe
        let data: Data
    }

    private let service = LaunchOptions.importService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a recipe")
                            .font(.system(.largeTitle, design: .serif).weight(.medium))
                        Text("Paste a recipe link, choose screenshots, or paste the text. Your saved recipe stays on this device.")
                            .foregroundStyle(Theme.muted)
                    }
                    Picker("Source", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(working || pendingCoverSave != nil)

                    Group {
                        switch mode {
                        case .link: linkInput
                        case .screenshots: screenshotInput
                        case .text: textInput
                        }
                    }
                    .disabled(working || pendingCoverSave != nil)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("import-error")
                    }

                    Button(action: runImport) {
                        if working {
                            HStack(spacing: 10) { ProgressView().tint(.white); Text("Reading the recipe…") }
                        } else {
                            Label(pendingCoverSave == nil ? "Add recipe" : "Retry cover save", systemImage: "arrow.down.doc")
                        }
                    }
                    .buttonStyle(BigButtonStyle())
                    .disabled(working || (pendingCoverSave == nil && !canImport))
                    .accessibilityIdentifier("import-recipe")
                    if let pendingCoverSave {
                        Button("Continue without cover") { finishImport(pendingCoverSave.recipe) }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("continue-without-cover")
                    }

                    Text(mode == .link
                         ? "Link import needs internet access. Review the imported recipe and any estimated times before cooking."
                         : "Check the imported recipe for missing or repeated text, and review any estimated times before cooking.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(24)
            }
            .background(Theme.cream)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(pendingCoverSave == nil ? "Cancel" : "Done") {
                        if let pending = pendingCoverSave { finishImport(pending.recipe) }
                        else { dismiss() }
                    }.disabled(working)
                }
            }
        }
        .tint(Theme.tomato)
        .interactiveDismissDisabled(working)
        .onChange(of: picked) { _, _ in coverData = nil }
        .sheet(isPresented: $choosingCover) {
            ScreenshotCoverSheet(items: picked) { coverData = $0 }
        }
    }

    private var canImport: Bool {
        switch mode {
        case .link: return parsedLink != nil
        case .screenshots: return !picked.isEmpty
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var screenshotInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("For Apple News+ Food, cookbook apps, or recipe cards. Include the title, ingredients and every step. Choose images in recipe order, then check for missing or repeated text after import.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            PhotosPicker(selection: $picked, maxSelectionCount: 12, selectionBehavior: .ordered, matching: .images) {
                Label(picked.isEmpty ? "Choose screenshots" : "\(picked.count) chosen — change", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("choose-screenshots")
            if !picked.isEmpty {
                Button(coverData == nil ? "Choose a cover from screenshots" : "Adjust cover crop") {
                    choosingCover = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("choose-cover")
            }
            if let coverData, let image = UIImage(data: coverData) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Selected recipe cover")
                Button("Remove cover") { self.coverData = nil }
                    .buttonStyle(QuietButtonStyle())
            }
            Text("The text is read on this device. Only a cover crop you choose is saved with the recipe; the full screenshots aren’t kept.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var linkInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("https://", text: $link)
                .keyboardType(.URL).textContentType(.URL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(14)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("recipe-link")
            // PasteButton reads the clipboard only when tapped: no
            // "Allow Paste" prompt, no peeking at the clipboard on open.
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                Task { @MainActor in
                    if let url = Self.firstURL(in: first) { link = url.absoluteString; mode = .link }
                    else { text = first; mode = .text }
                    error = nil
                }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleAndIcon)
            .tint(Theme.ink)
            Text("In Safari or Apple News: Share → Copy Link, then Paste here.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text)
                .frame(minHeight: 240)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Title\n\nIngredients\n2 cups flour…\n\nDirections\n1. Preheat the oven…")
                            .foregroundStyle(Theme.muted.opacity(0.7))
                            .padding(.horizontal, 15).padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("recipe-text")
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                Task { @MainActor in text = first; error = nil }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleAndIcon)
            .tint(Theme.ink)
        }
    }

    private var parsedLink: URL? { Self.firstURL(in: link) }

    static func firstURL(in s: String) -> URL? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.hasPrefix("http"), url.host != nil { return url }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return detector.matches(in: trimmed, options: [], range: range)
            .compactMap { $0.url }.first { ($0.scheme ?? "").hasPrefix("http") }
    }

    private func finishImport(_ recipe: Recipe) {
        if pendingCoverSave != nil { library.saveError = nil }
        pendingCoverSave = nil
        UIAccessibility.post(notification: .announcement, argument: "Added \(recipe.title).")
        dismiss()
        onAdded(recipe.id)
    }

    private func runImport() {
        error = nil
        working = true
        Task { @MainActor in
            defer { working = false }
            if let pending = pendingCoverSave {
                guard library.saveImage(pending.data, for: pending.recipe.id) != nil else {
                    error = "Your recipe is saved, but the cover couldn’t be saved. Retry or continue without it."
                    return
                }
                finishImport(pending.recipe)
                return
            }
            do {
                let recipe: Recipe
                var imageData: Data?
                if mode == .link, let url = parsedLink {
                    let result = try await service.importLink(url)
                    recipe = result.recipe
                    imageData = result.imageData
                } else if mode == .screenshots {
                    imageData = coverData
                    var pages: [[OCRLine]] = []
                    for item in picked {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            pages.append(try await ScreenshotReader.lines(in: data))
                        }
                    }
                    recipe = RecipeImporter.build(try RecipeImporter.parse(screenshots: pages), method: .photo)
                } else {
                    recipe = try service.importText(text)
                }
                // A recipe that didn't reach disk is not "added" (A2 S1 finding).
                guard library.add(recipe) else {
                    error = library.saveError ?? "The recipe couldn’t be saved on this device. Try again."
                    return
                }
                if let data = imageData, let jpeg = RecipeFormat.storableJPEG(data) {
                    guard library.saveImage(jpeg, for: recipe.id) != nil else {
                        pendingCoverSave = PendingCoverSave(recipe: recipe, data: jpeg)
                        error = "Your recipe is saved, but the cover couldn’t be saved. Retry or continue without it."
                        return
                    }
                }
                finishImport(recipe)
            } catch let e as LocalizedError {
                if case RecipeImportError.appleNewsOnly = e { mode = .screenshots }
                error = e.errorDescription ?? "That didn’t work. Try pasting the recipe text instead."
            } catch {
                self.error = "That didn’t work. Try pasting the recipe text instead."
            }
        }
    }
}

// MARK: - The recipe page

struct RecipeDetailView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case ingredients = "Ingredients", directions = "Directions", timing = "Timing"
        var id: String { rawValue }
    }

    let recipeID: UUID
    var onChoose: (() -> Void)? = nil
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tab: Tab = .ingredients
    @State private var editingStep: CookingStep?
    @State private var confirmingReplace = false
    @State private var confirmingDelete = false
    @State private var cannotDelete = false

    private var recipe: Recipe? { library.recipe(id: recipeID) }
    private var isTonight: Bool { store.session.menuID == recipe?.menuID }
    private var hasProgress: Bool { store.session.records.values.contains { $0.state != .notStarted } }
    /// Timing is frozen while this recipe is being cooked, same rule as the catalog.
    private var timingLocked: Bool { isTonight && hasProgress }

    var body: some View {
        Group {
            if let recipe {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(recipe)
                        VStack(alignment: .leading, spacing: 22) {
                            if let problem = library.saveError {
                                Label(problem, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline).foregroundStyle(Theme.warning)
                                    .accessibilityIdentifier("recipe-save-error")
                            }
                            stats(recipe)
                            if recipe.needsTimingReview && tab != .timing { reviewBanner(recipe) }
                            tabBar
                            switch tab {
                            case .ingredients: ingredients(recipe)
                            case .directions: directions(recipe)
                            case .timing: timing(recipe)
                            }
                            sourceLink(recipe)
                        }
                        .padding(24)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Theme.recipeBackground)
                .safeAreaInset(edge: .bottom, spacing: 0) { cookBar(recipe) }
                .toolbar { moreMenu(recipe) }
                .sheet(item: $editingStep) { step in
                    DurationEditorView(step: step, initialMinutes: step.minutes, note: DurationEditorView.recipeNote) { minutes in
                        guard library.setStep(recipeID: recipeID, stepID: step.id, minutes: minutes) else {
                            return library.saveError ?? "The estimate couldn’t be saved. Try again."
                        }
                        return nil
                    }
                }
                .confirmationDialog("Change dinner and clear progress?", isPresented: $confirmingReplace, titleVisibility: .visible) {
                    Button("Cook \(recipe.title) instead", role: .destructive) { choose(recipe) }
                    Button("Cancel", role: .cancel) { }
                }
                .confirmationDialog("Delete this recipe?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete recipe", role: .destructive) { delete(recipe) }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("It’s removed from this device. The original page isn’t affected.")
                }
                .alert("You’re cooking this right now", isPresented: $cannotDelete) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Finish or reset tonight’s dinner first, then delete the recipe.")
                }
            } else {
                ContentUnavailableView("Recipe not found", systemImage: "book.closed",
                                       description: Text("It may have been deleted."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
    }

    // MARK: Hero and header

    @ViewBuilder
    private func hero(_ recipe: Recipe) -> some View {
        if let url = library.imageURL(for: recipe), let image = UIImage(contentsOfFile: url.path) {
            VStack(alignment: .leading, spacing: 0) {
                // Width comes from the screen, not the photo: a fill-scaled image
                // framed only by height keeps its natural width and widens the page.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 160 : 240)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [Theme.cream.opacity(0), Theme.cream],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 80)
                            .allowsHitTesting(false)
                    }
                    .accessibilityHidden(true)
                titleBlock(recipe, onPhoto: false)
                    .padding(.horizontal, 24).padding(.top, 20)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Label("FROM YOUR COLLECTION", systemImage: "book.closed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.olive)
                }
                titleBlock(recipe, onPhoto: false)
            }
            .padding(.horizontal, 24).padding(.top, 20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func titleBlock(_ recipe: Recipe, onPhoto: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(onPhoto ? .white : Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recipe-title")
            if let byline = recipe.source.byline {
                Text(byline).font(.subheadline.weight(.medium))
                    .foregroundStyle(onPhoto ? .white.opacity(0.9) : Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stats(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    stat("RECIPE TIME", recipe.totalMinutes.map(RecipeFormat.compact) ?? "Not stated")
                    stat("STEPS", "\(recipe.steps.count)")
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 14) {
                    stat("RECIPE TIME", recipe.totalMinutes.map(RecipeFormat.compact) ?? "Not stated")
                    stat("STEPS", "\(recipe.steps.count)")
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "YIELD")
                Text(recipe.yield ?? "Not stated")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            Text(value).font(.system(.title2, design: .rounded).weight(.medium)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reviewBanner(_ recipe: Recipe) -> some View {
        Button { tab = .timing } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.badge.questionmark").font(.title3).foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check the timing before you cook").font(.headline)
                    Text(recipe.estimatedStepCount == 0
                         ? "We found a time for each step. Check the amounts, step order and attention labels against your recipe."
                         : "\(recipe.estimatedStepCount) of \(recipe.steps.count) steps had no time, so we estimated them.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .dtCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timing-review-banner")
    }

    private var tabBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    Text(t.rawValue).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(tab == t ? Theme.ink : Theme.muted)
                        .background(tab == t ? Theme.paper : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier("recipe-tab-\(t.rawValue.lowercased())")
            }
                }
            } else {
                HStack(spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    Text(t.rawValue).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(tab == t ? Theme.ink : Theme.muted)
                        .background(tab == t ? Theme.paper : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier("recipe-tab-\(t.rawValue.lowercased())")
            }
                }
            }
        }
        .padding(4)
        .background(Theme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Tabs

    private func ingredients(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let y = recipe.yield { Text("Yield: \(y)").font(.subheadline).foregroundStyle(Theme.muted) }
            if recipe.ingredients.isEmpty {
                Text("No ingredient list came with this recipe.").foregroundStyle(Theme.muted)
            }
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func directions(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let total = recipe.totalMinutes {
                Text("Total time: \(RecipeFormat.compact(total))").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(Array(recipe.directions.enumerated()), id: \.offset) { i, line in
                VStack(alignment: .leading, spacing: 8) {
                    Text("STEP \(i + 1)").font(.footnote.weight(.semibold)).tracking(0.8)
                        .foregroundStyle(Theme.olive)
                        .accessibilityAddTraits(.isHeader)
                    TimedText.make(line).font(.title3).lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let notes = recipe.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "NOTES")
                    Text(notes).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("recipe-notes")
            }
        }
    }

    private func timing(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(timingLocked
                 ? "You’re cooking this now, so the timing is locked. Reset tonight’s dinner to change it."
                 : "These times build your dinner plan. Check every step against your recipe. Needs you means active work; hands-off means mostly waiting, with any checks your recipe requires.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            ForEach(recipe.dishes, id: \.self) { dish in
                VStack(alignment: .leading, spacing: 10) {
                    if recipe.dishes.count > 1 {
                        Text(dish.first?.dish ?? "").font(.caption.weight(.bold)).foregroundStyle(Theme.olive)
                    }
                    ForEach(dish) { step in timingRow(step) }
                }
            }
            HStack {
                Text("Timing plan").font(.headline)
                Spacer()
                Text(RecipeFormat.compact(recipe.plannedMinutes)).font(.headline).monospacedDigit()
            }
            .padding(.top, 4)
            if let total = recipe.totalMinutes, abs(total - recipe.plannedMinutes) >= 10 {
                Text("The recipe lists \(RecipeFormat.compact(total)) total; this plan uses \(RecipeFormat.compact(recipe.plannedMinutes)). Check for missing prep, resting time or overlapping steps.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private func timingRow(_ step: CookingStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.title).font(.subheadline.weight(.semibold))
            if normalizedDirection(step.detail) != normalizedDirection(step.title) {
                Text(step.detail).font(.subheadline).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if step.estimated == true {
                Label("Estimated time - tap to edit", systemImage: "clock.badge.questionmark")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.warning)
            }
            ViewThatFits(in: .horizontal) {
                timingControls(step, stacked: false)
                timingControls(step, stacked: true)
            }
            .disabled(timingLocked)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Keep the full detail when it adds instructions; avoid repeating a
    /// complete short instruction just because its title omitted a period.
    private func normalizedDirection(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            .lowercased()
    }

    private func timingControls(_ step: CookingStep, stacked: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
                Button { editingStep = step } label: {
                    Label(RecipeFormat.compact(step.minutes), systemImage: "timer")
                        .monospacedDigit()
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("\(step.title), \(step.minutes) minutes\(step.estimated == true ? ", estimated" : ""). Edit.")
                Button {
                    library.setStep(recipeID: recipeID, stepID: step.id, handsOn: !step.handsOn)
                } label: {
                    Label(step.handsOn ? "Needs you" : "Hands-off",
                          systemImage: step.handsOn ? "hand.raised" : "moon.zzz")
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityHint("Switches between needs you and hands-off.")
        }
        .fixedSize(horizontal: !stacked, vertical: false)
    }

    @ViewBuilder
    private func sourceLink(_ recipe: Recipe) -> some View {
        if let url = recipe.source.url {
            Link(destination: url) {
                Label("View the original\(recipe.source.publisher.map { " on \($0)" } ?? "")", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 8)
        }
    }

    // MARK: Actions

    private func cookBar(_ recipe: Recipe) -> some View {
        VStack(spacing: 6) {
            if isTonight {
                Text("This is tonight’s dinner. Set the time on Tonight, then build your plan.")
                    .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            if recipe.needsTimingReview && tab == .timing {
                Button {
                    guard library.markTimingReviewed(id: recipe.id) else {
                        UIAccessibility.post(notification: .announcement,
                                             argument: library.saveError ?? "Timing couldn’t be saved. Try again.")
                        return
                    }
                    UIAccessibility.post(notification: .announcement, argument: "Timing confirmed.")
                } label: { Label("Timing looks right", systemImage: "checkmark") }
                .buttonStyle(BigButtonStyle())
                .disabled(timingLocked || recipe.steps.isEmpty)
                .accessibilityIdentifier("timing-looks-right")
            } else {
                Button {
                    if recipe.needsTimingReview { tab = .timing }
                    else if isTonight { dismiss() }
                    else if hasProgress { confirmingReplace = true }
                    else { choose(recipe) }
                } label: {
                    Label(recipe.needsTimingReview ? "Check timing to continue" : (isTonight ? "Back to Tonight" : "Cook this for dinner"), systemImage: recipe.needsTimingReview ? "clock.badge.questionmark" : "frying.pan")
                }
                .buttonStyle(BigButtonStyle())
                .disabled(recipe.steps.isEmpty)
                .accessibilityIdentifier("cook-this-recipe")
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(Theme.cream)
    }

    @ToolbarContentBuilder
    private func moreMenu(_ recipe: Recipe) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let url = recipe.source.url {
                    ShareLink(item: url) { Label("Share link", systemImage: "square.and.arrow.up") }
                }
                Button(role: .destructive) {
                    if timingLocked { cannotDelete = true } else { confirmingDelete = true }
                } label: { Label("Delete recipe", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").accessibilityLabel("More")
            }
        }
    }

    private func choose(_ recipe: Recipe) {
        guard !recipe.needsTimingReview else { tab = .timing; return }
        store.chooseMenu(recipe.menuID)
        if let onChoose { onChoose() } else { dismiss() }
    }

    private func delete(_ recipe: Recipe) {
        let wasTonight = isTonight
        // Delete first; only a delete that reached disk changes tonight's dinner.
        guard library.remove(id: recipe.id) else { return } // saveError banner explains
        if wasTonight { store.chooseMenu(DinnerCatalog.menus[0].id) }
        dismiss()
    }
}

// MARK: - Directions with timer chips

/// Renders a direction with every stated duration highlighted, like the
/// orange timer chips in the reference: "about [⏱ 30 seconds]".
enum TimedText {
    static let pattern = #"(?i)\b\d+(?:[.,]\d+)?(?:\s?[½¼¾⅓⅔]|\s\d/\d)?(?:\s*(?:to|-|–|or)\s*\d+(?:[.,]\d+)?(?:\s?[½¼¾⅓⅔]|\s\d/\d)?)?\s*(?:seconds?|secs?|minutes?|mins?|hours?|hrs?)\b|\b(?:an|one|half an|a half) hours?\b|\bovernight\b"#

    static func make(_ line: String) -> Text {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return Text(line) }
        let ns = NSString(string: line)
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return Text(line) }
        var result = Text("")
        var cursor = 0
        for m in matches {
            if m.range.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                result = Text("\(result)\(Text(plain))")
            }
            let chip = Text("\(Image(systemName: "timer")) \(ns.substring(with: m.range))")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.tomato)
            result = Text("\(result)\(chip)")
            cursor = m.range.location + m.range.length
        }
        if cursor < ns.length { result = Text("\(result)\(Text(ns.substring(from: cursor)))") }
        return result
    }
}

// MARK: - Optional screenshot cover (local pixels only)

struct ScreenshotCoverSheet: View {
    let items: [PhotosPickerItem]
    var onUse: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var images: [UIImage] = []
    @State private var selected = 0
    @State private var zoom = 1.0
    @State private var horizontal = 0.5
    @State private var vertical = 0.5
    @State private var loading = true
    @State private var problem: String?

    private var preview: UIImage? {
        guard images.indices.contains(selected) else { return nil }
        return croppedImage(images[selected], width: 640)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose the food photo")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text("Choose a screenshot with a photo, then adjust the crop to leave out text and buttons. A cover is optional.")
                        .foregroundStyle(Theme.muted)
                    if loading {
                        ProgressView("Loading screenshots…")
                    } else if !images.isEmpty {
                        Picker("Screenshot", selection: $selected) {
                            ForEach(images.indices, id: \.self) { index in
                                Text("Screenshot \(index + 1)").tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("cover-source")
                        if let preview {
                            Image(uiImage: preview).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .accessibilityLabel("Cover crop preview")
                                .accessibilityIdentifier("cover-preview")
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Zoom").font(.headline)
                            Slider(value: $zoom, in: 1...4, step: 0.05) { Text("Zoom") }
                                .accessibilityValue(String(format: "%.1f times", zoom))
                                .accessibilityIdentifier("cover-zoom")
                            Text("Left to right").font(.headline)
                            Slider(value: $horizontal, in: 0...1) { Text("Horizontal crop position") }
                                .accessibilityValue("\(Int(horizontal * 100)) percent")
                                .accessibilityIdentifier("cover-horizontal")
                            Text("Top to bottom").font(.headline)
                            Slider(value: $vertical, in: 0...1) { Text("Vertical crop position") }
                                .accessibilityValue("\(Int(vertical * 100)) percent")
                                .accessibilityIdentifier("cover-vertical")
                        }
                        .dtCard()
                    }
                    if let problem {
                        Text(problem).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("cover-error")
                    }
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.cream)
            .foregroundStyle(Theme.ink)
            .navigationTitle("Cover photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Use this crop") {
                    guard images.indices.contains(selected),
                          let image = croppedImage(images[selected], width: 1200),
                          let data = image.jpegData(compressionQuality: 0.88) else {
                        problem = "This crop couldn’t be prepared. Try another screenshot."
                        return
                    }
                    onUse(data)
                    dismiss()
                }
                .buttonStyle(BigButtonStyle())
                .disabled(loading || preview == nil)
                .accessibilityIdentifier("use-cover-crop")
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Theme.cream)
            }
        }
        .tint(Theme.tomato)
        .onChange(of: selected) { _, _ in zoom = 1; horizontal = 0.5; vertical = 0.5 }
        .task { await loadImages() }
    }

    @MainActor
    private func loadImages() async {
        defer { loading = false }
        do {
            var loaded: [UIImage] = []
            for item in items {
                guard !Task.isCancelled else { return }
                guard let data = try await item.loadTransferable(type: Data.self),
                      let jpeg = RecipeFormat.storableJPEG(data),
                      let image = UIImage(data: jpeg) else {
                    problem = "A screenshot couldn’t be opened. Cancel and choose your screenshots again."
                    return
                }
                loaded.append(image)
            }
            guard !Task.isCancelled else { return }
            images = loaded
            if loaded.isEmpty { problem = "Choose screenshots before adding a cover." }
        } catch {
            problem = "The screenshots couldn’t be opened. Cancel and try again."
        }
    }

    private func croppedImage(_ image: UIImage, width: CGFloat) -> UIImage? {
        guard let crop = RecipeCoverCrop.rect(width: Double(image.size.width), height: Double(image.size.height),
                                             zoom: zoom, horizontal: horizontal, vertical: vertical) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let output = CGSize(width: width, height: width * 3 / 4)
        let scale = width / CGFloat(crop.width)
        return UIGraphicsImageRenderer(size: output, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: output))
            image.draw(in: CGRect(x: -CGFloat(crop.x) * scale, y: -CGFloat(crop.y) * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
    }
}
