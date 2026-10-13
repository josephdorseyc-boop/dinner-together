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
        return LaunchOptions.forcedColorScheme // nil in Release
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
                    NavigationStack { PlanView(goCooking: { destination = .cooking }, goRecipes: { destination = .recipes }, openRecipe: openRecipe) }
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
            })
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if destination == .cooking {
            CookingView()
        } else {
            PlanView(goCooking: { destination = .cooking },
                     goRecipes: { destination = .recipes },
                     openRecipe: openRecipe)
        }
    }
}
