import SwiftUI
import UIKit

/// "Tonight": when dinner is on the table, which of the cook's own recipes
/// it is, the week ahead, and Thanksgiving when it comes round — then the
/// kitchen. The app brings no dinners of its own (Joe, October 14).
struct PlanView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var goCooking: () -> Void
    var goRecipes: () -> Void
    /// Opens the Add recipe sheet (an empty cookbook's first step).
    var addRecipe: (() -> Void)? = nil
    /// Opens one of the cook's recipes on its page (Recipes tab / sidebar).
    var openRecipe: ((UUID) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
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
    /// Whether the cover photo is under the navigation bar (at rest, yes).
    @State private var coverUnderBar = true
    /// How dark the frosted dinner-time card is: the cook's own setting.
    @AppStorage(TonightGlass.key) private var glassTint = TonightGlass.standard
    @State private var showingGlassPanel = false
    /// The photo runs up behind the clock and the bar on iPhone.
    private var photoUnderBar: Bool { coverUnderBar && horizontalSizeClass != .regular }

    private var hasProgress: Bool {
        store.session.records.values.contains { $0.state != .notStarted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // The photo cover (Joe and A2, October 14): tonight's recipe
                // photo — or A2's notebook when nothing is chosen — from the
                // very top of the screen, under the clock and the bar, fading
                // into the page at its foot, with the dinner-time card on it
                // in frosted glass.
                cover
                VStack(alignment: .leading, spacing: 28) {
                    tonightsRecipe
                    chooseRecipe
                    // The week sits below tonight's time and recipe choice
                    // (Joe, October 13).
                    WeekStrip(chooseToday: chooseFromWeek, openDay: { sheet = .day($0) })
                    thanksgivingSection
                }
                .padding(24)
                .frame(maxWidth: 720)
            }
            .frame(maxWidth: .infinity)
        }
        // The photo draws up behind the clock and the bar (see `cover`).
        .scrollClipDisabled()
        .onPreferenceChange(CoverBottomKey.self) { bottom in
            // The bar turns back to the plain page once the photo has
            // scrolled up out from under it (no bar reaches 160 pt down).
            let underBar = bottom > 160
            if underBar != coverUnderBar { coverUnderBar = underBar }
        }
        .background(Theme.cream)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Text(store.hasDinner ? "Selected: \(store.menu.title)" : "Nothing chosen for tonight yet")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button(action: {
                    // Nothing chosen: the action is choosing (or bringing
                    // in the first recipe), never an empty plan.
                    if !store.hasDinner {
                        if library.isEmpty, let addRecipe { addRecipe() } else { goRecipes() }
                        return
                    }
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
                    Label(primaryActionTitle, systemImage: store.hasDinner ? "arrow.right" : "book.closed")
                }
                .buttonStyle(BigButtonStyle())
                .accessibilityIdentifier("tonight-primary")
                .accessibilityHint(store.hasDinner ? "Opens your cooking timeline." : "Opens your recipes.")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(Theme.cream)
        }
        // Over the photo the bar is clear and dark-styled, so the clock and
        // battery read light on the photo; once the photo has scrolled away
        // it is the plain page's bar again, with the app's name.
        // (iPhone only: on iPad the sidebar sets the clock's color, so the
        // photo starts below the clock there and the bar stays as it is.)
        .navigationTitle("Dinner, Together")
        .navigationBarTitleDisplayMode(.inline)
        // The bar's background stays *visible* — clear over the photo — because
        // SwiftUI applies the bar's color scheme (and so the light clock) only
        // while its background is visible (A2-47: with it hidden, the clock
        // stayed dark over the recipe covers in run 38588198150).
        .toolbarBackground(photoUnderBar ? Color.clear : Theme.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(photoUnderBar ? .dark : nil, for: .navigationBar)
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
        if !store.hasDinner { return library.isEmpty ? "Add your first recipe" : "Choose tonight’s recipe" }
        if hasProgress { return "Back to cooking" }
        if case .startsInPast(let earliest) = feasibility {
            return "Build plan for \(Scheduling.formatTime(earliest))"
        }
        return "Build my cooking plan"
    }

    // MARK: Sections

    /// The cook's own recipe when it is tonight's dinner.
    private var tonightRecipe: Recipe? { library.recipe(menuID: store.session.menuID) }

    /// Tonight names the dish when it is one of the cook's recipes (Joe,
    /// build 10: "it should tell you which recipe you're making on the home
    /// page"). Its photo is the cover above; here the name leads, large, and
    /// opens the recipe.
    @ViewBuilder
    private var tonightsRecipe: some View {
        if let recipe = tonightRecipe {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "TONIGHT’S RECIPE")
                Button {
                    if let openRecipe { openRecipe(recipe.id) } else { goRecipes() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(recipe.title)
                            .font(.system(.title, design: .serif).weight(.medium))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                    .foregroundStyle(Theme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tonight-recipe")
                .accessibilityHint("Opens the recipe.")
                HStack(spacing: 6) {
                    if let byline = recipe.source.byline {
                        Text(byline).lineLimit(1)
                        Text("·").accessibilityHidden(true)
                    }
                    if recipe.needsTimingReview {
                        Label("Check the timing", systemImage: "clock.badge.questionmark")
                            .fontWeight(.semibold).foregroundStyle(Theme.warning)
                    } else {
                        Text(RecipeFormat.duration(recipe.plannedMinutes))
                    }
                }
                .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: The cover

    /// Behind the cover: tonight's recipe's plate photo or cover, else A2's
    /// default photo, so the page is never bare (Joe, October 14).
    private var coverImage: UIImage? {
        if let recipe = tonightRecipe, let photo = RecipePhotos.hero(recipe, from: library) { return photo.image }
        return UIImage(named: "TonightCover")
    }

    #if DEBUG
    /// Which picture the cover shows — for UI tests of A2-44's priority
    /// (plate, then cover, then the notebook), as the cover's value.
    private var coverSource: String {
        guard let recipe = tonightRecipe else { return "notebook" }
        if RecipePhotos.loadPlate(recipe, from: library) != nil { return "plate" }
        if RecipePhotos.load(recipe, from: library) != nil { return "cover" }
        return "notebook"
    }
    #endif

    /// The photo from the very top of the screen (Joe, October 14: "all
    /// the way to the top"): the cover lays out below the bar, and on iPhone
    /// its photo draws upward behind the bar and the clock (the scroll view
    /// does not clip), so nothing has to measure the bars. "Tonight" sits on
    /// the photo with the app's name in the clear bar above it; the frosted
    /// dinner-time card rests on the lower half; the photo fades into the
    /// page at its foot only, through a mask, in Light and Dark alike.
    private var cover: some View {
        let cream = Color(red: 0.965, green: 0.945, blue: 0.890)
        let reach: CGFloat = horizontalSizeClass == .regular ? 0 : 400
        return VStack(alignment: .leading, spacing: 0) {
            Text("Tonight")
                .font(.system(size: 44, weight: .medium, design: .serif))
                .minimumScaleFactor(0.7).lineLimit(1)
                .foregroundStyle(cream)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 1)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: 696, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 4)
            Spacer(minLength: 96)
            servingTimeCard
                .frame(maxWidth: 696)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
            Spacer().frame(height: 44) // the card's foot rests in the fade
        }
        .frame(maxWidth: .infinity, minHeight: horizontalSizeClass == .regular ? 500 : 400)
        .background {
            ZStack(alignment: .top) {
                if reach == 0 {
                    // iPad: a wide cover, the photo fills it.
                    Color.clear
                        .overlay {
                            if let coverImage {
                                Image(uiImage: coverImage).resizable().scaledToFill()
                            }
                        }
                        .clipped()
                } else if let coverImage {
                    // iPhone: the cover is far taller than wide (and reaches
                    // up out of sight for the bounce), so filling it blew a
                    // photo up to a corner of itself (Joe, build 18: "the app
                    // blew up the changed cover"). The photo now sits at the
                    // top of the screen at its own shape — zoomed at most to
                    // a 4:5 portrait — and melts into a soft, blurred wash of
                    // itself that carries on behind the card.
                    Color.clear
                        .overlay(Image(uiImage: coverImage).resizable().scaledToFill())
                        .blur(radius: 36, opaque: true)
                        .overlay(Color.black.opacity(0.22))
                        .clipped()
                    Color.clear
                        .aspectRatio(Self.coverPhotoAspect(coverImage), contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay(Image(uiImage: coverImage).resizable().scaledToFill())
                        .clipped()
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                                     .init(color: .black, location: 0.72),
                                                     .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                        // From the top of the screen (the clock and the bar
                        // are ~110 pt), not from the hidden bounce area.
                        .padding(.top, reach - Self.barReach)
                }
                // Keeps the clock, the bar's title and "Tonight" readable on
                // a pale photo: darkest behind the bars, gone by mid-cover.
                LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                                       .init(color: .black.opacity(0.42), location: reach == 0 ? 0.3 : 0.62),
                                       .init(color: .black.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: reach + 260)
            }
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black.opacity(0.4), location: 0.55),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 140)
                }
            }
            .padding(.top, -reach)
            .accessibilityHidden(true)
        }
        .background(GeometryReader { g in
            Color.clear.preference(key: CoverBottomKey.self, value: g.frame(in: .global).maxY)
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tonight-cover")
        #if DEBUG
        .accessibilityValue(coverSource)
        #endif
    }

    /// Choosing: the first recipe when the cookbook is empty, otherwise the
    /// cookbook. Once a recipe is tonight's, the same place changes it.
    @ViewBuilder
    private var chooseRecipe: some View {
        if library.isEmpty {
            // A2's first-evening copy under the notebook cover.
            VStack(spacing: 10) {
                Text("Your recipes, together")
                    .font(.system(.title, design: .serif).weight(.medium))
                    .multilineTextAlignment(.center)
                Text("Add a recipe you love from a link, text or screenshots. We’ll help you time dinner.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button { if let addRecipe { addRecipe() } else { goRecipes() } } label: {
                    Label("Link, text or screenshots", systemImage: "link")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
                .accessibilityIdentifier("import-first-recipe")
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("empty-cookbook")
        } else {
            Button(action: goRecipes) {
                Label(tonightRecipe == nil ? "Choose from Recipes" : "Choose a different recipe", systemImage: "book.closed")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("open-recipes")
        }
    }

    /// Thanksgiving is the one dinner the app brings (Joe, October 14): a
    /// card to start planning it, with its dishes and editable estimates.
    private var thanksgivingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "PLAN YOUR THANKSGIVING")
            Text("A whole-day plan for the turkey and the sides, timed back from when you sit down. Choose it for the day, then match each estimate to your recipes.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            menuCard(DinnerCatalog.thanksgiving)
        }
        .accessibilityIdentifier("thanksgiving-section")
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
        let shadow = solidCard ? 0 : TonightGlass.textShadow(glassTint)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("DINNER ON THE TABLE")
                    .font(.caption.weight(.semibold)).tracking(1.4)
                    .foregroundStyle(cream.opacity(0.85))
                    .accessibilityAddTraits(.isHeader)
                    .shadow(color: .black.opacity(shadow), radius: 3, y: 1)
                Spacer(minLength: 0)
                // "…": the card from see-through to solid (Joe, build 18).
                Button { showingGlassPanel = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(cream)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                // A 44 pt target without making the header taller.
                .padding(5).contentShape(Rectangle()).padding(-5)
                .accessibilityLabel("Card opacity")
                .accessibilityHint("Makes this card see-through or solid.")
                .accessibilityIdentifier("table-card-more")
                .popover(isPresented: $showingGlassPanel, arrowEdge: .bottom) {
                    GlassTintPanel(tint: $glassTint, solid: solidCard) { showingGlassPanel = false }
                        .presentationCompactAdaptation(.popover)
                        .uiTestTypeSize()
                }
            }
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
            .shadow(color: .black.opacity(shadow), radius: 3, y: 1)

            if !store.hasDinner {
                Label("Choose tonight’s recipe and we’ll say when to start cooking.", systemImage: "book.closed")
                    .font(.subheadline.weight(.medium)).foregroundStyle(apricot)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("table-time-no-dinner")
                    .shadow(color: .black.opacity(shadow), radius: 3, y: 1)
            } else if hasProgress {
                Label("You’re cooking. Change the time from Cooking with Adjust time or Review dinner time.", systemImage: "flame")
                    .font(.subheadline).foregroundStyle(cream)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(shadow), radius: 3, y: 1)
            } else if case .startsInPast(let earliest) = feasibility {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Too soon for this menu. Starting now, the earliest realistic time is \(Scheduling.formatMoment(earliest)).",
                          systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(apricot)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(shadow), radius: 3, y: 1)
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
                    .shadow(color: .black.opacity(shadow), radius: 3, y: 1)
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
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { tableGlass }
    }

    /// The status bar and the inline navigation bar on iPhone, about.
    private static let barReach: CGFloat = 110
    /// The cover photo's shape on iPhone: its own, but never wider than 4:5
    /// portrait, so a landscape photo still reaches the card (a 1.25× crop
    /// at most for a square, 1.66× for 4:3 — never the 3–4× of filling).
    static func coverPhotoAspect(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 0.8 }
        return min(image.size.width / image.size.height, 0.8)
    }

    /// Solid espresso instead of glass: the cook asked for less
    /// transparency or more contrast (or the `-dt-solid-cards` captures).
    private var solidCard: Bool {
        reduceTransparency || contrast == .increased || LaunchOptions.solidCards
    }

    /// Dark frosted glass over the cover photo, as dark as the cook set it
    /// with the card's "…" (`TonightGlass`); solid espresso for Reduce
    /// Transparency and Increase Contrast.
    @ViewBuilder
    private var tableGlass: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if solidCard {
            shape.fill(Self.tableSurface)
        } else {
            // One dial from glass to solid: the blur and the espresso fade
            // in together; at Solid nothing of the photo shows.
            ZStack {
                shape.fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(TonightGlass.blur(glassTint))
                shape.fill(Self.tableSurface.opacity(TonightGlass.tint(glassTint)))
            }
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
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
                    Image(systemName: menu.symbol)
                        .font(.title2).foregroundStyle(Theme.tomato)
                        .frame(width: 50, height: 50)
                        .background(Theme.cream, in: Circle())
                        .overlay(Circle().stroke(selected ? Theme.tomato.opacity(0.7) : Theme.line, lineWidth: 1.5))
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
                .contentShape(Rectangle()) // the gap before the check takes the tap too
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(menu.title), \(menu.subtitle)")
            .accessibilityAddTraits(selected ? .isSelected : [])

            if menu.id == DinnerCatalog.thanksgivingID {
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
                    Text("Estimates, not recipes — adjust any step to match your kitchen, and verify doneness separately.")
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

/// Where the bottom of Tonight's cover is on screen, to restyle the bar
/// once the photo has scrolled out from under it.
private struct CoverBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = min(value, nextValue()) }
}

/// How dark Tonight's frosted dinner-time card is (Joe, build 18: "It's a
/// little dark … like slider?"). The cook sets it from the card's "…"; it
/// stays on this device. The value is the espresso tint laid over the
/// blurred photo; Reduce Transparency and Increase Contrast keep the card
/// solid whatever it is.
enum TonightGlass {
    /// 0 = see-through glass, 1 = a solid card (Joe, build 18: "make the
    /// card opaque and able to adjust it"). A new key: the first slider's
    /// tint values do not mean the same thing.
    static let key = "tonightCardOpacity"
    static let range: ClosedRange<Double> = 0...1
    /// A little more see-through than build 18's card.
    static let standard = 0.45

    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : standard
    }

    /// How much of the frosted blur shows: a light blur when see-through,
    /// full frosting from about a third of the way up.
    static func blur(_ value: Double) -> Double { min(1, 0.25 + clamped(value) * 2.2) }
    /// The espresso layer: a hint when see-through, fully opaque at Solid.
    static func tint(_ value: Double) -> Double { 0.08 + clamped(value) * 0.92 }

    /// A soft shadow under the card's cream text as the card clears, so it
    /// still reads where the photo is pale; none from 0.6 up.
    static func textShadow(_ value: Double) -> Double {
        max(0, 0.6 - clamped(value)) * 1.1
    }
}
}

/// The card's "…" panel: one slider from See-through to Solid that changes
/// the card live behind it, and a way back to the standard card.
private struct GlassTintPanel: View {
    @Binding var tint: Double
    /// Reduce Transparency or Increase Contrast: the card stays solid.
    var solid: Bool
    var done: () -> Void

    private var atStandard: Bool { abs(TonightGlass.clamped(tint) - TonightGlass.standard) < 0.005 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Card opacity").font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                Button("Done", action: done)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("glass-done")
            }
            if solid {
                Text("Reduce Transparency or Increase Contrast is on, so the card stays solid.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    Slider(value: Binding(get: { TonightGlass.clamped(tint) }, set: { tint = $0 }),
                           in: TonightGlass.range) {
                        Text("Card opacity")
                    }
                    .tint(Theme.tomato)
                    .accessibilityValue("\(Int((TonightGlass.clamped(tint) * 100).rounded())) percent opaque")
                    .accessibilityIdentifier("glass-slider")
                    HStack {
                        Text("See-through")
                        Spacer(minLength: 12)
                        Text("Solid")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
                Button("Reset to standard") { tint = TonightGlass.standard }
                    .font(.subheadline)
                    .disabled(atStandard)
                    .accessibilityIdentifier("glass-reset")
            }
        }
        .padding(20)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}
