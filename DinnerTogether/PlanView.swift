import SwiftUI
import UIKit

/// "Tonight": pick when dinner is, inspect each menu's dishes and steps,
/// adjust estimates before cooking, then head to the kitchen.
struct PlanView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var goCooking: () -> Void
    var goRecipes: () -> Void
    /// Opens one of the cook's recipes on its page (Recipes tab / sidebar).
    var openRecipe: ((UUID) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feasibility: Feasibility = .ok
    @State private var pendingMenuID: String?
    /// One sheet presenter for the page: the duration editor or the week's
    /// day sheet. A second `.sheet` — on this view or inside its scroll
    /// view — never appeared (runs 38497304286 and 38508449584).
    enum PageSheet: Identifiable {
        case step(CookingStep), day(PlanDay)
        var id: String {
            switch self {
            case .step(let s): return "step-" + s.id
            case .day(let d): return "day-" + d.date.description
            }
        }
    }
    @State private var sheet: PageSheet?

    private var hasProgress: Bool {
        store.session.records.values.contains { $0.state != .notStarted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                servingTimeCard
                tonightsRecipe
                Button(action: goRecipes) {
                    Label(tonightRecipe == nil ? "Choose from Recipes" : "Choose a different recipe", systemImage: "book.closed")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("open-recipes")
                // The week sits below tonight's time and recipe choice, above
                // the classics (Joe, October 13).
                WeekStrip(chooseToday: chooseFromWeek, openDay: { sheet = .day($0) })
                SectionLabel(text: "ON THE MENU")
                ForEach(DinnerCatalog.menus) { menu in
                    menuCard(menu)
                }
                Text("Timings are planning estimates, not complete tested recipes. Use your trusted recipes and verify doneness separately.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.cream)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Text("Selected: \(store.menu.title)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button(action: {
                    // Recompute feasibility right before entering cooking —
                    // duration edits can invalidate the serving time.
                    recheckFeasibility()
                    if hasProgress || feasibility == .ok { goCooking(); return }
                    // Never a silent no-op (Joe, build 8). The label already
                    // named the time, so moving dinner to it is what was asked.
                    if case .startsInPast(let earliest) = feasibility {
                        store.setServeAt(earliest)
                        recheckFeasibility()
                        goCooking()
                    }
                }) {
                    Label(primaryActionTitle, systemImage: "arrow.right")
                }
                .buttonStyle(BigButtonStyle())
                .accessibilityHint("Opens your cooking timeline.")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(Theme.cream)
        }
        .navigationTitle("Dinner, Together")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recheckFeasibility() }
        .sensoryFeedback(.selection, trigger: store.session.menuID)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: store.session.menuID)
        .sheet(item: $sheet) { which in
            switch which {
            case .step(let step):
                DurationEditorView(step: step,
                    initialMinutes: store.session.durationOverrides[step.id] ?? step.minutes) { minutes in
                    store.setDuration(stepID: step.id, minutes: minutes)
                    recheckFeasibility()
                    return nil // the session store reports its own save problems
                }
                .uiTestTypeSize()
            case .day(let day):
                DayPlanSheet(day: day, chooseToday: chooseFromWeek).uiTestTypeSize()
            }
        }
        .confirmationDialog(
            "Change dinner and clear progress?",
            isPresented: Binding(
                get: { pendingMenuID != nil },
                set: { if !$0 { pendingMenuID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Change dinner", role: .destructive) {
                if let id = pendingMenuID { store.chooseMenu(id) }
                pendingMenuID = nil
                recheckFeasibility()
            }
            Button("Cancel", role: .cancel) { pendingMenuID = nil }
        }
    }

    private var primaryActionTitle: String {
        if hasProgress { return "Back to cooking" }
        if case .startsInPast(let earliest) = feasibility {
            return "Build plan for \(Scheduling.formatTime(earliest))"
        }
        return "Build my cooking plan"
    }

    // MARK: Sections

    /// The cook's own recipe when it is tonight's dinner.
    private var tonightRecipe: Recipe? { library.recipe(menuID: store.session.menuID) }

    /// Tonight names the dish when it is one of the cook's recipes, right
    /// above the catalog (Joe, build 10: "it should tell you which recipe
    /// you're making on the home page"). Tapping opens the recipe.
    @ViewBuilder
    private var tonightsRecipe: some View {
        if let recipe = tonightRecipe {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "TONIGHT’S DINNER")
                Button {
                    if let openRecipe { openRecipe(recipe.id) } else { goRecipes() }
                } label: {
                    // The cover leads when there is one (A2-35); accessibility
                    // sizes keep the row with its small thumbnail, so the
                    // title is never squeezed by a photo.
                    if !dynamicTypeSize.isAccessibilitySize, let cover = RecipePhotos.load(recipe, from: library) {
                        TonightCoverCard(recipe: recipe, image: cover.image, palette: cover.palette,
                                         bandHeight: horizontalSizeClass == .regular ? 160 : 120)
                    } else {
                        RecipeRow(recipe: recipe, selected: true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tonight-recipe")
                .accessibilityHint("Opens the recipe.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dinner, beautifully timed.")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
            Text("Choose your dinner. We’ll bring the timing together.")
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    /// The app's promise, first and loudest (Joe, October 13): when dinner
    /// is on the table, and whether that time is realistic for this menu.
    /// A deep warm card on the cream page — fixed colors, so it stands out
    /// in Light and Dark alike — with the time large, when to start, or the
    /// earliest realistic time with a one-tap fix.
    private var servingTimeCard: some View {
        let cream = Color(red: 0.965, green: 0.945, blue: 0.890)
        let apricot = PageText.accent.color
        let minutes = menuMinutes(store.menu)
        let startBy = store.session.serveAt.addingTimeInterval(-Double(minutes) * 60)
        return VStack(alignment: .leading, spacing: 14) {
            Text("DINNER ON THE TABLE")
                .font(.caption.weight(.semibold)).tracking(1.4)
                .foregroundStyle(cream.opacity(0.85))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.session.serveAt, format: .dateTime.hour().minute())
                    .font(.system(size: 60, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(cream)
                    .accessibilityIdentifier("table-time")
                Text(store.session.serveAt, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline).foregroundStyle(cream.opacity(0.85))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Dinner on the table at \(Scheduling.formatMoment(store.session.serveAt))")

            if hasProgress {
                Label("You’re cooking. Change the time from Cooking with Adjust time or Review dinner time.", systemImage: "flame")
                    .font(.subheadline).foregroundStyle(cream)
                    .fixedSize(horizontal: false, vertical: true)
            } else if case .startsInPast(let earliest) = feasibility {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Too soon for this menu. Starting now, the earliest realistic time is \(Scheduling.formatMoment(earliest)).",
                          systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(apricot)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Use \(Scheduling.formatMoment(earliest))") {
                        store.setServeAt(earliest)
                        recheckFeasibility()
                    }
                    .buttonStyle(BigButtonStyle(onColoredPage: true))
                    .accessibilityIdentifier("use-earliest-time")
                }
                .accessibilityIdentifier("table-time-too-soon")
            } else {
                Label("Start cooking by \(Scheduling.formatMoment(startBy)) · about \(Scheduling.formatMinutes(minutes)) of cooking",
                      systemImage: "clock")
                    .font(.subheadline.weight(.medium)).foregroundStyle(apricot)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("table-time-start-by")
            }

            DatePicker(
                "Change dinner time",
                selection: Binding(
                    get: { store.session.serveAt },
                    set: { store.setServeAt($0); recheckFeasibility() }
                ),
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .foregroundStyle(cream)
            .tint(apricot)
            .environment(\.colorScheme, .dark)
            .disabled(hasProgress)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.tableSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Deep espresso in Light Mode, a lifted warm brown in Dark Mode (so it
    /// still stands off the dark page). Cream text ≥ 9:1 on both.
    private static let tableSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.20, blue: 0.15, alpha: 1)
            : UIColor(red: 0.188, green: 0.169, blue: 0.145, alpha: 1)
    })

    private func menuCard(_ menu: DinnerMenu) -> some View {
        let selected = store.session.menuID == menu.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                guard menu.id != store.session.menuID else { return }
                if hasProgress { pendingMenuID = menu.id } else { store.chooseMenu(menu.id); recheckFeasibility() }
            } label: {
                HStack(spacing: 16) {
                    // The classic's illustrated plate (Joe, October 13).
                    PlateIllustration(menuID: menu.id)
                        .frame(width: 50, height: 50)
                        .overlay(Circle().stroke(selected ? Theme.tomato.opacity(0.7) : .clear, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(menu.title).font(.headline)
                        Text(menu.subtitle).font(.caption).foregroundStyle(Theme.muted)
                        Text("About \(Scheduling.formatMinutes(menuMinutes(menu))) · \(menu.dishes.count) dishes")
                            .font(.caption).foregroundStyle(Theme.olive)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.tomato : Theme.line)
                        .font(.title3)
                }
                .foregroundStyle(Theme.ink)
                .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(menu.title), \(menu.subtitle)")
            .accessibilityAddTraits(selected ? .isSelected : [])

            if menu.id == "thanksgiving" {
                Text("Holiday guide: about 4 hours with the preset estimates. Match the roast time to your recipe. Check shared oven space and temperatures, and plan help for the final sides; the app flags overlaps but does not resolve them.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            Divider().padding(.horizontal, 16)

            DisclosureGroup("Dishes & timing") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(menu.dishes, id: \.self) { dish in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dish.first?.dish ?? "")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.olive)
                            ForEach(dish) { step in
                                durationRow(menu, step)
                            }
                        }
                        .padding(.top, 6)
                    }
                    Text("Estimates, not recipes — adjust any step to match your kitchen.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 8)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .tint(Theme.olive)
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(selected ? Theme.tomato.opacity(0.65) : .clear, lineWidth: 1.25)
        )
    }

    private func durationRow(_ menu: DinnerMenu, _ step: CookingStep) -> some View {
        let selected = store.session.menuID == menu.id
        let minutes = store.session.durationOverrides[step.id] ?? step.minutes
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title).font(.subheadline)
                if !step.handsOn {
                    Text("Hands-off").font(.caption).foregroundStyle(Theme.olive)
                }
            }
            Spacer()
            // Previews are read-only until the menu is selected: duration
            // controls on an unselected menu used to silently do nothing
            // useful. Select the menu first, then adjust.
            if selected {
                Button { sheet = .step(step) } label: {
                    Label("\(Scheduling.formatMinutes(minutes))", systemImage: "pencil")
                }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Edit \(step.title) estimate, \(minutes) minutes")
                    .disabled(hasProgress)
            } else {
                Text("\(Scheduling.formatMinutes(step.minutes))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func menuMinutes(_ menu: DinnerMenu) -> Int {
        guard menu.id == store.session.menuID else { return menu.longestDishMinutes }
        return menu.dishes.map { dish in
            dish.reduce(0) { total, step in
                total + Scheduling.effectiveMinutes(step, durations: store.session.durationOverrides)
            }
        }.max() ?? menu.longestDishMinutes
    }

    private func chooseFromWeek(_ id: String) {
        guard id != store.session.menuID else { return }
        if hasProgress { pendingMenuID = id } else { store.chooseMenu(id); recheckFeasibility() }
    }

    private func recheckFeasibility() {
        feasibility = Scheduling.checkFeasibility(
            menu: store.menu,
            serveAt: store.session.serveAt,
            durations: store.session.durationOverrides,
            now: Date()
        )
    }
}
