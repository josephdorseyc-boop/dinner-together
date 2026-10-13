import SwiftUI

/// Root view. iPhone gets the Tonight, Cooking and Recipes tabs; iPad gets a sidebar with a
/// genuinely wider detail layout instead of a stretched phone screen.
struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Debug launch option `-dt-open-cooking` starts on the Cooking screen
    // (simulator screenshots). Release builds always start on Tonight.
    @State private var tab = LaunchOptions.openCooking ? 1 : 0
    @State private var sidebarSelection: String? = LaunchOptions.openCooking ? "cooking" : "tonight"

    @State private var recipePath: [UUID] = []

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    List(selection: $sidebarSelection) {
                        Label("Tonight", systemImage: "fork.knife").tag("tonight")
                        Label("Cooking", systemImage: "timer").tag("cooking")
                        Label("Recipes", systemImage: "book.closed").tag("recipes")
                    }
                    .navigationTitle("Dinner, Together")
                } detail: {
                    if sidebarSelection == "recipes" {
                        recipeNavigation
                    } else {
                        NavigationStack { detailView }
                    }
                }
            } else {
                TabView(selection: $tab) {
                    NavigationStack { PlanView(goCooking: { tab = 1 }, goRecipes: { tab = 2 }, openRecipe: openRecipe) }
                        .tabItem { Label("Tonight", systemImage: "fork.knife") }
                        .tag(0)
                    NavigationStack { CookingView() }
                        .tabItem { Label("Cooking", systemImage: "timer") }
                        .tag(1)
                    recipeNavigation
                        .tabItem { Label("Recipes", systemImage: "book.closed") }
                        .tag(2)
                }
                .toolbarBackground(Theme.cream, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(Theme.tomato)
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
        tab = 2
        sidebarSelection = "recipes"
    }

    private var recipeNavigation: some View {
        NavigationStack(path: $recipePath) {
            RecipesView(path: $recipePath, goTonight: {
                recipePath.removeAll()
                tab = 0
                sidebarSelection = "tonight"
            }, goCooking: {
                tab = 1
                sidebarSelection = "cooking"
            })
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if sidebarSelection == "cooking" {
            CookingView()
        } else {
            PlanView(goCooking: { sidebarSelection = "cooking" },
                     goRecipes: { sidebarSelection = "recipes" },
                     openRecipe: openRecipe)
        }
    }
}
