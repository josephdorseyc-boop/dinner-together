import SwiftUI

/// Root view. iPhone gets the Tonight, Cooking and Recipes tabs; iPad gets a sidebar with a
/// genuinely wider detail layout instead of a stretched phone screen.
struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Debug launch option `-dt-open-cooking` starts on the Cooking screen
    // (simulator screenshots). Release builds always start on Tonight.
    private enum Destination: Hashable {
        case tonight, cooking, recipes
    }
    // One destination survives compact/regular layout changes. Separate tab
    // and sidebar state could reopen the other layout on an older screen.
    @State private var destination: Destination = LaunchOptions.openCooking ? .cooking : .tonight

    private var sidebarSelection: Binding<Destination?> {
        Binding(get: { destination }, set: { next in
            if let next { destination = next }
        })
    }

    @State private var recipePath: [UUID] = []
    /// The Add recipe sheet, in the Recipes destination; Tonight opens it
    /// too when the cookbook is empty.
    @State private var addingRecipe = false

    /// A colored recipe page draws from its own colors — light text and dark
    /// chrome on a deep page, dark text and light chrome on a pale one. Keep
    /// the decision at the presentation root so the status bar, sidebar and
    /// tab bar agree (A2-23); leaving the page returns to the system/test
    /// appearance.
    private var preferredPresentationScheme: ColorScheme? {
        if destination == .recipes,
           let id = recipePath.last,
           let recipe = library.recipe(id: id),
           let palette = RecipePhotos.palette(for: recipe, from: library) {
            return palette.tone == .deep ? .dark : .light
        }
        // The UI tests' forced Light/Dark is a window setting, like the
        // system's (`LaunchOptions.applyForcedAppearance`): as a root color
        // scheme it overrode the top bar's say over the clock, which then
        // stayed black over Tonight's photo in every forced-Light capture
        // (A2-54, run 38628522264).
        return nil
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    List(selection: sidebarSelection) {
                        Label("Tonight", systemImage: "fork.knife").tag(Destination.tonight)
                        Label("Cooking", systemImage: "timer").tag(Destination.cooking)
                        Label("Recipes", systemImage: "book.closed").tag(Destination.recipes)
                    }
                    .navigationTitle("Dinner, Together")
                } detail: {
                    if destination == .recipes {
                        recipeNavigation
                    } else {
                        NavigationStack { detailView }
                    }
                }
            } else {
                TabView(selection: $destination) {
                    NavigationStack { planView }
                        .tabItem { Label("Tonight", systemImage: "fork.knife") }
                        .tag(Destination.tonight)
                    NavigationStack { CookingView() }
                        .tabItem { Label("Cooking", systemImage: "timer") }
                        .tag(Destination.cooking)
                    recipeNavigation
                        .tabItem { Label("Recipes", systemImage: "book.closed") }
                        .tag(Destination.recipes)
                }
                .toolbarBackground(Theme.cream, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(Theme.tomato)
        .preferredColorScheme(preferredPresentationScheme)
        .onAppear { LaunchOptions.applyForcedAppearance() }
        // Leaving a colored recipe page resets the window's style; put the
        // tests' forced appearance back (Debug only; nothing in Release).
        .onChange(of: preferredPresentationScheme) { _, scheme in
            if scheme == nil { LaunchOptions.applyForcedAppearance() }
        }
        // Share → "Dinner, Together" from another app: the inbox item opens
        // Add recipe already filled in; the new recipe's page follows.
        .sheet(item: $library.pendingShare) { share in
            AddRecipeSheet(shared: share) { id in openRecipe(id) }
                .uiTestTypeSize()
        }
        .sheet(isPresented: $store.needsStaleChoice) {
            StalePlanView()
                .presentationDetents([.medium])
                // The stale-plan choice is explicit: no swipe-to-dismiss bypass.
                .interactiveDismissDisabled()
                .uiTestTypeSize()
        }
        .alert("Couldn't save",
               isPresented: Binding(
                   get: { store.saveError != nil },
                   set: { if !$0 { store.saveError = nil } }
               )
        ) {
            Button("Try again") { store.save() }
            Button("Dismiss", role: .cancel) { store.saveError = nil }
        } message: {
            Text(store.saveError ?? "")
        }
    }

    /// Tonight's recipe card → its page in the Recipes destination.
    private func openRecipe(_ id: UUID) {
        recipePath = [id]
        destination = .recipes
    }

    private var recipeNavigation: some View {
        NavigationStack(path: $recipePath) {
            RecipesView(path: $recipePath, goTonight: {
                recipePath.removeAll()
                destination = .tonight
            }, goCooking: {
                destination = .cooking
            }, adding: $addingRecipe)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if destination == .cooking {
            CookingView()
        } else {
            planView
        }
    }

    private var planView: some View {
        PlanView(goCooking: { destination = .cooking },
                 goRecipes: { destination = .recipes },
                 addRecipe: { recipePath.removeAll(); destination = .recipes; addingRecipe = true },
                 openRecipe: openRecipe)
    }
}
