import SwiftUI
import UIKit

/// A2-63: the folded, sideways This Week presentation. ContentView owns
/// entry, progress/modal guards, routing and Done's re-entry suppression.
/// Paging only changes this view's selection; the existing day sheet owns
/// edits, through the same guarded callbacks Tonight uses.
@MainActor
struct WeekShowcaseView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var weekPlan: WeekPlanStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    let onDone: () -> Void
    /// A recipe or whole-meal menu ID; navigation is not a cooking action.
    let openDinner: (String) -> Void
    let chooseToday: (String) -> Void
    let changeTodayDishes: (String) -> Void

    @State private var referenceDate = Date()
    @State private var selectedDay = WeekRotation.dayKey(Date())
    @State private var planningDay: PlanDay?

    private var days: [Date] { WeekRotation.days(from: referenceDate) }
    private var selectedIndex: Int { days.firstIndex { key($0) == selectedDay } ?? 0 }
    private var selectedDate: Date { days[selectedIndex] }
    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        TabView(selection: $selectedDay) {
            ForEach(days, id: \.self) { date in
                ZStack {
                    hero(on: date)
                    VStack(spacing: 10) {
                        header
                        dayPicker
                        dayPage(date)
                    }
                    .padding(16)
                }
                .tag(key(date))
                .accessibilityHidden(key(date) != selectedDay)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .foregroundStyle(.white)
        .accessibilityIdentifier("week-showcase")
        .sheet(item: $planningDay) { day in
            DayPlanSheet(day: PlanDay(date: day.date, isToday: isToday(day.date)),
                         chooseToday: chooseToday, changeTodayDishes: changeTodayDishes)
                // A calendar rollover must not leave yesterday's sheet
                // writing to today's session through its old isToday flag.
                .id(key(referenceDate))
                .uiTestTypeSize()
        }
        .onAppear { refreshDays() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDays() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshDays()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Done", action: onDone)
                .buttonStyle(ShowcaseButtonStyle(solid: solid))
                .accessibilityIdentifier("week-showcase-done")
            Spacer(minLength: 0)
            Text("THIS WEEK").font(.headline).tracking(1.5)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text("\(selectedIndex + 1) of \(days.count)")
                .font(.subheadline.monospacedDigit())
                .accessibilityIdentifier("week-showcase-count")
            if !typeSize.isAccessibilitySize {
                Image(systemName: "leaf").foregroundStyle(Color(red: 0.95, green: 0.69, blue: 0.45))
                    .accessibilityHidden(true)
            }
        }
        .padding(8)
        .background(.black.opacity(solid ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var dayPicker: some View {
        if typeSize.isAccessibilitySize {
            HStack(spacing: 12) {
                pageButton(forward: false)
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.headline).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(pageAnnouncement(on: selectedDate))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: select(offset: 1)
                        case .decrement: select(offset: -1)
                        @unknown default: break
                        }
                    }
                pageButton(forward: true)
            }
            .padding(8)
            .background(.black, in: RoundedRectangle(cornerRadius: 18))
        } else {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { date in
                    Button { select(date) } label: {
                        VStack(spacing: 3) {
                            Text(isToday(date) ? "Today" : date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption.weight(.semibold))
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                            Capsule().fill(.white.opacity(key(date) == selectedDay ? 1 : 0))
                                .frame(height: 2).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pageAnnouncement(on: date))
                    .accessibilityAddTraits(key(date) == selectedDay ? .isSelected : [])
                    .accessibilityIdentifier("week-showcase-day-\(key(date))")
                }
            }
            .padding(8)
            .background(.black.opacity(solid ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func pageButton(forward: Bool) -> some View {
        Button { select(offset: forward ? 1 : -1) } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(forward ? selectedIndex == days.count - 1 : selectedIndex == 0)
        .accessibilityLabel(forward ? "Next day" : "Previous day")
        .accessibilityIdentifier(forward ? "week-showcase-next" : "week-showcase-previous")
    }

    private func dayPage(_ date: Date) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isToday(date) {
                        Text("TONIGHT").font(.caption.weight(.semibold)).tracking(1.5)
                    } else {
                        Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(title(on: date))
                        .font(typeSize.isAccessibilitySize ? .title2 : .largeTitle)
                        .fontDesign(.serif).fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("week-showcase-title")
                    if case .menu(let id) = dinner(on: date) {
                        let recipes = PlannedDinners.recipes(id, library: library)
                        if recipes.count > 1 {
                            Text("+ " + recipes.dropFirst().map(\.title).joined(separator: " · "))
                                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Text("\(recipes.count) dishes").font(.caption)
                        } else if let recipe = recipes.first, !typeSize.isAccessibilitySize {
                            if let detail = metadata(for: recipe) {
                                Text(detail).font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    actions(on: date)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(solid ? 1 : 0.75), in: RoundedRectangle(cornerRadius: 22))
                .frame(minHeight: geometry.size.height, alignment: .bottom)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(pageAnnouncement(on: date))
        .accessibilityIdentifier("week-showcase-page-\(key(date))")
        .accessibilityHidden(key(date) != selectedDay)
    }

    @ViewBuilder
    private func actions(on date: Date) -> some View {
        if case .menu(let id) = dinner(on: date) {
            let label = PlannedDinners.recipes(id, library: library).count == 1 ? "View recipe" : "View dinner"
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    viewButton(label, on: date)
                    optionsButton(on: date, empty: false)
                }
            } else {
                HStack(spacing: 12) {
                    viewButton(label, on: date)
                    Spacer(minLength: 0)
                    optionsButton(on: date, empty: false)
                }
            }
        } else {
            optionsButton(on: date, empty: true)
        }
    }

    private func viewButton(_ label: String, on date: Date) -> some View {
        Button {
            // Resolve at the tap too: a recipe can disappear while visible.
            if case .menu(let id) = dinner(on: date) { openDinner(id) }
        } label: { Label(label, systemImage: "book") }
            .buttonStyle(ShowcaseButtonStyle(solid: solid))
            .accessibilityIdentifier("week-showcase-view-dinner")
    }

    private func optionsButton(on date: Date, empty: Bool) -> some View {
        Button {
            planningDay = PlanDay(date: date, isToday: isToday(date))
        } label: { Label(empty ? "Plan this day" : "Day options", systemImage: empty ? "plus" : "ellipsis") }
            .buttonStyle(ShowcaseButtonStyle(solid: solid))
            .accessibilityIdentifier(empty ? "week-showcase-plan-day" : "week-showcase-day-options")
    }

    private func hero(on date: Date) -> some View {
        let image: UIImage? = {
            if case .menu(let id) = dinner(on: date),
               let recipe = PlannedDinners.recipes(id, library: library).first,
               let hero = RecipePhotos.hero(recipe, from: library) { return hero.image }
            return UIImage(named: "TonightCover")
        }()
        return GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.12), .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func key(_ date: Date) -> String { WeekRotation.dayKey(date) }
    private func isToday(_ date: Date) -> Bool { Calendar.current.isDate(date, inSameDayAs: referenceDate) }

    private func dinner(on date: Date) -> PlannedDinner {
        if isToday(date) {
            guard store.hasDinner, PlannedDinners.exists(store.session.menuID, library: library) else { return .open }
            return .menu(store.session.menuID)
        }
        // A2-63: no implicit holiday card. WeekPlan still has a Thanksgiving
        // default; only an explicitly chosen assignment belongs in this view.
        guard let id = weekPlan.plan.assignments[key(date)], !id.isEmpty,
              PlannedDinners.exists(id, library: library) else { return .open }
        return .menu(id)
    }

    private func title(on date: Date) -> String {
        guard case .menu(let id) = dinner(on: date) else { return "Nothing planned yet" }
        return PlannedDinners.recipes(id, library: library).first?.title
            ?? PlannedDinners.title(id, library: library) ?? "Nothing planned yet"
    }

    private func metadata(for recipe: Recipe) -> String? {
        var parts: [String] = []
        if recipe.needsTimingReview { parts.append("Check timing before cooking") }
        else if recipe.plannedMinutes > 0 { parts.append(RecipeFormat.duration(recipe.plannedMinutes)) }
        if let yield = recipe.yield?.trimmingCharacters(in: .whitespacesAndNewlines), !yield.isEmpty {
            parts.append(yield)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func pageAnnouncement(on date: Date) -> String {
        let position = (days.firstIndex(of: date) ?? 0) + 1
        let description: String
        if case .menu(let id) = dinner(on: date) {
            description = PlannedDinners.title(id, library: library) ?? "Nothing planned yet"
        } else { description = "Nothing planned yet" }
        return "\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(isToday(date) ? "Tonight, " : "")\(description), \(position) of \(days.count)"
    }

    private func select(_ date: Date) {
        if reduceMotion { selectedDay = key(date) }
        else { withAnimation(.easeInOut(duration: 0.2)) { selectedDay = key(date) } }
    }

    private func select(offset: Int) {
        let index = min(max(selectedIndex + offset, 0), days.count - 1)
        select(days[index])
    }

    private func refreshDays() {
        referenceDate = Date()
        if !days.contains(where: { key($0) == selectedDay }) { selectedDay = key(days[0]) }
    }
}

private struct ShowcaseButtonStyle: ButtonStyle {
    let solid: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.inkOnLight)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                if solid { RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.98, green: 0.965, blue: 0.929)) }
                else { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial) }
            }
            .environment(\.colorScheme, .light)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
