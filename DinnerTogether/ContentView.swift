import SwiftUI
import UIKit

/// Root view. iPhone gets the Tonight, Cooking and Recipes tabs; iPad gets a sidebar with a
/// genuinely wider detail layout instead of a stretched phone screen. The
/// opened iPhone Duo is a phone with a regular-width window (951 × 669, run
/// 38766905435): it keeps the tabs, so the cookbook spread has the whole
/// screen as in the approved mockups (Joe, October 15: no sidebar there).
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

    /// The sidebar is iPad's: a regular-width window on a phone (the opened
    /// Duo) keeps the tabs, whose bar the system puts in its rail.
    private var usesSidebar: Bool {
        horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom != .phone
    }

    /// The folded Duo turned sideways (A2-63; Joe, October 15, 1:12 PM):
    /// its cover display's landscape window — short side under 600 pt —
    /// shows This Week, the week's hero photos to swipe through, over an
    /// idle Tonight. Ordinary iPhones stay upright (AppDelegate), so only
    /// the Duo's cover gets here; the opened Duo (669 short) keeps Tonight.
    @State private var windowSize: CGSize = .zero
    /// Done: not again until the window stops being the sideways cover
    /// (turned upright or opened).
    @State private var showcaseDone = false

    private var sidewaysCover: Bool {
        let short = min(windowSize.width, windowSize.height)
        return UIDevice.current.userInterfaceIdiom == .phone
            && windowSize.width > windowSize.height && short > 0 && short < 600
    }

    /// Only from an idle Tonight: never over Cooking, a recipe, an import,
    /// the stale-plan choice or a dinner in progress.
    private var showsWeekShowcase: Bool {
        sidewaysCover && !showcaseDone && destination == .tonight
            && !store.hasProgress && library.pendingShare == nil && !store.needsStaleChoice
    }

    @State private var recipePath: [UUID] = []
    /// The Add recipe sheet, in the Recipes destination; Tonight opens it
    /// too when the cookbook is empty.
    @State private var addingRecipe = false

    /// A colored recipe page draws from its own colors — light text and dark
    /// chrome on a deep page, dark text and light chrome on a pale one. Keep
    /// the decision at the window so the status bar, sidebar and tab bar
    /// agree (A2-23); leaving the page returns to the system/test
    /// appearance. Applied as the window's style (`WindowStyle`), never as
    /// a root `.preferredColorScheme`: that took the clock away from
    /// Tonight's dark top bar — in the forced-Light captures (A2-54) and,
    /// after a pale recipe page, on Joe's iPhone (build 18).
    private var preferredPresentationScheme: ColorScheme? {
        if destination == .recipes,
           let id = recipePath.last,
           let recipe = library.recipe(id: id) {
            // No palette is the classic cream page: cream, so light, in Dark
            // Mode too (Joe, build 19).
            guard let palette = RecipePhotos.palette(for: recipe, from: library) else { return .light }
            return palette.tone == .deep ? .dark : .light
        }
        // Dark Mode is Tonight's alone (Joe, October 15: "a dark mode but
        // only on the Tonight page at night"): Tonight follows the phone (or
        // the tests' forced appearance); Cooking and Recipes stay cream.
        return destination == .tonight ? nil : .light
    }

    var body: some View {
        Group {
            if usesSidebar {
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
        // Behind the showcase, Tonight is out of VoiceOver's reach too.
        .accessibilityHidden(showsWeekShowcase)
        .overlay {
            if showsWeekShowcase {
                ZStack {
                    // Takes every touch the photos let through.
                    Color.black.ignoresSafeArea()
                    WeekShowcaseView(
                        onDone: { showcaseDone = true },
                        openDinner: { id in
                            // Read, never choose or cook: the main dish's page.
                            if let main = WholeMeal.recipeIDs(id)?.first { openRecipe(main) }
                        },
                        chooseToday: { id in
                            guard id != store.session.menuID, !store.hasProgress else { return }
                            store.chooseMenu(id)
                        },
                        changeTodayDishes: { id in
                            guard !store.hasProgress else { return }
                            store.changeDishes(to: id)
                        })
                }
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
            }
        }
        .background {
            GeometryReader { g in
                Color.clear
                    .onAppear { windowSize = g.size }
                    .onChange(of: g.size) { _, size in windowSize = size }
            }
            .ignoresSafeArea()
        }
        .onChange(of: sidewaysCover) { _, sideways in
            if !sideways { showcaseDone = false }
        }
        // The colored page's scheme — or, off such a page, the tests' forced
        // appearance (Debug; nil in Release) or else the system's — as this
        // window's own style.
        .background(WindowStyle(scheme: preferredPresentationScheme ?? LaunchOptions.forcedColorScheme))
        // Video-post covers saved with a baked-in ▶ (Joe, build 19).
        .task { library.cleanVideoCovers() }
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

/// Sets the hosting window's `overrideUserInterfaceStyle` — the way the
/// system's own Light/Dark setting applies — and has the status bar re-read
/// its style. Build 18 set a colored recipe page's scheme as a root
/// `.preferredColorScheme`; back on Tonight after a pale page (Whipped
/// Frozen Apple Cider on Joe's iPhone) the clock stayed black over the
/// photo, because nothing asked the status bar again once that scheme
/// went back to nil. Per window, so a second iPad window keeps its own.
private struct WindowStyle: UIViewRepresentable {
    var scheme: ColorScheme?

    func makeUIView(context: Context) -> Probe { Probe() }

    func updateUIView(_ probe: Probe, context: Context) {
        switch scheme {
        case .dark?: probe.style = .dark
        case .light?: probe.style = .light
        default: probe.style = .unspecified
        }
    }

    final class Probe: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { if style != oldValue { scheduleApply() } }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleApply()
        }

        /// After the SwiftUI update in progress: changing the window's
        /// traits inside it would start another one.
        private func scheduleApply() {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        private func apply() {
            guard let window else { return }
            if window.overrideUserInterfaceStyle != style { window.overrideUserInterfaceStyle = style }
            var controller = window.rootViewController
            while let current = controller {
                current.setNeedsStatusBarAppearanceUpdate()
                controller = current.presentedViewController
            }
        }
    }
}
