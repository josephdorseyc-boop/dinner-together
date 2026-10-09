import SwiftUI

/// Root view. iPhone gets the familiar two tabs; iPad gets a sidebar with a
/// genuinely wider detail layout instead of a stretched phone screen.
struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Debug launch option `-dt-open-cooking` starts on the Cooking screen
    // (simulator screenshots). Release builds always start on Tonight.
    @State private var tab = LaunchOptions.openCooking ? 1 : 0
    @State private var sidebarSelection: String? = LaunchOptions.openCooking ? "cooking" : "tonight"

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    List(selection: $sidebarSelection) {
                        Label("Tonight", systemImage: "fork.knife").tag("tonight")
                        Label("Cooking", systemImage: "timer").tag("cooking")
                    }
                    .navigationTitle("Dinner, Together")
                } detail: {
                    NavigationStack { detailView }
                }
            } else {
                TabView(selection: $tab) {
                    NavigationStack { PlanView(goCooking: { tab = 1 }) }
                        .tabItem { Label("Tonight", systemImage: "fork.knife") }
                        .tag(0)
                    NavigationStack { CookingView() }
                        .tabItem { Label("Cooking", systemImage: "timer") }
                        .tag(1)
                }
                .toolbarBackground(Theme.cream, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(Theme.tomato)
        .sheet(isPresented: $store.needsStaleChoice) {
            StalePlanView()
                .presentationDetents([.medium])
                // The stale-plan choice is explicit: no swipe-to-dismiss bypass.
                .interactiveDismissDisabled()
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

    @ViewBuilder
    private var detailView: some View {
        if sidebarSelection == "cooking" {
            CookingView()
        } else {
            PlanView(goCooking: { sidebarSelection = "cooking" })
        }
    }
}
