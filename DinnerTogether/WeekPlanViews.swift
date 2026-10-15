import SwiftUI
import UIKit
import PhotosUI

// The week's dinners on screen (Joe, October 13/14): a "This week" strip on
// Tonight and a sheet to set any day to one of the cook's own recipes, an
// open night, or Thanksgiving. The app brings no dinners of its own.

/// Names, pictures and rules for whatever a day holds.
@MainActor
enum PlannedDinners {
    /// The dinner's recipes, main first (empty for Thanksgiving or a
    /// recipe that's gone).
    static func recipes(_ id: String, library: RecipeLibrary) -> [Recipe] {
        (WholeMeal.recipeIDs(id) ?? []).compactMap { library.recipe(id: $0) }
    }

    static func title(_ id: String, library: RecipeLibrary) -> String? {
        if let ids = WholeMeal.recipeIDs(id) {
            let recipes = recipes(id, library: library)
            // Every dish, or nothing — as the library resolves the menu.
            guard recipes.count == ids.count else { return nil }
            return recipes.map(\.title).joined(separator: " + ")
        }
        return DinnerCatalog.menu(id: id)?.title
    }

    static func exists(_ id: String, library: RecipeLibrary) -> Bool { title(id, library: library) != nil }

    /// Can become tonight's dinner without more work: Thanksgiving, and
    /// recipes whose timing has been checked — every dish of a whole meal.
    static func cookable(_ id: String, library: RecipeLibrary) -> Bool {
        if let ids = WholeMeal.recipeIDs(id) {
            let recipes = recipes(id, library: library)
            return recipes.count == ids.count && !recipes.contains { $0.needsTimingReview }
        }
        return DinnerCatalog.menu(id: id) != nil
    }

    /// The dinner's picture: the plate photo the cook took, else the cover.
    static func picture(_ id: String, library: RecipeLibrary) -> UIImage? {
        library.recipe(menuID: id).flatMap { RecipePhotos.hero($0, from: library)?.image }
    }
}

/// A dinner's picture at a given size: the recipe's photo, a glyph for a
/// recipe without one or for Thanksgiving; an open night is a dashed ring.
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
                if let image = PlannedDinners.picture(id, library: library) {
                    RecipeCoverThumbnail(image: image, size: size)
                } else {
                    Circle().fill(Theme.paper)
                        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                        .overlay(Image(systemName: DinnerCatalog.menu(id: id)?.symbol ?? "book.closed")
                            .font(.system(size: size * 0.32)).foregroundStyle(id == DinnerCatalog.thanksgivingID ? Theme.tomato : Theme.muted))
                }
            }
        }
        .frame(width: size, height: size)
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
    /// The page presents the day sheet (PlanView.planningDay).
    var openDay: (PlanDay) -> Void

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
    }

    private func dinner(on day: Date, index: Int) -> PlannedDinner {
        if index == 0 { return store.hasDinner ? .menu(store.session.menuID) : .open }
        return weekPlan.dinner(on: day) { PlannedDinners.exists($0, library: library) }
    }

    private func chip(_ day: Date, index: Int) -> some View {
        let dinner = self.dinner(on: day, index: index)
        let title: String = {
            switch dinner {
            case .open: return index == 0 ? "Not chosen" : "Your pick"
            case .menu(let id): return PlannedDinners.title(id, library: library) ?? store.menu.title
            }
        }()
        let dayName = index == 0 ? "Today" : day.formatted(.dateTime.weekday(.abbreviated))
        let width: CGFloat = dynamicTypeSize.isAccessibilitySize ? 150 : 88
        return Button { openDay(PlanDay(date: day, isToday: index == 0)) } label: {
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
            // The whole chip takes the tap. Without this a plain-style
            // Button is hit-testable only where its label draws: the plate
            // is drawn with hit testing off and the chip's background is
            // clear, so a tap at the chip's center — where a finger and
            // XCTest both land — fell through to the strip (runs
            // 38508449584, 38519974627, 38532632676: chips were Buttons
            // with finite frames, nothing presented, no sheet).
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        // The Button's own element, untouched: `.ignore` dropped the button
        // trait (run 38484344610).
        .accessibilityLabel("\(index == 0 ? "Today" : day.formatted(.dateTime.weekday(.wide))): \(title)")
        .accessibilityHint(index == 0 ? "Choose tonight’s dinner." : "Plan this day’s dinner.")
        .accessibilityIdentifier("week-day-\(index)")
    }
}

/// One day of the plan: one of the cook's recipes, an open night, or
/// Thanksgiving. Today goes through Tonight's own choice.
struct DayPlanSheet: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var weekPlan: WeekPlanStore
    @Environment(\.dismiss) private var dismiss
    let day: PlanDay
    var chooseToday: (String) -> Void
    /// Tonight's dishes changed (a whole meal, build 21): the dinner time
    /// stays. Falls back to `chooseToday` when not given.
    var changeTodayDishes: ((String) -> Void)? = nil
    /// Add a new recipe from the day itself (Joe, build 20).
    @State private var adding = false
    @State private var query = ""

    private var current: PlannedDinner {
        day.isToday ? .menu(store.session.menuID) : weekPlan.dinner(on: day.date) { PlannedDinners.exists($0, library: library) }
    }

    /// The day's recipes, main first — the checked rows (Joe, October 15:
    /// "make it so you can check more than one recipe").
    private var checked: [UUID] {
        if case .menu(let id) = current { return WholeMeal.recipeIDs(id) ?? [] }
        return []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // A2-63's copy: first is the main, up to four, saved as chosen.
                    Text(day.isToday
                         ? "Choose up to 4 dishes for tonight. The first is your main; they’re timed to be ready together."
                         : "Choose up to 4 dishes for this day. The first is your main. When the day comes it becomes tonight’s, unless you’ve already chosen or started cooking.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Text(checked.isEmpty ? "Changes save as you choose." : "\(checked.count) of \(WholeMeal.maxRecipes) dishes chosen · changes save as you choose.")
                        .font(.caption).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("day-plan-count")
                    if let problem = weekPlan.saveError {
                        Text(problem).font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("day-plan-error")
                    }
                }
                if !day.isToday {
                    Section {
                        row(.open, title: "Your pick", subtitle: "Leave this night open", identifier: "day-plan-open")
                    }
                }
                Section("Your recipes") {
                    if library.recipes.isEmpty {
                        Text("You haven’t added a recipe yet. Add one here and plan it for this day.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("day-plan-no-recipes")
                    }
                    ForEach(library.recipesFavoritesFirst.filter { $0.matches(query) }) { recipe in
                            let blocked = day.isToday && recipe.needsTimingReview
                            let position = checked.firstIndex(of: recipe.id)
                            let full = position == nil && checked.count >= WholeMeal.maxRecipes
                            recipeRow(recipe, position: position,
                                      subtitle: recipe.needsTimingReview
                                          ? (day.isToday ? "Check its timing first, on the recipe’s page" : "Check its timing before that day")
                                          : (full ? "Four dishes is the most for one dinner" : RecipeFormat.duration(recipe.plannedMinutes)),
                                      disabled: blocked || full)
                    }
                    // + a recipe not in the cookbook yet: added, then planned
                    // for this day (tonight once its timing is checked).
                    Button { adding = true } label: {
                        Label("Add a new recipe", systemImage: "plus.circle.fill")
                            .font(.headline).foregroundStyle(Theme.tomato)
                            .frame(minHeight: 44)
                    }
                    .listRowBackground(Theme.paper)
                    .accessibilityIdentifier("day-plan-add-recipe")
                }
                Section("Holiday") {
                    let tg = DinnerCatalog.thanksgiving
                    row(.menu(tg.id), title: tg.title, subtitle: tg.subtitle, identifier: "day-plan-\(tg.id)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Title or ingredient")
            .accessibilityIdentifier("day-plan-sheet")
            .navigationTitle(day.isToday ? "Tonight" : day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("day-plan-done") } }
            .sheet(isPresented: $adding) {
                AddRecipeSheet { id in
                    // A future day plans it now, alongside the dishes already
                    // checked (A2-63: never in their place); tonight needs
                    // its timing checked first, so it waits in the list.
                    guard !day.isToday, library.recipe(id: id) != nil else { return }
                    var ids = checked
                    if !ids.contains(id), ids.count < WholeMeal.maxRecipes { ids.append(id) }
                    if let menuID = WholeMeal.menuID(ids) { _ = weekPlan.set(.menu(menuID), on: day.date) }
                }
                .uiTestTypeSize()
            }
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
            .contentShape(Rectangle())
        }
        .disabled(disabled)
        .listRowBackground(Theme.paper)
        .accessibilityAddTraits(dinner == current ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// A recipe row checks into the day's dinner and out again; the first
    /// checked is the main. The sheet stays open for the next dish.
    private func recipeRow(_ recipe: Recipe, position: Int?, subtitle: String, disabled: Bool) -> some View {
        Button {
            toggle(recipe)
        } label: {
            HStack(spacing: 14) {
                DinnerPicture(dinner: .menu(recipe.menuID), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title).font(.headline).foregroundStyle(Theme.ink)
                    Text(position == 0 ? "Main dish · \(subtitle)" : subtitle)
                        .font(.caption).foregroundStyle(disabled ? Theme.warning : Theme.muted)
                }
                Spacer(minLength: 0)
                if position != nil {
                    Image(systemName: "checkmark").foregroundStyle(Theme.tomato).accessibilityLabel("Planned")
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(disabled)
        .listRowBackground(Theme.paper)
        .accessibilityAddTraits(position != nil ? .isSelected : [])
        .accessibilityHint(position != nil ? "Takes it off this dinner." : "Adds it to this dinner.")
        .accessibilityIdentifier("day-plan-recipe")
    }

    private func toggle(_ recipe: Recipe) {
        var ids = checked
        if let i = ids.firstIndex(of: recipe.id) { ids.remove(at: i) } else { ids.append(recipe.id) }
        let next = ids.isEmpty ? "" : (WholeMeal.menuID(ids) ?? "")
        if day.isToday {
            // Unchecking the last one leaves no dinner chosen (Joe, build 19);
            // the first check chooses; after that the dishes change and the
            // dinner time stays.
            if checked.isEmpty || ids.isEmpty { chooseToday(next) } else { (changeTodayDishes ?? chooseToday)(next) }
        } else {
            _ = weekPlan.set(ids.isEmpty ? .open : .menu(next), on: day.date)
        }
    }

    private func choose(_ dinner: PlannedDinner) {
        if day.isToday {
            // Tonight's checked choice, tapped again, unchecks it (Joe, build 19).
            if case .menu(let id) = dinner { chooseToday(dinner == current ? "" : id) }
            dismiss()
        } else if weekPlan.set(dinner, on: day.date) {
            dismiss()
        }
    }
}

// MARK: - Tonight's dinner as a hero (Joe, October 13; A2's Duo mock)

/// The best picture a dinner has: the plate photo the cook took after
/// cooking it, else the recipe's cover. Nothing else — never a stock or
/// drawn picture (Joe, October 14).
enum DinnerHeroArt {
    case cover(UIImage, RecipePalette?)

    @MainActor
    static func of(_ menuID: String, library: RecipeLibrary) -> DinnerHeroArt? {
        guard let recipe = library.recipe(menuID: menuID) else { return nil }
        return RecipePhotos.hero(recipe, from: library).map { .cover($0.image, $0.palette) }
    }
}

/// The hero band: a cover resolving into the card's surface. Decorative;
/// the card names the dish.
struct DinnerHero: View {
    let art: DinnerHeroArt
    let height: CGFloat

    var body: some View {
        switch art {
        case .cover(let image, let palette):
            RecipeCoverBand(image: image, palette: palette, height: height)
        }
    }
}

/// The same picture as a small square, for header rows and the timeline.
struct DinnerHeroThumbnail: View {
    let art: DinnerHeroArt
    let size: CGFloat

    var body: some View {
        switch art {
        case .cover(let image, _): RecipeCoverThumbnail(image: image, size: size)
        }
    }
}

/// A step's picture on timer and timeline rows: the recipe's own photo.
/// Anything without one shows nothing.
struct DishThumbnail: View {
    @EnvironmentObject private var library: RecipeLibrary
    let step: CookingStep
    let menuID: String
    let size: CGFloat

    var body: some View {
        if let recipe = library.recipe(forStep: step.id, in: menuID), let photo = RecipePhotos.hero(recipe, from: library) {
            RecipeCoverThumbnail(image: photo.image, size: size)
        }
    }
}

// MARK: - A photo of the plate (Joe, October 14)

/// After the last step: take or choose a photo of the finished plate. It
/// leads the recipe's hero on Tonight and Cooking from then on; the cover
/// stays for the recipe's page and colors.
struct PlatePhotoCard: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    @State private var picked: PhotosPickerItem?
    @State private var takingPhoto = false
    @State private var problem: String?

    private var current: Recipe { library.recipe(id: recipe.id) ?? recipe }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "YOUR PLATE")
            if let plate = RecipePhotos.loadPlate(current, from: library) {
                HStack(spacing: 14) {
                    RecipeCoverThumbnail(image: plate, size: 64)
                        .accessibilityLabel("Your plate photo")
                        .accessibilityIdentifier("plate-photo-thumbnail")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your photo is the picture for this dinner.")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                        Button("Remove photo") {
                            if !library.removePlatePhoto(for: recipe.id) { problem = library.saveError }
                        }
                        .font(.caption).foregroundStyle(Theme.tomato)
                        .accessibilityIdentifier("remove-plate-photo")
                    }
                }
            } else {
                Text("Add a photo of your plate and it becomes this dinner’s picture.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { takingPhoto = true } label: { Label("Take a photo", systemImage: "camera") }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("take-plate-photo")
                    }
                    PhotosPicker(selection: $picked, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("choose-plate-photo")
                }
            }
            if let problem {
                Text(problem).font(.caption).foregroundStyle(Theme.warning)
                    .accessibilityIdentifier("plate-photo-error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dtCard()
        .accessibilityIdentifier("plate-photo-card")
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { save(data) }
                picked = nil
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraCapture { image in
                takingPhoto = false
                if let image, let data = image.jpegData(compressionQuality: 0.85) { save(data) }
            }
            .ignoresSafeArea()
        }
    }

    private func save(_ data: Data) {
        // Re-encode through UIImage so an HEIC pick is stored as JPEG.
        let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
        if library.savePlatePhoto(jpeg, for: recipe.id) == nil { problem = library.saveError } else { problem = nil }
    }
}

/// The system camera, for the plate photo.
struct CameraCapture: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
