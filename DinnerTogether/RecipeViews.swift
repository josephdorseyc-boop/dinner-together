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
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var path: [UUID]
    var goTonight: () -> Void
    var goCooking: () -> Void
    /// Owned by the root so Tonight's "Add your first recipe" can open it.
    @Binding var adding: Bool
    @State private var editing: Recipe?
    @State private var deleting: Recipe?
    @State private var cannotDelete = false
    /// A delete that didn't reach disk, in words about deleting (A2-17).
    @State private var deleteProblem: String?
    /// Search by title or ingredient (A2's build 20 shortlist).
    @State private var query = ""
    private var shown: [Recipe] { library.recipesFavoritesFirst.filter { $0.matches(query) } }

    private var hasProgress: Bool { store.session.records.values.contains { $0.state != .notStarted } }

    // A List, not a stack in a scroll view: rows swipe left for Edit and
    // Delete (Joe, build 12). The rows keep the card look — no separators,
    // clear row backgrounds, the page's own margins and 720-pt column.
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your kitchen, collected.")
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                Text("Your favorites, ready for dinner.")
                    .foregroundStyle(Theme.muted)
            }
            .libraryRow(top: 24, bottom: 12)
            if hasProgress {
                Button(action: goCooking) {
                    Label("Back to cooking", systemImage: "timer")
                }
                .buttonStyle(SecondaryButtonStyle())
                .libraryRow()
            }
            HStack {
                SectionLabel(text: "YOUR RECIPES")
                Spacer()
                // One Add when the cookbook is empty: the card's big button
                // (Joe, build 18: two Add recipe buttons on an empty page).
                if !library.isEmpty {
                    Button { adding = true } label: {
                        Label("Add a recipe", systemImage: "plus")
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityIdentifier("add-recipe")
                }
            }
            .libraryRow(top: 12)
            if let deleteProblem {
                Label(deleteProblem, systemImage: "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recipe-list-error")
                    .libraryRow()
            }
            if library.isEmpty {
                // The app starts empty (Joe, October 14): the cook's own
                // recipes are the whole cookbook, so the first thing to do
                // is bring one in.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cook your own recipes, on time.")
                        .font(.headline)
                    Text("Add a recipe link, screenshots, or text. Check the imported steps and timing before cooking.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Button { adding = true } label: {
                        Label("Add your first recipe", systemImage: "plus")
                    }
                    .buttonStyle(BigButtonStyle())
                    // The page's one Add button while it is empty.
                    .accessibilityIdentifier("add-recipe")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dtCard()
                .libraryRow()
            } else {
                if shown.isEmpty {
                    Text("No recipe matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))” by title or ingredient.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .libraryRow()
                        .accessibilityIdentifier("recipe-search-empty")
                }
                // Favorites get their own section at the top (Joe, build 20);
                // the rest follow under All recipes.
                let favorites = shown.filter(\.isFavorite)
                let others = shown.filter { !$0.isFavorite }
                if !favorites.isEmpty {
                    Label("FAVORITES", systemImage: "star.fill")
                        .font(.caption.weight(.semibold)).tracking(1.2)
                        .foregroundStyle(Theme.tomato)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("favorites-section")
                        .libraryRow(top: 8, bottom: 0)
                    ForEach(favorites) { recipe in recipeListRow(recipe) }
                    if !others.isEmpty {
                        SectionLabel(text: "ALL RECIPES")
                            .accessibilityIdentifier("all-recipes-section")
                            .libraryRow(top: 16, bottom: 0)
                    }
                }
                ForEach(others) { recipe in recipeListRow(recipe) }
            }
            Color.clear.frame(height: 24).libraryRow(top: 0, bottom: 0)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.recipeBackground)
        .foregroundStyle(Theme.ink)
        // The field sits in the bar, so it is at hand wherever the list is
        // scrolled; nothing to search in an empty cookbook.
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: library.isEmpty ? .automatic : .always),
                    prompt: "Title or ingredient")
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("recipe-library")
        .navigationDestination(for: UUID.self) { id in
            // The page — or, with the phone open like a book, the spread.
            RecipeSpreadView(recipeID: id, onChoose: goTonight)
        }
        .sheet(isPresented: $adding) {
            AddRecipeSheet { id in path.append(id) }.uiTestTypeSize()
        }
        .sheet(item: $editing) { recipe in
            RecipeEditSheet(recipe: recipe).uiTestTypeSize()
        }
        // An alert, not a confirmation dialog: alerts present reliably after
        // the swipe closes (dialogs from closing menus did not, A3-U-F11).
        .alert("Delete this recipe?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
               presenting: deleting) { recipe in
            Button("Delete recipe", role: .destructive) { delete(recipe) }
            Button("Cancel", role: .cancel) { }
        } message: { recipe in
            Text("“\(recipe.title)” is removed from this device. The original page isn’t affected.")
        }
        .alert("You’re cooking this right now", isPresented: $cannotDelete) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Finish or reset tonight’s dinner first, then delete the recipe.")
        }
    }

    /// Same rule as the page's Delete button: not while it's being cooked.
    /// One recipe in Your Recipes: the row opens it; the star beside it
    /// stars or unstars it in one tap (Joe, build 20: the swipe alone was
    /// not found). Swipe right stars too; swipe left for Edit and Delete.
    private func recipeListRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 4) {
            Button { path.append(recipe.id) } label: {
                RecipeRow(recipe: recipe, selected: store.session.menuID == recipe.menuID, marksFavorite: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the recipe. Swipe left for Edit and Delete.")
            Button { library.setFavorite(id: recipe.id, !recipe.isFavorite) } label: {
                Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(recipe.isFavorite ? Theme.tomato : Theme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recipe.isFavorite ? "Remove \(recipe.title) from favorites" : "Add \(recipe.title) to favorites")
            .accessibilityAddTraits(recipe.isFavorite ? .isSelected : [])
            .accessibilityIdentifier("recipe-star")
        }
        .libraryRow()
        // Plain buttons, not role: .destructive — that role
        // animates the row away before the cook has confirmed.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { library.setFavorite(id: recipe.id, !recipe.isFavorite) } label: {
                Label(recipe.isFavorite ? "Unstar" : "Star", systemImage: recipe.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(Theme.tomato)
            .accessibilityIdentifier("swipe-favorite")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { requestDelete(recipe) } label: { Label("Delete", systemImage: "trash") }
                .tint(.red)
                .accessibilityIdentifier("swipe-delete")
            Button { editing = recipe } label: { Label("Edit", systemImage: "pencil") }
                .tint(Theme.olive)
                .accessibilityIdentifier("swipe-edit")
        }
    }

    private func requestDelete(_ recipe: Recipe) {
        if store.session.menuID == recipe.menuID && hasProgress { cannotDelete = true } else { deleting = recipe }
    }

    private func delete(_ recipe: Recipe) {
        let wasTonight = store.session.menuID == recipe.menuID
        // Delete first; only a delete that reached disk changes tonight's dinner.
        guard library.remove(id: recipe.id) else {
            deleteProblem = "“\(recipe.title)” couldn’t be deleted. It’s still in your recipes. Try deleting it again."
            UIAccessibility.post(notification: .announcement, argument: deleteProblem)
            return
        }
        deleteProblem = nil
        if wasTonight { store.clearDinner() }
    }
}

private extension View {
    /// A list row that looks like the page around it.
    func libraryRow(top: CGFloat = 7, bottom: CGFloat = 7) -> some View {
        frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: top, leading: 24, bottom: bottom, trailing: 24))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct RecipeRow: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    let selected: Bool
    /// The small star before the title; off where the row has its own star button.
    var marksFavorite = true

    // Explicit: the private wrapper makes the memberwise init file-private,
    // and Tonight (PlanView.swift) shows this row too.
    init(recipe: Recipe, selected: Bool, marksFavorite: Bool = true) {
        self.recipe = recipe; self.selected = selected; self.marksFavorite = marksFavorite
    }

    var body: some View {
        HStack(spacing: 14) {
            RecipeThumbnail(recipe: recipe, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if marksFavorite && recipe.isFavorite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.tomato)
                            .accessibilityLabel("Favorite")
                    }
                    Text(recipe.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                }
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
            if let image = RecipePhotos.load(recipe, from: library)?.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let palette = recipe.resolvedPalette(photo: nil) {
                Image(systemName: "book.closed").font(.title3.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.swatchGradient)
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

private enum ScreenshotReadError: LocalizedError {
    case unavailable(number: Int)

    nonisolated var errorDescription: String? {
        switch self {
        case .unavailable(let number):
            return "Screenshot \(number) couldn’t be opened. Choose it again and retry."
        }
    }
}

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
    /// Screenshot bytes supplied without the picker: shared from another app
    /// (phase 1b), or the DEBUG UI-test stub (-dt-stub-screenshots).
    @State private var stubbed: [Data]
    /// A link or text that arrived through the share sheet starts importing
    /// as soon as the sheet appears (Mela's behavior); images wait for Add.
    private let autoImport: Bool
    private var screenshotCount: Int { stubbed.isEmpty ? picked.count : stubbed.count }

    init(shared: PendingShare? = nil, onAdded: @escaping (UUID) -> Void) {
        self.onAdded = onAdded
        var initialMode = Mode.link
        var initialLink = "", initialText = ""
        var provided = LaunchOptions.stubScreenshotData()
        var auto = false
        if let shared {
            switch shared.item.kind {
            case .link: initialMode = .link; initialLink = shared.item.url?.absoluteString ?? ""; auto = !initialLink.isEmpty
            case .text: initialMode = .text; initialText = shared.item.text ?? ""; auto = !initialText.isEmpty
            case .images: initialMode = .screenshots; provided = shared.images
            }
        }
        _mode = State(initialValue: initialMode)
        _link = State(initialValue: initialLink)
        _text = State(initialValue: initialText)
        _stubbed = State(initialValue: provided)
        autoImport = auto
    }

    /// The chosen screenshots' bytes, in selection order.
    private func screenshotData() async throws -> [Data] {
        if !stubbed.isEmpty { return stubbed }
        var out: [Data] = []
        for (index, item) in picked.enumerated() {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ScreenshotReadError.unavailable(number: index + 1)
            }
            out.append(data)
        }
        return out
    }
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
        .task { if autoImport && !working { runImport() } }
        .sheet(isPresented: $choosingCover) {
            ScreenshotCoverSheet(load: { try await screenshotData() }) { coverData = $0 }
                .uiTestTypeSize()
        }
    }

    private var canImport: Bool {
        switch mode {
        case .link: return parsedLink != nil
        case .screenshots: return screenshotCount > 0
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var screenshotInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose up to 30 screenshots, in recipe order. For Apple News Cook mode, include the cover, ingredients and every step. Make sure each instruction is fully visible below the top bar in at least one image. Check the imported text and timing before cooking.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            if stubbed.isEmpty {
                PhotosPicker(selection: $picked, maxSelectionCount: 30, selectionBehavior: .ordered, matching: .images) {
                    Label(picked.isEmpty ? "Choose screenshots" : "\(picked.count) chosen — change", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("choose-screenshots")
            } else {
                Label("\(stubbed.count) test screenshots", systemImage: "photo.on.rectangle.angled")
                    .accessibilityIdentifier("choose-screenshots")
            }
            if screenshotCount > 0 {
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
                    for data in try await screenshotData() {
                        pages.append(try await ScreenshotReader.lines(in: data))
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
                    // A video post's cover can carry a baked-in ▶: cropped,
                    // the original kept for Edit cover (Joe, build 19; A2).
                    if RecipeLibrary.isVideoPost(recipe) { library.cropPlayButton(for: recipe.id) }
                }
                finishImport(recipe)
            } catch let e as LocalizedError {
                // Links that can only be finished with screenshots switch the
                // sheet there, with the explanation kept in view.
                switch e as? RecipeImportError {
                case .appleNewsOnly, .captionWithoutRecipe, .instagramLoginWall, .tiktokUnavailable: mode = .screenshots
                default: break
                }
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

    /// The page as itself, or the spread's LEFT page: a reader of a second
    /// recipe (ingredients and directions only — read alongside, never
    /// cooked from here), with no menu, cook bar or delete, and its own
    /// identifiers ("-second") so the main page's stay unique.
    enum Role { case page, reader }

    let recipeID: UUID
    var onChoose: (() -> Void)? = nil
    var role: Role = .page
    /// The spread's reader only: the main recipe on the right, so this page
    /// can offer "Cook both together" (Joe, October 14).
    var pairMain: UUID? = nil
    /// A page of the Duo's cookbook spread (Joe approved A2-59, October 15):
    /// a small rounded photo beside a serif title, underlined tabs, olive
    /// numbered steps between hairlines, a quiet cook button, and on the main
    /// page a small terracotta leaf. `pageWidth` is the page's own width.
    var bookPage = false
    var pageWidth: CGFloat? = nil
    /// Behind the side dish on the Duo's single page: its bar buttons go
    /// away so ••• and the star never act on a recipe out of sight.
    var inBackground = false
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tab: Tab = .ingredients
    @State private var editingStep: CookingStep?
    @State private var removingStep: CookingStep?
    @State private var confirmingReplace = false
    @State private var confirmingDelete = false
    @State private var cannotDelete = false
    @State private var choosingPageStyle = false
    @State private var editingRecipeTime = false
    @State private var editingDetails = false
    @State private var editInNotes = false
    @State private var editingCover = false
    /// A delete that didn't reach disk, in words about deleting (A2-17).
    @State private var deleteProblem: String?
    @Environment(\.colorScheme) private var colorScheme

    private var recipe: Recipe? { library.recipe(id: recipeID) }
    private var reader: Bool { role == .reader }
    private func pageID(_ base: String) -> String { reader ? base + "-second" : base }
    /// The reader reads (Ingredients, Directions); Timing appears there
    /// only while this recipe's timing still needs its check, so it can be
    /// cooked alongside the main.
    private var tabs: [Tab] {
        guard reader, let recipe, !recipe.needsTimingReview, tab != .timing else { return Tab.allCases }
        return [.ingredients, .directions]
    }
    /// What "cook" means here: this recipe, or — on the spread's second
    /// page — the main and this one together.
    private var dinnerMenuID: String? {
        guard let recipe else { return nil }
        if reader { return pairMain.map { PairedDinner.menuID(main: $0, side: recipe.id) } }
        return recipe.menuID
    }
    private var mainNeedsReview: Bool { pairMain.flatMap { library.recipe(id: $0) }?.needsTimingReview ?? false }
    /// The page's colors (photo or the cook's choice); nil = classic cream.
    private var pagePalette: RecipePalette? { recipe.flatMap { RecipePhotos.palette(for: $0, from: library) } }
    /// A page draws from its own colors whatever the phone's appearance —
    /// light text on a deep page, the classic dark text on a pale one and
    /// on Classic cream, which is cream in Dark Mode too (Joe, build 19:
    /// choosing it left the page dark; Charcoal is the dark page).
    private var pageScheme: ColorScheme { pagePalette.map { $0.tone == .deep ? .dark : .light } ?? .light }
    /// Deep pages swap the classic accents for ones that read on dark color.
    private var deepPage: Bool { pagePalette?.tone == .deep }
    private var labelColor: Color { deepPage ? Theme.pageAccent : Theme.olive }
    private var accentColor: Color { deepPage ? Theme.pageAccent : Theme.tomato }
    private var isTonight: Bool { dinnerMenuID != nil && store.session.menuID == dinnerMenuID }
    private var hasProgress: Bool { store.session.records.values.contains { $0.state != .notStarted } }
    /// Timing is frozen while this recipe is being cooked, same rule as the catalog.
    /// Timing is frozen while this recipe is being cooked — alone or as
    /// half of a paired dinner.
    private var timingLocked: Bool {
        guard hasProgress, let recipe else { return false }
        if store.session.menuID == recipe.menuID { return true }
        if let pair = PairedDinner.parse(store.session.menuID) { return pair.main == recipe.id || pair.side == recipe.id }
        return false
    }

    var body: some View {
        Group {
            if let recipe {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if bookPage { bookHeader(recipe) } else { hero(recipe) }
                        VStack(alignment: .leading, spacing: bookPage ? 18 : 22) {
                            if let problem = deleteProblem ?? library.saveError {
                                Label(problem, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline).foregroundStyle(Theme.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier(pageID("recipe-save-error"))
                            }
                            if !bookPage { stats(recipe) }
                            if !reader && recipe.needsTimingReview && tab != .timing { reviewBanner(recipe) }
                            if bookPage { bookTabs } else { tabBar }
                            importWarningCard(recipe)
                            switch tab {
                            case .ingredients: ingredients(recipe)
                            case .directions: directions(recipe)
                            case .timing: timing(recipe)
                            }
                            sourceLink(recipe)
                            if !reader { deleteButton }
                        }
                        .padding(bookPage ? 18 : 24)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background {
                    if let palette = pagePalette { RecipePageBackground(palette: palette) }
                    else { Theme.recipeBackground.ignoresSafeArea() }
                }
                .environment(\.recipePalette, pagePalette)
                .environment(\.colorScheme, pageScheme)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !reader || pairMain != nil {
                        cookBar(recipe)
                            .environment(\.recipePalette, pagePalette)
                            .environment(\.colorScheme, pageScheme)
                    }
                }
                // A colored page is dark whatever the phone's appearance, so
                // the system chrome over it must be too: the status clock
                // and the tab bar (A2-17: black clock on brown, 2.1:1).
                // (The main page's say; the spread's left page has none.)
                .toolbarColorScheme(reader ? nil : pageScheme, for: .navigationBar, .tabBar)
                .toolbar {
                    if !reader && !inBackground {
                        ToolbarItem(placement: .primaryAction) {
                            Button { library.setFavorite(id: recipe.id, !recipe.isFavorite) } label: {
                                Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                            }
                            .tint(recipe.isFavorite ? Theme.tomato : nil)
                            .accessibilityLabel(recipe.isFavorite ? "Favorite. Remove star" : "Star this recipe")
                            .accessibilityAddTraits(recipe.isFavorite ? .isSelected : [])
                            .accessibilityIdentifier("recipe-favorite")
                        }
                        moreMenu(recipe)
                    }
                }
                .sheet(isPresented: $choosingPageStyle) { PageStyleSheet(recipeID: recipeID).uiTestTypeSize() }
                .sheet(isPresented: $editingRecipeTime) {
                    RecipeTimeSheet(recipeID: recipeID, initialMinutes: recipe.totalMinutes).uiTestTypeSize()
                }
                .sheet(isPresented: $editingDetails, onDismiss: { editInNotes = false }) {
                    RecipeEditSheet(recipe: recipe, startInNotes: editInNotes).uiTestTypeSize()
                }
                .sheet(isPresented: $editingCover) {
                    EditCoverSheet(recipe: recipe).uiTestTypeSize()
                }
                .sheet(item: $editingStep) { step in
                    DurationEditorView(step: step, initialMinutes: step.minutes, note: DurationEditorView.recipeNote) { minutes in
                        guard library.setStep(recipeID: recipeID, stepID: step.id, minutes: minutes) else {
                            return library.saveError ?? "The estimate couldn’t be saved. Try again."
                        }
                        return nil
                    }
                    .uiTestTypeSize()
                }
                .confirmationDialog("Change dinner and clear progress?", isPresented: $confirmingReplace, titleVisibility: .visible) {
                    Button(reader ? "Cook both instead" : "Cook \(recipe.title) instead", role: .destructive) { choose(recipe) }
                    Button("Cancel", role: .cancel) { }
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

    /// The cookbook page's head (A2-59, approved): the photo small and
    /// rounded beside the serif title, its time and yield under it; on a
    /// narrow page the photo sits above. A small terracotta leaf marks the
    /// main page, decorative only, and gives way at large text.
    @ViewBuilder
    private func bookHeader(_ recipe: Recipe) -> some View {
        let narrow = (pageWidth ?? 400) < 340
        let meta = [recipe.plannedMinutes > 0 ? RecipeFormat.compact(recipe.plannedMinutes) : nil,
                    recipe.yield.map { "Serves \($0)" }].compactMap { $0 }.joined(separator: " • ")
        let photo = RecipePhotos.load(recipe, from: library)?.image
        let title = VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.system(narrow ? .title3 : .title2, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(pageID("recipe-title"))
            if !meta.isEmpty {
                Text(meta).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        let thumb = Group {
            if let photo {
                Color.clear
                    .frame(width: narrow ? 72 : 96, height: narrow ? 72 : 96)
                    .overlay(Image(uiImage: photo).resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement()
                    .accessibilityLabel("Photo of \(recipe.title)")
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier(pageID("recipe-hero"))
            }
        }
        VStack(alignment: .leading, spacing: 12) {
            if !reader && !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Spacer()
                    Image(systemName: "leaf")
                        .font(.title3).rotationEffect(.degrees(-35))
                        .foregroundStyle(Theme.tomato.opacity(0.85))
                        .accessibilityHidden(true)
                }
            }
            if narrow || dynamicTypeSize.isAccessibilitySize {
                thumb
                title
            } else {
                HStack(alignment: .center, spacing: 16) { thumb; title }
            }
        }
        .padding(.horizontal, 18).padding(.top, 12)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// Underlined tabs on a hairline (A2-59), smaller type before they wrap.
    private var bookTabs: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                bookTabRow(spacing: 22, font: .subheadline)
                bookTabRow(spacing: 12, font: .footnote)
                VStack(alignment: .leading, spacing: 0) { bookTabButtons(font: .subheadline) }
            }
            Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
        }
    }

    private func bookTabRow(spacing: CGFloat, font: Font) -> some View {
        HStack(spacing: spacing) { bookTabButtons(font: font) }
    }

    @ViewBuilder
    private func bookTabButtons(font: Font) -> some View {
        ForEach(tabs) { t in
            Button { tab = t } label: {
                Text(t.rawValue)
                    .font(font.weight(tab == t ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(tab == t ? Theme.ink : Theme.muted)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(tab == t ? Theme.olive : .clear).frame(height: 2)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(tab == t ? .isSelected : [])
            .accessibilityIdentifier(pageID("recipe-tab-\(t.rawValue.lowercased())"))
        }
    }

    @ViewBuilder
    private func hero(_ recipe: Recipe) -> some View {
        if let image = RecipePhotos.load(recipe, from: library)?.image {
            VStack(alignment: .leading, spacing: 0) {
                // Width comes from the screen, not the photo: a fill-scaled image
                // framed only by height keeps its natural width and widens the page.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 160 : 240)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
                    .mask {
                        // Colored page: the photo itself fades out, so it melts
                        // into the gradient (the page's top third is one color).
                        if pagePalette != nil {
                            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.6),
                                                   .init(color: .clear, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                        } else {
                            Rectangle()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if pagePalette == nil {
                            LinearGradient(colors: [Theme.cream.opacity(0), Theme.cream],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 80)
                                .allowsHitTesting(false)
                        }
                    }
                    // A content photo, not decoration: VoiceOver names it and
                    // tests can find it (cover-crop flow).
                    .accessibilityElement()
                    .accessibilityLabel("Photo of \(recipe.title)")
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier(pageID("recipe-hero"))
                titleBlock(recipe, onPhoto: false)
                    .padding(.horizontal, 24).padding(.top, 20)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Label("FROM YOUR COLLECTION", systemImage: "book.closed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(labelColor)
                    }
                    Spacer(minLength: 0)
                    // Typed and pasted recipes have no photo to take colors
                    // from, so the choice is on the page, not only in •••.
                    Button { choosingPageStyle = true } label: {
                        Label("Page color", systemImage: "paintpalette")
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityIdentifier(pageID("page-color-button"))
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
                .accessibilityIdentifier(pageID("recipe-title"))
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
                    recipeTimeStat(recipe)
                    stat("STEPS", "\(recipe.steps.count)")
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 14) {
                    recipeTimeStat(recipe)
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
    }

    /// The recipe's own time, tappable: an import that found none shows
    /// "Add time" (Joe, build 11: "warn users they didn't include the recipe
    /// time… include the ability to manually enter it").
    private func recipeTimeStat(_ recipe: Recipe) -> some View {
        Button { editingRecipeTime = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "RECIPE TIME")
                HStack(spacing: 6) {
                    Text(recipe.totalMinutes.map(RecipeFormat.compact) ?? "Add time")
                        .font(.system(.title2, design: .rounded).weight(.medium)).monospacedDigit()
                        .foregroundStyle(recipe.totalMinutes == nil ? accentColor : Theme.ink)
                    Image(systemName: recipe.totalMinutes == nil ? "plus.circle" : "pencil.circle")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.totalMinutes.map { "Recipe time, \(RecipeFormat.compact($0))" } ?? "Recipe time not stated")
        .accessibilityHint(recipe.totalMinutes == nil ? "Adds the recipe’s total time." : "Edits the recipe’s total time.")
        .accessibilityIdentifier(pageID("recipe-time"))
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
                    Text(dynamicTypeSize.isAccessibilitySize ? "Review timing" : "Check the timing before you cook").font(.headline)
                    Text(reviewBannerText(recipe))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .padding(22)
            .recipeSurface(cornerRadius: 26)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timing-review-banner")
    }

    private func reviewBannerText(_ recipe: Recipe) -> String {
        if dynamicTypeSize.isAccessibilitySize {
            // A2-21: shorter timing copy; content notes have their own surface.
            let estimateCount = recipe.estimatedStepCount
            var summary = estimateCount == 0 ? "Check step times." :
                "\(estimateCount) estimated \(estimateCount == 1 ? "step" : "steps")."
            if recipe.totalMinutes == nil { summary += " Add recipe time." }
            return summary
        }
        var text = recipe.estimatedStepCount == 0
            ? "We found a time for each step. Check the amounts, step order and attention labels against your recipe."
            : "\(recipe.estimatedStepCount) of \(recipe.steps.count) steps had no time, so we estimated them."
        if recipe.totalMinutes == nil { text += " No total time was found — add it under Recipe time." }
        return text
    }

    /// Content uncertainty survives timing confirmation and remains visible on every tab.
    @ViewBuilder
    private func importWarningCard(_ recipe: Recipe) -> some View {
        if let warnings = recipe.importWarnings, !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Check the imported text", systemImage: "exclamationmark.triangle")
                    .font(.headline).foregroundStyle(Theme.warning)
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Compare the imported instructions with your original recipe before cooking.")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .recipeSurface(cornerRadius: 22)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(pageID("import-content-warning"))
        }
    }

    private var tabBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
            ForEach(tabs) { t in
                Button { tab = t } label: {
                    Text(t.rawValue).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(tab == t ? Theme.ink : Theme.muted)
                        .background(tab == t ? selectedTabFill : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier(pageID("recipe-tab-\(t.rawValue.lowercased())"))
            }
                }
            } else {
                HStack(spacing: 6) {
            ForEach(tabs) { t in
                Button { tab = t } label: {
                    Text(t.rawValue).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(tab == t ? Theme.ink : Theme.muted)
                        .background(tab == t ? selectedTabFill : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier(pageID("recipe-tab-\(t.rawValue.lowercased())"))
            }
                }
            }
        }
        .padding(4)
        .modifier(TabTrack(colored: pagePalette != nil))
    }

    private var selectedTabFill: Color {
        deepPage ? Color.white.opacity(RecipePalette.selectedLift) : Theme.paper
    }

    // MARK: Tabs

    private func ingredients(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let y = recipe.yield { Text("Yield: \(y)").font(.subheadline).foregroundStyle(Theme.muted) }
            if recipe.ingredients.isEmpty {
                Text("No ingredient list came with this recipe.").foregroundStyle(Theme.muted)
            }
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, line in
                if SocialImport.isGroupHeader(line) {
                    // "For the chicken:" heads its group, not a card of its own.
                    Text(line.dropLast().uppercased())
                        .font(.footnote.weight(.semibold)).tracking(0.8)
                        .foregroundStyle(labelColor)
                        .padding(.top, i == 0 ? 0 : 10)
                        .accessibilityAddTraits(.isHeader)
                } else if bookPage {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(line).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
                    }
                } else {
                    Text(line)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .recipeSurface(cornerRadius: 18)
                }
            }
        }
    }

    private func directions(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let total = recipe.totalMinutes {
                Text("Total time: \(RecipeFormat.compact(total))").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(Array(recipe.directions.enumerated()), id: \.offset) { i, line in
                if bookPage {
                    // Olive numbered steps between hairlines (A2-59).
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(minWidth: 28, minHeight: 28)
                                .background(Circle().fill(Theme.olive))
                                .accessibilityLabel("Step \(i + 1)")
                            TimedText.make(line, accent: accentColor)
                                .font(.body).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STEP \(i + 1)").font(.footnote.weight(.semibold)).tracking(0.8)
                            .foregroundStyle(labelColor)
                            .accessibilityAddTraits(.isHeader)
                        TimedText.make(line, accent: accentColor)
                            .font(.title3).lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            // The recipe's notes — an import's own, and the cook's (A2,
            // build 19), edited from here or the ••• menu.
            VStack(alignment: .leading, spacing: 8) {
                if bookPage {
                    Text("Cooking notes").font(.system(.headline, design: .serif)).accessibilityAddTraits(.isHeader)
                } else {
                    SectionLabel(text: "NOTES")
                }
                if let notes = recipe.notes, !notes.isEmpty {
                    Text(notes).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(pageID("recipe-notes"))
                    Button { startEditing(inNotes: true) } label: {
                        Label("Edit notes", systemImage: "pencil").font(.subheadline.weight(.semibold))
                    }
                    .tint(accentColor)
                    .accessibilityIdentifier(pageID("edit-notes"))
                } else {
                    Button { startEditing(inNotes: true) } label: {
                        Label("Add your notes — what to remember next time", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .tint(accentColor)
                    .accessibilityIdentifier(pageID("add-notes"))
                }
            }
        }
    }

    /// The Edit sheet, in Notes when asked. (The page's own menu waits for
    /// the menu to close first; from the page body there is no menu.)
    private func startEditing(inNotes: Bool) {
        editInNotes = inNotes
        editingDetails = true
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
                        Text(dish.first?.dish ?? "").font(.caption.weight(.bold)).foregroundStyle(labelColor)
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
            } else if recipe.totalMinutes == nil {
                Button { editingRecipeTime = true } label: {
                    Label("No total time came with this recipe. Add it to compare with this plan.", systemImage: "clock.badge.questionmark")
                        .font(.caption).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.warning)
                .accessibilityIdentifier(pageID("recipe-time-missing"))
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
        .recipeSurface(cornerRadius: 18)
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
                // Text the import mistook for a step leaves the recipe here
                // (A2 S2). The dialog hangs off its own button: on iOS 26 a
                // dialog presented from a scrolling page shows as a bubble
                // at the button, and tapping away cancels it.
                Button(role: .destructive) { removingStep = step } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("remove-step-\(step.id)")
                .accessibilityLabel("Remove \(step.title)")
                .accessibilityHint("Removes the step and its matching direction from this recipe and its timing plan.")
                .confirmationDialog("Remove this step?",
                                    isPresented: Binding(get: { removingStep?.id == step.id },
                                                         set: { if !$0 { removingStep = nil } }),
                                    titleVisibility: .visible) {
                    Button("Remove step", role: .destructive) {
                        if !library.removeStep(recipeID: recipeID, stepID: step.id) {
                            UIAccessibility.post(notification: .announcement, argument: library.saveError)
                        }
                    }
                    Button("Cancel", role: .cancel) { removingStep = nil }
                } message: {
                    Text("This removes the step and its matching direction from this saved recipe and its timing plan. Use this for text that isn’t a cooking instruction.")
                }
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
            .tint(accentColor)
            .padding(.top, 8)
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func cookBar(_ recipe: Recipe) -> some View {
        let bar = VStack(spacing: 6) {
            if isTonight && !bookPage {
                Text(reader ? "These two are tonight’s dinner. Set the time on Tonight, then build your plan."
                            : "This is tonight’s dinner. Set the time on Tonight, then build your plan.")
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
                .buttonStyle(CookBarStyle(book: bookPage, onColoredPage: deepPage))
                .disabled(timingLocked || recipe.steps.isEmpty)
                .accessibilityIdentifier(pageID("timing-looks-right"))
            } else if reader {
                if mainNeedsReview {
                    Text("Check the main recipe’s timing on the right first.")
                        .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                Button {
                    if recipe.needsTimingReview { tab = .timing }
                    else if isTonight { onChoose?() }
                    else if hasProgress { confirmingReplace = true }
                    else { choose(recipe) }
                } label: {
                    Label(recipe.needsTimingReview ? "Check timing to continue" : (isTonight ? "Back to Tonight" : "Cook both together"),
                          systemImage: recipe.needsTimingReview ? "clock.badge.questionmark" : "frying.pan")
                }
                .buttonStyle(CookBarStyle(book: bookPage, onColoredPage: deepPage))
                .disabled(recipe.steps.isEmpty || (mainNeedsReview && !recipe.needsTimingReview && !isTonight))
                .accessibilityHint("Cooks this and the recipe on the right on one timeline, ready together.")
                .accessibilityIdentifier("cook-both")
            } else {
                Button {
                    if recipe.needsTimingReview { tab = .timing }
                    // "Back to Tonight" goes to Tonight — not just back to the
                    // collection with the recipe ticked (Joe, build 10).
                    else if isTonight { if let onChoose { onChoose() } else { dismiss() } }
                    else if hasProgress { confirmingReplace = true }
                    else { choose(recipe) }
                } label: {
                    Label(recipe.needsTimingReview ? "Check timing to continue" : (isTonight ? "Back to Tonight" : "Cook this for dinner"), systemImage: recipe.needsTimingReview ? "clock.badge.questionmark" : "frying.pan")
                }
                .buttonStyle(CookBarStyle(book: bookPage, onColoredPage: deepPage))
                .disabled(recipe.steps.isEmpty)
                .accessibilityIdentifier("cook-this-recipe")
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        if let palette = pagePalette {
            // Frosted, and mostly the page's deepest color, so the caption
            // stays readable whatever scrolls underneath.
            bar.background {
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(palette.colors[2].color.opacity(0.88))
                    .ignoresSafeArea()
            }
        } else {
            bar.background(Theme.cream)
        }
    }

    @ToolbarContentBuilder
    private func moreMenu(_ recipe: Recipe) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let url = recipe.source.url {
                    ShareLink(item: url) { Label("Share link", systemImage: "square.and.arrow.up") }
                }
                Button {
                    // A sheet from a Menu action presents reliably once the
                    // menu has closed (4 runs of 4 on iPhone and iPad); a
                    // dialog from one does not, which is why Delete is a
                    // button on the page (A3-U-F11).
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        choosingPageStyle = true
                    }
                } label: { Label("Page color", systemImage: "paintpalette") }
                Button {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        editingDetails = true
                    }
                } label: { Label("Edit title, yield and notes", systemImage: "pencil") }
                Button {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        editingCover = true
                    }
                } label: { Label(recipe.imageFilename == nil ? "Add cover photo" : "Edit cover photo", systemImage: "photo") }
            } label: {
                // On a colored page the glyph carries its own dark disc, so
                // it reads over a bright hero photo whatever the glass does
                // (iPad run 38290508810: white dots on clear glass over the
                // orange photo were nearly invisible).
                if pagePalette == nil {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("More")
                } else {
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.42))
                        .accessibilityLabel("More")
                }
            }
            // The identifier is on the Menu itself: on iOS 27 the label's
            // "More" did not reach XCTest on colored pages (duo-validation
            // 38425944734, test12/test18/test27), while the identifier does.
            .accessibilityIdentifier("recipe-more")
        }
    }

    /// Delete lives at the end of the page, not in the ••• menu: a
    /// confirmation dialog requested from a closing Menu was dropped on
    /// iPhone in five CI runs out of five (and once on iPad), with or
    /// without a delay — the cook would have tapped Delete and seen
    /// nothing. From a plain button the dialog presents every time.
    @ViewBuilder
    private var deleteButton: some View {
        if let recipe {
            Button(role: .destructive) {
                if timingLocked { cannotDelete = true } else { confirmingDelete = true }
            } label: {
                Label("Delete this recipe", systemImage: "trash")
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.top, 12)
            .accessibilityIdentifier("delete-recipe")
            // On the button, so iOS 26's popover-style dialog points at it
            // (attached to the page it pointed at the review banner, run
            // 38330367116). That style shows no Cancel; tapping away cancels.
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
        }
    }

    private func choose(_ recipe: Recipe) {
        guard !recipe.needsTimingReview, !(reader && mainNeedsReview), let id = dinnerMenuID else {
            if recipe.needsTimingReview { tab = .timing }
            return
        }
        store.chooseMenu(id)
        if let onChoose { onChoose() } else { dismiss() }
    }

    private func delete(_ recipe: Recipe) {
        let wasTonight = isTonight
        // Delete first; only a delete that reached disk changes tonight's dinner.
        guard library.remove(id: recipe.id) else {
            deleteProblem = "This recipe couldn’t be deleted. It’s still in your recipes. Try deleting it again."
            UIAccessibility.post(notification: .announcement, argument: deleteProblem)
            return
        }
        deleteProblem = nil
        if wasTonight { store.clearDinner() }
        dismiss()
    }
}

// MARK: - Directions with timer chips

/// Renders a direction with every stated duration highlighted, like the
/// orange timer chips in the reference: "about [⏱ 30 seconds]".
enum TimedText {
    static let pattern = #"(?i)\b\d+(?:[.,]\d+)?(?:\s?[½¼¾⅓⅔]|\s\d/\d)?(?:\s*(?:to|-|–|or)\s*\d+(?:[.,]\d+)?(?:\s?[½¼¾⅓⅔]|\s\d/\d)?)?\s*(?:seconds?|secs?|minutes?|mins?|hours?|hrs?)\b|\b(?:an|one|half an|a half) hours?\b|\bovernight\b"#

    static func make(_ line: String, accent: Color = Theme.tomato) -> Text {
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
                .foregroundStyle(accent)
            result = Text("\(result)\(chip)")
            cursor = m.range.location + m.range.length
        }
        if cursor < ns.length { result = Text("\(result)\(Text(ns.substring(from: cursor)))") }
        return result
    }
}

// MARK: - Optional screenshot cover (local pixels only)

struct ScreenshotCoverSheet: View {
    /// Supplies the chosen screenshots' bytes (photo picker or UI-test stub).
    let load: () async throws -> [Data]
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
            for data in try await load() {
                guard !Task.isCancelled else { return }
                guard let jpeg = RecipeFormat.storableJPEG(data),
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

/// The tab bar's track: a faint ink wash on the classic page, frosted glass
/// on a colored one (the wash would lighten the page under muted labels).
private struct TabTrack: ViewModifier {
    let colored: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if colored {
            content.recipeSurface(cornerRadius: 20)
        } else {
            content.background(Theme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Edit cover photo (Joe, October 14)

/// The recipe's cover after import: crop the current one again, choose a
/// screenshot or photo from Photos, use the plate photo, or remove it. The
/// crop step is the import's own cover sheet.
struct EditCoverSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var picked: [PhotosPickerItem] = []
    @State private var candidates: [Data] = []
    @State private var cropping = false
    @State private var loading = false
    @State private var saved = false
    @State private var problem: String?

    private var current: Recipe { library.recipe(id: recipe.id) ?? recipe }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Cover photo")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text("The cover leads the recipe’s page and sets its colors. Choose a screenshot or photo, then crop it to the food.")
                        .foregroundStyle(Theme.muted)
                    if let cover = RecipePhotos.load(current, from: library) {
                        Image(uiImage: cover.image).resizable().scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Current recipe cover")
                            .accessibilityIdentifier("current-cover")
                        Button("Crop the current cover again") { candidates = [cover.image.jpegData(compressionQuality: 0.95)].compactMap { $0 }; cropping = true }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("recrop-cover")
                    } else {
                        Text("No cover yet.").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    PhotosPicker(selection: $picked, maxSelectionCount: 10, selectionBehavior: .ordered, matching: .images) {
                        Label(loading ? "Loading…" : "Choose from Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(loading)
                    .accessibilityIdentifier("cover-from-photos")
                    if let plate = RecipePhotos.loadPlate(current, from: library) {
                        Button("Use your plate photo") { candidates = [plate.jpegData(compressionQuality: 0.95)].compactMap { $0 }; cropping = true }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("cover-from-plate")
                    }
                    if current.originalCoverFilename != nil {
                        // The app cropped a video's ▶ out of this cover; the
                        // picture as it came is one tap away (A2, build 20).
                        Text("We trimmed the video’s play button off this cover.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Use the original picture") {
                            if library.restoreOriginalCover(for: recipe.id) { problem = nil } else { problem = library.saveError ?? "The original picture couldn’t be restored." }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("restore-original-cover")
                    }
                    if current.imageFilename != nil {
                        Button("Remove cover") {
                            if library.removeCover(for: recipe.id) { dismiss() } else { problem = library.saveError }
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("remove-cover")
                    }
                    if let problem {
                        Text(problem).font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("cover-edit-error")
                    }
                }
                .padding(24)
            }
            .background(Theme.cream)
            .navigationTitle("Cover photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("cover-edit-done") } }
        }
        .tint(Theme.tomato)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            loading = true
            Task {
                var loaded: [Data] = []
                for item in items { if let data = try? await item.loadTransferable(type: Data.self) { loaded.append(data) } }
                loading = false
                picked = []
                if loaded.isEmpty { problem = "Those photos couldn’t be loaded. Try choosing them again." }
                else { candidates = loaded; cropping = true }
            }
        }
        .sheet(isPresented: $cropping) {
            ScreenshotCoverSheet(load: { candidates }) { data in
                if library.saveImage(data, for: recipe.id) == nil { problem = library.saveError } else { problem = nil; saved = true }
            }
            .uiTestTypeSize()
        }
        // Close once the crop sheet has gone, not underneath it.
        .onChange(of: cropping) { _, open in if !open && saved { dismiss() } }
    }
}

/// The recipe page's cook buttons: the big pill on a page of its own, a
/// quiet one on the Duo's cookbook spread (A2-59: no giant plan button there).
private struct CookBarStyle: ButtonStyle {
    var book: Bool
    var onColoredPage: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if book {
            QuietButtonStyle().makeBody(configuration: configuration)
                .frame(maxWidth: .infinity)
        } else {
            BigButtonStyle(onColoredPage: onColoredPage).makeBody(configuration: configuration)
        }
    }
}
