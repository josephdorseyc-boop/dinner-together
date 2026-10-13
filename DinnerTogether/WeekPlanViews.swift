import SwiftUI
import UIKit

// The week's dinners on screen (Joe, October 13): a "This week" strip at the
// top of Tonight, a sheet to set any day, the built-in dinners as a classics
// folder in Recipes, and an illustrated plate for each classic until the cook
// has a photo of their own.

/// Names, pictures and rules for whatever a day holds.
@MainActor
enum PlannedDinners {
    static func title(_ id: String, library: RecipeLibrary) -> String? {
        if let r = library.recipe(menuID: id) { return r.title }
        return DinnerCatalog.menus.first { $0.id == id }?.title
    }

    static func exists(_ id: String, library: RecipeLibrary) -> Bool { title(id, library: library) != nil }

    /// Can become tonight's dinner without more work: every classic, and a
    /// recipe whose timing has been checked.
    static func cookable(_ id: String, library: RecipeLibrary) -> Bool {
        if let r = library.recipe(menuID: id) { return !r.needsTimingReview }
        return DinnerCatalog.menus.contains { $0.id == id }
    }

    static func cover(_ id: String, library: RecipeLibrary) -> UIImage? {
        library.recipe(menuID: id).flatMap { RecipePhotos.load($0, from: library)?.image }
    }
}

/// A dinner's picture at a given size: the recipe's cover, else the classic's
/// illustrated plate, else a plain recipe glyph; an open night is a dashed ring.
struct DinnerPicture: View {
    @EnvironmentObject private var library: RecipeLibrary
    let dinner: PlannedDinner
    let size: CGFloat

    var body: some View {
        Group {
            switch dinner {
            case .open:
                Circle().strokeBorder(Theme.muted.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .overlay(Image(systemName: "sparkles").font(.system(size: size * 0.3)).foregroundStyle(Theme.muted))
            case .menu(let id):
                if let image = PlannedDinners.cover(id, library: library) {
                    RecipeCoverThumbnail(image: image, size: size)
                } else if DinnerCatalog.menus.contains(where: { $0.id == id }) {
                    PlateIllustration(menuID: id)
                } else {
                    Circle().fill(Theme.paper)
                        .overlay(Image(systemName: "book.closed").font(.system(size: size * 0.32)).foregroundStyle(Theme.muted))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A classic's illustrated plate, drawn in the app's palette: the main on
/// the left, the side in a little heap on the right, a scatter of garnish.
/// A placeholder in A2's hands for the final artwork; it scales to any size.
struct PlateIllustration: View {
    let menuID: String

    private struct Look { let main: Color; let side: Color; let garnish: Color }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
    private static let looks: [String: Look] = [
        "steak": Look(main: c(0.47, 0.26, 0.18), side: c(0.86, 0.68, 0.32), garnish: c(0.36, 0.52, 0.28)),
        "pasta": Look(main: c(0.93, 0.79, 0.47), side: c(0.74, 0.24, 0.16), garnish: c(0.33, 0.55, 0.27)),
        "salmon": Look(main: c(0.94, 0.53, 0.40), side: c(0.96, 0.93, 0.86), garnish: c(0.42, 0.58, 0.30)),
        "lemon-chicken": Look(main: c(0.86, 0.66, 0.39), side: c(0.98, 0.86, 0.36), garnish: c(0.40, 0.55, 0.30)),
        "turkey-tacos": Look(main: c(0.93, 0.80, 0.56), side: c(0.55, 0.33, 0.20), garnish: c(0.80, 0.25, 0.20)),
        "tofu-bowls": Look(main: c(0.95, 0.85, 0.60), side: c(0.95, 0.55, 0.25), garnish: c(0.40, 0.62, 0.32)),
        "chickpea-curry": Look(main: c(0.88, 0.60, 0.22), side: c(0.96, 0.94, 0.88), garnish: c(0.35, 0.56, 0.30)),
        "gnocchi-greens": Look(main: c(0.93, 0.82, 0.56), side: c(0.35, 0.52, 0.27), garnish: c(0.97, 0.92, 0.75)),
        "pork-supper": Look(main: c(0.70, 0.45, 0.35), side: c(0.90, 0.55, 0.25), garnish: c(0.38, 0.52, 0.28)),
        "thanksgiving": Look(main: c(0.70, 0.42, 0.22), side: c(0.62, 0.12, 0.20), garnish: c(0.76, 0.60, 0.38)),
    ]

    var body: some View {
        let look = Self.looks[menuID] ?? Look(main: Theme.tomato, side: Theme.olive, garnish: Theme.muted)
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Color(red: 0.999, green: 0.992, blue: 0.973))
                    .shadow(color: .black.opacity(0.12), radius: s * 0.04, y: s * 0.02)
                Circle().strokeBorder(Color(red: 0.90, green: 0.87, blue: 0.82), lineWidth: s * 0.035)
                    .padding(s * 0.09)
                Ellipse().fill(look.main)
                    .frame(width: s * 0.42, height: s * 0.30)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -s * 0.10, y: s * 0.03)
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(look.side)
                        .frame(width: s * 0.14, height: s * 0.14)
                        .offset(x: s * (0.15 + 0.07 * Double(i % 2)), y: s * (0.06 * Double(i) - 0.07))
                }
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(look.garnish)
                        .frame(width: s * 0.10, height: s * 0.05)
                        .rotationEffect(.degrees(Double(i) * 50 - 30))
                        .offset(x: s * (0.02 * Double(i) - 0.04), y: -s * (0.17 + 0.02 * Double(i)))
                }
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A day the cook is looking at, for `.sheet(item:)`.
struct PlanDay: Identifiable, Equatable {
    let date: Date
    let isToday: Bool
    var id: Date { date }
}

/// "THIS WEEK" on Tonight: today and the six days after it. Today shows
/// tonight's actual dinner; the other days show the plan.
struct WeekStrip: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var weekPlan: WeekPlanStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Choosing today's dinner goes through Tonight's own path (it asks
    /// before replacing a dinner in progress).
    var chooseToday: (String) -> Void
    @State private var editing: PlanDay?

    private var days: [Date] { WeekRotation.days(from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "THIS WEEK")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        chip(day, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
            if let problem = weekPlan.saveError {
                Text(problem).font(.caption).foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $editing) { day in
            DayPlanSheet(day: day, chooseToday: chooseToday).uiTestTypeSize()
        }
    }

    private func dinner(on day: Date, index: Int) -> PlannedDinner {
        index == 0 ? .menu(store.session.menuID) : weekPlan.dinner(on: day) { PlannedDinners.exists($0, library: library) }
    }

    private func chip(_ day: Date, index: Int) -> some View {
        let dinner = self.dinner(on: day, index: index)
        let title: String = {
            switch dinner {
            case .open: return "Your pick"
            case .menu(let id): return PlannedDinners.title(id, library: library) ?? store.menu.title
            }
        }()
        let dayName = index == 0 ? "Today" : day.formatted(.dateTime.weekday(.abbreviated))
        let width: CGFloat = dynamicTypeSize.isAccessibilitySize ? 150 : 88
        return Button { editing = PlanDay(date: day, isToday: index == 0) } label: {
            VStack(spacing: 6) {
                Text(dayName).font(.caption.weight(.semibold))
                    .foregroundStyle(index == 0 ? Theme.tomato : Theme.muted)
                DinnerPicture(dinner: dinner, size: 56)
                Text(title).font(.caption2).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width)
            .padding(.vertical, 10).padding(.horizontal, 4)
            .background(index == 0 ? Theme.paper : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(index == 0 ? Theme.tomato.opacity(0.55) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index == 0 ? "Today" : day.formatted(.dateTime.weekday(.wide))): \(title)")
        .accessibilityHint(index == 0 ? "Choose tonight’s dinner." : "Plan this day’s dinner.")
        .accessibilityIdentifier("week-day-\(index)")
    }
}

/// One day of the plan: a classic, one of the cook's recipes, an open night,
/// or back to the rotation. Today goes through Tonight's own choice.
struct DayPlanSheet: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var weekPlan: WeekPlanStore
    @Environment(\.dismiss) private var dismiss
    let day: PlanDay
    var chooseToday: (String) -> Void

    private var current: PlannedDinner {
        day.isToday ? .menu(store.session.menuID) : weekPlan.dinner(on: day.date) { PlannedDinners.exists($0, library: library) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(day.isToday
                         ? "Choose tonight’s dinner. Your week plan fills the other days."
                         : "Plan this day’s dinner. When the day comes it becomes tonight’s, unless you’ve already chosen or started cooking.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    if let problem = weekPlan.saveError {
                        Text(problem).font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("day-plan-error")
                    }
                }
                if !day.isToday {
                    Section {
                        row(.open, title: "Your pick", subtitle: "Leave this night open", identifier: "day-plan-open")
                        if weekPlan.plan.isChosen(day.date) {
                            Button("Back to the weekly rotation") {
                                if weekPlan.clear(day.date) { dismiss() }
                            }
                            .foregroundStyle(Theme.tomato)
                            .accessibilityIdentifier("day-plan-rotation")
                        }
                    }
                }
                Section("Dinner, Together classics") {
                    ForEach(DinnerCatalog.menus) { menu in
                        row(.menu(menu.id), title: menu.title, subtitle: menu.subtitle, identifier: "day-plan-\(menu.id)")
                    }
                }
                if !library.recipes.isEmpty {
                    Section("Your recipes") {
                        ForEach(library.recipes) { recipe in
                            let blocked = day.isToday && recipe.needsTimingReview
                            row(.menu(recipe.menuID), title: recipe.title,
                                subtitle: recipe.needsTimingReview
                                    ? (day.isToday ? "Check its timing first, on the recipe’s page" : "Check its timing before that day")
                                    : RecipeFormat.duration(recipe.plannedMinutes),
                                identifier: "day-plan-recipe", disabled: blocked)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle(day.isToday ? "Tonight" : day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("day-plan-done") } }
        }
        .presentationDetents([.large])
    }

    private func row(_ dinner: PlannedDinner, title: String, subtitle: String, identifier: String, disabled: Bool = false) -> some View {
        Button {
            choose(dinner)
        } label: {
            HStack(spacing: 14) {
                DinnerPicture(dinner: dinner, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(disabled ? Theme.warning : Theme.muted)
                }
                Spacer(minLength: 0)
                if dinner == current {
                    Image(systemName: "checkmark").foregroundStyle(Theme.tomato).accessibilityLabel("Planned")
                }
            }
        }
        .disabled(disabled)
        .listRowBackground(Theme.paper)
        .accessibilityAddTraits(dinner == current ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func choose(_ dinner: PlannedDinner) {
        if day.isToday {
            if case .menu(let id) = dinner { chooseToday(id) }
            dismiss()
        } else if weekPlan.set(dinner, on: day.date) {
            dismiss()
        }
    }
}

/// Recipes → "Dinner, Together classics": the built-in dinners as a folder,
/// each one ready to plan onto a day of the week.
struct ClassicsView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var weekPlan: WeekPlanStore
    var goTonight: () -> Void
    @State private var planning: DinnerMenu?

    var body: some View {
        List {
            Text("The dinners that come with the app. They rotate through your week on Tonight; plan one for any day here.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            ForEach(DinnerCatalog.menus) { menu in
                Button { planning = menu } label: {
                    HStack(spacing: 14) {
                        DinnerPicture(dinner: .menu(menu.id), size: 58)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(menu.title).font(.headline).foregroundStyle(Theme.ink)
                            Text(menu.subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            if let when = plannedDays(menu.id) {
                                Text(when).font(.caption.weight(.semibold)).foregroundStyle(Theme.olive)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "calendar.badge.plus").foregroundStyle(Theme.tomato)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.paper)
                .accessibilityHint("Plan this dinner for a day this week.")
                .accessibilityIdentifier("classic-\(menu.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.recipeBackground)
        .navigationTitle("Dinner, Together classics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $planning) { menu in
            PlanClassicSheet(menu: menu, goTonight: goTonight).uiTestTypeSize()
        }
    }

    /// "Tonight · Thu" — the days this week it is on the plan.
    private func plannedDays(_ id: String) -> String? {
        let days = WeekRotation.days(from: Date())
        let names: [String] = days.enumerated().compactMap { index, day in
            let dinner: PlannedDinner = index == 0 ? .menu(store.session.menuID) : weekPlan.dinner(on: day)
            guard dinner == .menu(id) else { return nil }
            return index == 0 ? "Tonight" : day.formatted(.dateTime.weekday(.abbreviated))
        }
        return names.isEmpty ? nil : "This week: " + names.joined(separator: " · ")
    }
}

/// "Plan <classic> for…" — tonight, or one of the next six days.
struct PlanClassicSheet: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var weekPlan: WeekPlanStore
    @Environment(\.dismiss) private var dismiss
    let menu: DinnerMenu
    var goTonight: () -> Void
    @State private var cookingNow = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        DinnerPicture(dinner: .menu(menu.id), size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(menu.title).font(.title3.weight(.semibold))
                            Text(menu.subtitle).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                if let problem = weekPlan.saveError {
                    Text(problem).font(.subheadline).foregroundStyle(Theme.warning)
                }
                Section("Plan it for") {
                    ForEach(Array(WeekRotation.days(from: Date()).enumerated()), id: \.offset) { index, day in
                        Button {
                            choose(day, isToday: index == 0)
                        } label: {
                            HStack {
                                Text(index == 0 ? "Tonight" : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(currentTitle(day, isToday: index == 0)).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        .listRowBackground(Theme.paper)
                        .accessibilityIdentifier("plan-day-\(index)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle("Plan this dinner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("You’re cooking right now", isPresented: $cookingNow) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Finish or reset tonight’s dinner first, then choose another for tonight. You can still plan it for another day.")
            }
        }
        .presentationDetents([.large])
    }

    private func currentTitle(_ day: Date, isToday: Bool) -> String {
        if isToday { return store.menu.title }
        switch weekPlan.dinner(on: day) {
        case .open: return "Your pick"
        case .menu(let id): return DinnerCatalog.menus.first { $0.id == id }?.title ?? "One of your recipes"
        }
    }

    private func choose(_ day: Date, isToday: Bool) {
        if isToday {
            guard !store.hasProgress else { cookingNow = true; return }
            store.chooseMenu(menu.id)
            dismiss()
            goTonight()
        } else if weekPlan.set(.menu(menu.id), on: day) {
            dismiss()
        }
    }
}
