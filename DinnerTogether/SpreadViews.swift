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

    var body: some View {
        GeometryReader { g in
            let spread = SpreadLayout.showsSpread(
                width: g.size.width, height: g.size.height,
                phoneIdiom: UIDevice.current.userInterfaceIdiom == .phone,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize)
            HStack(spacing: 0) {
                if spread {
                    leftPane
                        .frame(width: (g.size.width / 2).rounded(.down))
                        .clipped()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("spread-left")
                    // The spine.
                    Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
                        .accessibilityHidden(true)
                }
                // Always in this position, so its identity — tab, scroll,
                // sheets — survives the spread opening and closing.
                RecipeDetailView(recipeID: recipeID, onChoose: onChoose)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: g.size.width, height: g.size.height)
            .sheet(isPresented: $choosingSecond) {
                SecondRecipePicker(mainID: recipeID, current: leftPage.secondRecipeID) { id in
                    leftPage = .recipe(id)
                }
                .uiTestTypeSize()
            }
            // A deleted second recipe gives way to the cover.
            .onChange(of: library.recipes.map(\.id)) { _, ids in
                leftPage = leftPage.settled { ids.contains($0) }
            }
        }
    }

    @ViewBuilder
    private var leftPane: some View {
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
                RecipeDetailView(recipeID: id, role: .reader)
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
            // Mockup "01 / Photo-first cookbook": the photo says it all —
            // the title is on the right page; a small "Tonight" when it is
            // tonight's dinner, and the "…" for a second recipe.
            if let recipe {
                let onPhoto = RecipePhotos.hero(recipe, from: library) != nil
                VStack(alignment: .leading) {
                    if store.session.menuID == recipe.menuID && onPhoto {
                        Text("Tonight")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                            .accessibilityIdentifier("spread-tonight-tag")
                    }
                    Spacer()
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
private struct SecondRecipePicker: View {
    let mainID: UUID
    let current: UUID?
    var choose: (UUID) -> Void
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(library.recipes.filter { $0.id != mainID }) { recipe in
                        Button {
                            choose(recipe.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RecipeRow(recipe: recipe, selected: store.session.menuID == recipe.menuID)
                                if recipe.id == current {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.tomato)
                                        .accessibilityLabel("Reading now")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.paper)
                    }
                } header: {
                    Text("Read alongside — a side dish, a sauce, dessert. Dinner stays one recipe.")
                        .font(.subheadline).foregroundStyle(Theme.muted).textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle("Second recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
