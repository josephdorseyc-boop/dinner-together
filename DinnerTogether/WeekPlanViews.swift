import SwiftUI
import UIKit
import PhotosUI

// The week's dinners on screen (Joe, October 13/14): a "This week" strip on
// Tonight and a sheet to set any day to one of the cook's own recipes, an
// open night, or Thanksgiving. The app brings no dinners of its own.

/// Names, pictures and rules for whatever a day holds.
@MainActor
enum PlannedDinners {
    static func title(_ id: String, library: RecipeLibrary) -> String? {
        if let r = library.recipe(menuID: id) { return r.title }
        return DinnerCatalog.menu(id: id)?.title
    }

    static func exists(_ id: String, library: RecipeLibrary) -> Bool { title(id, library: library) != nil }

    /// Can become tonight's dinner without more work: Thanksgiving, and a
    /// recipe whose timing has been checked.
    static func cookable(_ id: String, library: RecipeLibrary) -> Bool {
        if let r = library.recipe(menuID: id) { return !r.needsTimingReview }
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
    /// Add a new recipe from the day itself (Joe, build 20).
    @State private var adding = false

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
                    }
                }
                Section("Your recipes") {
                    if library.recipes.isEmpty {
                        Text("You haven’t added a recipe yet. Add one here and plan it for this day.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("day-plan-no-recipes")
                    }
                    ForEach(library.recipesFavoritesFirst) { recipe in
                            let blocked = day.isToday && recipe.needsTimingReview
                            row(.menu(recipe.menuID), title: recipe.title,
                                subtitle: recipe.needsTimingReview
                                    ? (day.isToday ? "Check its timing first, on the recipe’s page" : "Check its timing before that day")
                                    : RecipeFormat.duration(recipe.plannedMinutes),
                                identifier: "day-plan-recipe", disabled: blocked)
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
            .accessibilityIdentifier("day-plan-sheet")
            .navigationTitle(day.isToday ? "Tonight" : day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("day-plan-done") } }
            .sheet(isPresented: $adding) {
                AddRecipeSheet { id in
                    // A future day plans it now; tonight needs its timing
                    // checked first, so it waits in the list, marked so.
                    guard !day.isToday, let recipe = library.recipe(id: id) else { return }
                    _ = weekPlan.set(.menu(recipe.menuID), on: day.date)
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

    private func choose(_ dinner: PlannedDinner) {
        if day.isToday {
            if case .menu(let id) = dinner { chooseToday(id) }
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
        if let recipe = library.recipe(menuID: menuID), let photo = RecipePhotos.hero(recipe, from: library) {
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
