import SwiftUI
import UIKit

/// The recipe page, or — with the phone open like a book — the cookbook
/// spread (Joe and A2, October 14): RIGHT the main recipe, the page as it
/// always was; LEFT the cover photo edge to edge, or a second recipe to
/// read alongside. The right page is the same view either way, so folding
/// and unfolding keep its tab and scroll position; what the left shows
/// never touches it. `SpreadLayout` decides from the window's geometry.
struct RecipeSpreadView: View {
    let recipeID: UUID
    var onChoose: (() -> Void)? = nil
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var leftPage: SpreadLeftPage = .cover
    @State private var choosingSecond = false
    /// `.book` mode: the side dish is the page in front.
    @State private var showingSide = false

    var body: some View {
        GeometryReader { g in
            // The window's own size: the bars are inside it.
            let mode = SpreadLayout.mode(
                width: g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing,
                height: g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom,
                phoneIdiom: UIDevice.current.userInterfaceIdiom == .phone,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize)
            let half = (g.size.width / 2).rounded(.down)
            let side = mode == .book ? leftPage.secondRecipeID : nil
            let sideInFront = side != nil && showingSide
            HStack(spacing: 0) {
                if mode == .spread {
                    leftPane(pageWidth: half)
                        .frame(width: half)
                        .clipped()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("spread-left")
                    // The spine.
                    Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
                        .accessibilityHidden(true)
                }
                ZStack(alignment: .top) {
                    // Always in this position, so its identity — tab, scroll,
                    // sheets — survives the spread opening and closing.
                    RecipeDetailView(recipeID: recipeID, onChoose: onChoose,
                                     bookPage: mode != .single,
                                     pageWidth: mode == .spread ? half : g.size.width,
                                     inBackground: sideInFront,
                                     roleLabel: side != nil ? "MAIN DISH" : nil)
                        .opacity(sideInFront ? 0 : 1)
                        .allowsHitTesting(!sideInFront)
                        .accessibilityHidden(sideInFront)
                    // The side dish, kept in place behind the main page so
                    // each keeps its own tab and scroll (A2-59).
                    if let side {
                        RecipeDetailView(recipeID: side, onChoose: onChoose, role: .reader, pairMain: recipeID,
                                         bookPage: true, pageWidth: g.size.width, roleLabel: "SIDE DISH")
                            .id(side)
                            .opacity(sideInFront ? 1 : 0)
                            .allowsHitTesting(sideInFront)
                            .accessibilityHidden(!sideInFront)
                    }
                }
                .frame(maxWidth: .infinity)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if mode == .book { bookSwitch(side: side) }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            .sheet(isPresented: $choosingSecond) {
                RecipePickerSheet(excluding: [recipeID], current: leftPage.secondRecipeID) { id in
                    leftPage = .recipe(id)
                    showingSide = true
                }
                .uiTestTypeSize()
            }
            // A deleted second recipe gives way to the cover.
            .onChange(of: library.recipes.map(\.id)) { _, ids in
                leftPage = leftPage.settled { ids.contains($0) }
                if leftPage.secondRecipeID == nil { showingSide = false }
            }
        }
    }

    /// A near-square screen — the Duo's cover display either way up, or the
    /// opened Duo held upright (Joe, October 15): one cookbook page, and a
    /// quiet switch between the main recipe and a side dish read alongside.
    /// Its bar is frosted, so a colored page shows through as under the
    /// system's own glass rail (Joe, October 15, 10:45 AM).
    @ViewBuilder
    private func bookSwitch(side: UUID?) -> some View {
        HStack(spacing: 16) {
            if side != nil {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    switchTab("Main", selected: !showingSide, id: "book-switch-main") { showingSide = false }
                    switchTab("Side", selected: showingSide, id: "book-switch-side") { showingSide = true }
                }
                .padding(3)
                .background(Capsule().fill(Theme.line.opacity(0.6)))
                Spacer(minLength: 0)
                Menu {
                    Button { choosingSecond = true } label: { Label("Change side dish", systemImage: "arrow.left.arrow.right") }
                    Button { leftPage = .cover; showingSide = false } label: { Label("Close side dish", systemImage: "xmark") }
                } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.semibold)).foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Side dish options")
                .accessibilityIdentifier("book-side-options")
            } else {
                Spacer(minLength: 0)
                Button { choosingSecond = true } label: {
                    Label("Add a side dish", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(library.recipes.count < 2)
                .accessibilityHint("Reads another of your recipes alongside this one.")
                .accessibilityIdentifier("book-add-side")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    /// One half of the Main / Side capsule (approved mockup 04): olive with
    /// cream text when chosen, quiet otherwise.
    private func switchTab(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.cream : Theme.ink)
                .padding(.horizontal, 22).frame(minHeight: 44)
                .background(Capsule().fill(selected ? Theme.olive : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func leftPane(pageWidth: CGFloat) -> some View {
        switch leftPage {
        case .cover:
            SpreadCoverPage(recipeID: recipeID) { choosingSecond = true }
        case .recipe(let id):
            VStack(spacing: 0) {
                // As in the approved mockup (Joe, October 14, "03 / Two
                // recipes, side by side"): the way back to the photo first.
                HStack(spacing: 8) {
                    Button { leftPage = .cover } label: {
                        Label("Show cover photo", systemImage: "photo").lineLimit(1)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityIdentifier("spread-show-cover")
                    Spacer(minLength: 8)
                    Button { choosingSecond = true } label: {
                        Label("Change", systemImage: "arrow.left.arrow.right").labelStyle(.iconOnly)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Change the second recipe")
                    .accessibilityIdentifier("spread-change-second")
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Theme.cream)
                Text("SIDE DISH")
                    .font(.caption.weight(.semibold)).tracking(1.6)
                    .foregroundStyle(Theme.tomato)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.top, 6)
                    .background(Theme.cream)
                    .accessibilityAddTraits(.isHeader)
                Divider()
                RecipeDetailView(recipeID: id, onChoose: onChoose, role: .reader, pairMain: recipeID,
                                 bookPage: true, pageWidth: pageWidth)
                    .id(id) // a different recipe starts at its own first tab
            }
        }
    }
}

/// The spread's default LEFT page: the main recipe's photo edge to edge
/// (its plate photo, then its cover), nothing over it but a
/// discreet "…" to read a second recipe alongside. A recipe without a
/// photo gets a warm page with its title large.
struct SpreadCoverPage: View {
    let recipeID: UUID
    var addSecond: () -> Void
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore

    private var recipe: Recipe? { library.recipe(id: recipeID) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let recipe, let photo = RecipePhotos.hero(recipe, from: library)?.image {
                Color.clear
                    .overlay(Image(uiImage: photo).resizable().scaledToFill())
                    .clipped()
                    .accessibilityElement()
                    .accessibilityLabel("Photo of \(recipe.title)")
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("spread-cover-photo")
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                                       .init(color: .black.opacity(0.55), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 260)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            } else {
                Theme.cream
                VStack(alignment: .leading, spacing: 12) {
                    Label("FROM YOUR COLLECTION", systemImage: "book.closed")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.olive)
                    Text(recipe?.title ?? "")
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            // The opened Duo reading one recipe (Joe approved the consolidated
            // boards, October 15, 11:58 AM): the photo full-bleed with a
            // minimal title low on it; a small "Tonight" when it is tonight's
            // dinner, and the "…" for a second recipe. The reading itself is
            // on the right page.
            if let recipe {
                let onPhoto = RecipePhotos.hero(recipe, from: library) != nil
                VStack(alignment: .leading, spacing: 10) {
                    if store.isTonightsDish(recipe.id) && onPhoto {
                        Text("Tonight")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                            .accessibilityIdentifier("spread-tonight-tag")
                    }
                    Spacer()
                    if onPhoto {
                        // Read once, on the right page: decorative here.
                        Text(recipe.title)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("spread-cover-title")
                    }
                    Menu {
                        // After the menu has closed: a sheet asked for while it
                        // is closing does not appear (as the page's ••• does).
                        Button {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                addSecond()
                            }
                        } label: { Label("Add a second recipe", systemImage: "plus") }
                            .disabled(library.recipes.count < 2)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.32)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .accessibilityLabel("Page options")
                    .accessibilityHint("Read a second recipe on this page.")
                    .accessibilityIdentifier("spread-more")
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(recipe.title)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Which of the cook's recipes reads alongside the main one.
/// The cook's recipes, favorites first, searchable by title or ingredient
/// — to read alongside on the spread, or to add to tonight's dinner (build
/// 21). `excluding`: recipes already in play; `current`: the one chosen now.
struct RecipePickerSheet: View {
    var title = "Second recipe"
    var header = "Read alongside — a side dish, a sauce, dessert."
    var emptyText = "Add another recipe to read one alongside."
    var excluding: [UUID] = []
    var current: UUID?
    /// "+ Add a new recipe" at the foot: imported, then chosen (A2-63).
    var allowsNewRecipe = false
    /// A reason a recipe can't be chosen yet, shown under its name.
    var blocked: (Recipe) -> String? = { _ in nil }
    var choose: (UUID) -> Void
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var adding = false
    private var shown: [Recipe] { library.recipesFavoritesFirst.filter { !excluding.contains($0.id) && $0.matches(query) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if shown.isEmpty {
                        Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? emptyText
                             : "No recipe matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))” by title or ingredient.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .listRowBackground(Theme.paper)
                    }
                    ForEach(shown) { recipe in
                        let reason = blocked(recipe)
                        Button {
                            choose(recipe.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 12) {
                                    RecipeRow(recipe: recipe, selected: store.isTonightsDish(recipe.id))
                                    if recipe.id == current {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.tomato)
                                            .accessibilityLabel("Reading now")
                                    }
                                }
                                if let reason {
                                    Text(reason).font(.caption).foregroundStyle(Theme.warning)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(reason != nil)
                        .listRowBackground(Theme.paper)
                        .accessibilityIdentifier("pick-recipe")
                    }
                    if allowsNewRecipe {
                        Button { adding = true } label: {
                            Label("Add a new recipe", systemImage: "plus.circle.fill")
                                .font(.headline).foregroundStyle(Theme.tomato)
                                .frame(minHeight: 44)
                        }
                        .listRowBackground(Theme.paper)
                        .accessibilityIdentifier("pick-add-recipe")
                    }
                } header: {
                    Text(header)
                        .font(.subheadline).foregroundStyle(Theme.muted).textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title or ingredient")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $adding) {
                // A new recipe's timing is checked on its page first (the
                // day sheet's rule); it waits in this list, marked so.
                AddRecipeSheet { id in
                    if let recipe = library.recipe(id: id), blocked(recipe) == nil { choose(id); dismiss() }
                }
                .uiTestTypeSize()
            }
        }
        .presentationDetents([.medium, .large])
    }
}
