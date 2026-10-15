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
                HStack(spacing: 8) {
                    Label("Reading alongside", systemImage: "book")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Button { choosingSecond = true } label: {
                        Label("Change", systemImage: "arrow.left.arrow.right").labelStyle(.iconOnly)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Change the second recipe")
                    .accessibilityIdentifier("spread-change-second")
                    Button { leftPage = .cover } label: {
                        Label("Cover photo", systemImage: "photo").lineLimit(1)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Show cover photo")
                    .accessibilityIdentifier("spread-show-cover")
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Theme.cream)
                Divider()
                RecipeDetailView(recipeID: id, role: .reader)
                    .id(id) // a different recipe starts at its own first tab
            }
        }
    }
}

/// The spread's default LEFT page: the main recipe's photo edge to edge
/// (its plate photo, then its cover), the title and byline on it, and a
/// discreet way to read a second recipe alongside. A recipe without a
/// photo gets a warm page with its title large.
struct SpreadCoverPage: View {
    let recipeID: UUID
    var addSecond: () -> Void
    @EnvironmentObject private var library: RecipeLibrary

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
                    Spacer()
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if let recipe {
                let onPhoto = RecipePhotos.hero(recipe, from: library) != nil
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.title)
                            .font(.system(onPhoto ? .title : .largeTitle, design: .serif).weight(.semibold))
                            .foregroundStyle(onPhoto ? .white : Theme.ink)
                            .shadow(color: .black.opacity(onPhoto ? 0.35 : 0), radius: 6, y: 1)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("spread-cover-title")
                        if let byline = recipe.source.byline {
                            Text(byline).font(.subheadline.weight(.medium))
                                .foregroundStyle(onPhoto ? .white.opacity(0.9) : Theme.muted)
                                .shadow(color: .black.opacity(onPhoto ? 0.35 : 0), radius: 4, y: 1)
                        }
                    }
                    Button(action: addSecond) {
                        Label("Add a second recipe", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .foregroundStyle(onPhoto ? .white : Theme.ink)
                            .background(onPhoto ? Color.white.opacity(0.18) : Theme.ink.opacity(0.06),
                                        in: Capsule())
                            .overlay(Capsule().strokeBorder((onPhoto ? Color.white : Theme.ink).opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(library.recipes.count < 2)
                    .accessibilityHint("Reads another of your recipes on this page.")
                    .accessibilityIdentifier("spread-add-second")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
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
