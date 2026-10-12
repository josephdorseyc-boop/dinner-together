import SwiftUI

/// "Tonight": pick when dinner is, inspect each menu's dishes and steps,
/// adjust estimates before cooking, then head to the kitchen.
struct PlanView: View {
    @EnvironmentObject private var store: SessionStore
    var goCooking: () -> Void
    var goRecipes: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feasibility: Feasibility = .ok
    @State private var pendingMenuID: String?
    @State private var editingStep: CookingStep?

    private var hasProgress: Bool {
        store.session.records.values.contains { $0.state != .notStarted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                servingTimeCard
                feasibilityCard
                Button(action: goRecipes) {
                    Label("Choose from Recipes", systemImage: "book.closed")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("open-recipes")
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
                    if hasProgress || feasibility == .ok { goCooking() }
                }) {
                    Label(hasProgress ? "Back to cooking" : "Build my cooking plan", systemImage: "arrow.right")
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
        .sheet(item: $editingStep) { step in
            DurationEditorView(step: step,
                initialMinutes: store.session.durationOverrides[step.id] ?? step.minutes) { minutes in
                store.setDuration(stepID: step.id, minutes: minutes)
                recheckFeasibility()
                return nil // the session store reports its own save problems
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

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dinner, beautifully timed.")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
            Text("Choose your dinner. We’ll bring the timing together.")
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var servingTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "AT THE TABLE")
            Text(store.session.serveAt, format: .dateTime.hour().minute())
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .monospacedDigit().foregroundStyle(Theme.ink)
            DatePicker(
                "Dinner time",
                selection: Binding(
                    get: { store.session.serveAt },
                    set: { store.setServeAt($0); recheckFeasibility() }
                ),
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .disabled(hasProgress)
            if hasProgress {
                Text("Use “Adjust time” or “Review dinner time” while cooking, or reset progress to choose a new time.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .dtCard()
    }

    @ViewBuilder
    private var feasibilityCard: some View {
        if !hasProgress, case .startsInPast(let earliest) = feasibility {
            VStack(alignment: .leading, spacing: 10) {
                Label("Let’s give dinner enough time", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(Theme.warning)
                Text("Starting now, this menu can reach the table at \(Scheduling.formatMoment(earliest)).")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Button("Use \(Scheduling.formatMoment(earliest))") {
                    store.setServeAt(earliest)
                    recheckFeasibility()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .dtCard()
            .accessibilityElement(children: .combine)
        }
    }

    private func menuCard(_ menu: DinnerMenu) -> some View {
        let selected = store.session.menuID == menu.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                guard menu.id != store.session.menuID else { return }
                if hasProgress { pendingMenuID = menu.id } else { store.chooseMenu(menu.id); recheckFeasibility() }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: menu.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(selected ? Theme.tomato : Theme.muted)
                        .frame(width: 46, height: 46)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
                Button { editingStep = step } label: {
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

    private func recheckFeasibility() {
        feasibility = Scheduling.checkFeasibility(
            menu: store.menu,
            serveAt: store.session.serveAt,
            durations: store.session.durationOverrides,
            now: Date()
        )
    }
}
