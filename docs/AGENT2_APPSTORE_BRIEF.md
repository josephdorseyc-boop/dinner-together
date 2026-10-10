# Dinner, Together — App Store brief for Agent 2 (product, content, design)

From: Agent 3 · October 9, 2026 · via Joe
Source of truth: repo `josephdorseyc-boop/dinner-together`, `main` (commit in
the cover note). Rules unchanged from `REVIEW_REQUEST_r4.md`: findings
ranked by severity, patches separate, no overlapping edits, evidence tiers
labeled. Patch naming for this stream: `A2-S<n>-<slug>.patch`; handoff
`A2_APPSTORE_HANDOFF.md`.

## The decision

Joe has decided to ship 1.0 to the App Store now and monetize: **paid app,
$2.99, no in-app purchase in 1.0**. Read `docs/store/APP_STORE_PLAN.md` for
the reasoning and the timeline (live within about a week of Developer
Program approval), and `release/README.md` for how the build gets there
(signed on GitHub's macOS runners; no Mac anywhere).

The validation loop you know is unchanged and still gates every release:
61 unit tests, the XCUITest tap-through (first execution: CI run 12),
seeded screenshots.

## Your four deliverables, in priority order

### S1 — The listing (`docs/store/LISTING.md`) — review and return

Every App Store Connect field is drafted and paste-ready: name, subtitle,
promotional text, description, keywords, screenshot order, review notes.
Edit for voice and accuracy. Constraints: character limits are in the file;
Apple rejects keywords that repeat the name, competitor names, or
superlatives; the description must not promise anything the app doesn't do
today (three dinners, no custom dinners, no sharing). Keep "timing is an
estimate; use a thermometer" — it's a 1.4.1 safeguard, not boilerplate.

### S2 — Menu content: six to eight new dinners (Guideline 4.2 insurance)

Three menus is the one thing an App Review reviewer could call thin. Add
dinners to `DinnerTogether/DinnerCatalog.swift` in the exact existing
format (`DinnerMenu` → dishes → `step(id, dish, title, minutes, detail,
handsOn:)`), as one patch. Requirements, all enforced by the engine or the
tests — read `Scheduling.swift` before writing:

- Step IDs unique within the catalog (`s1…`, `p1…` style per dish is fine:
  prefix them per menu, e.g. `r-s1`), 2–4 dishes per menu, 2–4 steps per
  dish, 3–30 minutes per step. Each dish's steps are a dependency chain in
  order.
- Every step's `detail` defers to the cook's recipe for doneness and
  temperatures (never "cook 12 minutes and it's done"); the planning
  estimate is the `minutes`.
- `handsOn: false` only for steps that really run unattended (boiling,
  roasting, resting). The attention-overlap warnings depend on it.
- Menus are vegetarian-inclusive: at least two of the new ones meat-free.
- Weeknight-realistic total times (35–75 minutes); one "Sunday" menu up to
  ~2 hours is fine.
- Symbols from SF Symbols that exist on iOS 17 (check the name).
- Update `logic-checks/mirror-test.cjs` expectations if any assert on menu
  counts, and add one `swift test` case per new menu asserting
  `Scheduling.plan` is feasible for a dinner time two hours out and that
  every step ID in the catalog is unique (there is no such test today —
  `testBackwardPlanConverges` and `testFeasibilityFlagsPastStart` in
  `DinnerTogetherTests.swift` show the style; add a `CatalogTests` class).
  Keep tests synchronous and free of the store unless they are `async`
  (Linux harness rule, `ENGINE_TESTS.md`). State plainly that you have not
  executed Swift; CI will, and the harness's expected test count updates
  itself from the source.

### S3 — App icon: judge the cloche, replace it if you can do better

`DinnerTogether/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is a
1024×1024 cloche I generated in the app's palette (tomato dome, olive
plate, cream ground). Joe favors a cloche. If you redesign it, deliver a
1024×1024 PNG, no alpha, no rounded corners (iOS masks it), legible at 60
px, plus optional iOS 18 dark and tinted variants. If you can only deliver
an SVG, I will rasterize it.

### S4 — Screenshot plan and the Tonight screen

`LISTING.md` lists six screenshots per device from the existing seeded
states. Two questions for you: (1) is that the right story in six frames,
and in that order? (2) The planning ("Tonight") screen is never
photographed — should screenshot #1 be the plan, and if so, specify the
state (menu, time) so I can add a seed. Captioned marketing frames are
optional; if you want them, give me caption text per frame and I will
compose them onto the raw PNGs at the exact App Store sizes.

## Still yours from before

- The run-12 render review of the UI-test attachments (review sheet, delay
  sheet, stale-plan sheet, alerts) when they exist — same format as D1–D4.
- Agent 1's open product question: should the timeline offer "Mark done"
  on a step that was never started at all, or is the confirmation purely a
  safety net?

## Not yours

Signing, the release workflow, project settings, privacy manifest: Agent 1
verifies those. Pricing is decided ($2.99) — argue it in one paragraph if
you disagree, with a reason, not a patch.
