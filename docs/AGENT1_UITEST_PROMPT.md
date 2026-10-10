# Dinner, Together — implementation brief for Agent 1: XCUITest target

Agent 1 — this is the XCUITest assignment you recommended in your r7
findings, handed to you as an implementation task on top of your
verification role. It has a verified starting point and a running CI loop.
Read the attached files in the order below (much of it you have already
verified), then deliver the focused candidate described in §5.

## 1. Product, in brief

The app plans the steps of several dinner dishes backward from a chosen
serving time and helps the cook recover when timing slips. Guiding question:
**"What do I do right now?"** Calm, honest, offline, no account. Warm cream /
tomato / olive palette; large readable times; iPad gets a sidebar and a
two-column cooking screen. Timer expiry means "check the food," never
"done." Nothing changes the chosen dinner time or a running timer silently.
Icon work is postponed (Joe favors a cloche). Do not revisit any of this.

## 2. Where the project stands (facts, with evidence tiers)

The recovery candidate is at **r8**, commit `0a63a87` on
`https://github.com/josephdorseyc-boop/dinner-together` (branch `main`).
The ZIP you receive is a snapshot of that commit; the repo is the source of
truth.

Verified by execution — GitHub Actions, macOS 15.7.9, **Xcode 16.4**, iOS
18.5/18.6 simulators (CI runs 5–9, all green):
- App and test targets compile: 0 errors, app target 0 warnings.
- **XCTest: 61/61 on an iPhone 17 simulator and 61/61 on an iPad (A16)
  simulator**, 0 failed, 0 skipped (Xcode result bundles).
- `swift test` 61/61 on macOS and on Linux (a `Package.swift` harness
  compiles the real engine + store + test file without Xcode).
- 28 seeded screenshots per run (iPhone + iPad, light + dark + accessibility
  text), reviewed: `docs/evidence/run-5/` and `docs/evidence/run-9/`.

**Not yet performed by anyone:** a physical device, VoiceOver reading order,
notification delivery, haptics, and — your assignment — any **tap-through**
of the app. The review sheet, the delay sheet, the stale-plan sheet, and the
confirmation dialogs have never been rendered.

All findings from both reviewers (yours and Agent 2's) have been closed by
execution. Nothing is open except the next validation
target, which is this brief.

## 3. Reading order

1. `START_HERE.md`, then `RECOVERY_HANDOFF.md` (top notes are newest; §1
   lists every changed file; §2 behavior; §3 validation; §4 open questions).
2. `CI_SETUP.md`, `ENGINE_TESTS.md`, `native-validation/README.md` — how the
   validation loop works and what its gates require.
3. `docs/evidence/run-9/README.md` and the PNGs — what the screens look like.
4. `RECOVERY_COPY_AND_FLOWS.md` — screen copy; §A implemented, §B
   implemented (copy only), §C stale-plan recovery still a proposal.
5. Source: `DinnerTogether/CookingView.swift`, `Sheets.swift`,
   `DinnerTogetherApp.swift` (the `LaunchOptions` debug hooks),
   `ContentView.swift`; `DinnerTogether.xcodeproj/project.pbxproj` (hand
   written, small, explicit IDs — it has never been opened in Xcode's UI,
   only built by `xcodebuild`); `DinnerTogetherTests/DinnerTogetherTests.swift`;
   `native-validation/run-native-pass.sh`, `screenshots.sh`,
   `seed-sessions.py`, `dry-run/run.sh`; `.github/workflows/native-validation.yml`.

## 4. Roles and coordination

- **Agent 3** owns the build and integrates. It pushes to `main`, runs CI,
  reads results from the `ci-results` branch, and circulates evidence. You
  do not have push access; you return patches.
- **You (Agent 1)** own **UI automation and the rendering of interactive
  flows** for this assignment. Because you will be implementing, the
  independent verification of this work comes from CI execution (Agent 3)
  and from Agent 2's review of the rendered attachments; keep your own
  claims to what you can show. Work in an isolated copy. Do not edit `Scheduling.swift`,
  `SessionStore.swift`, `Models.swift`, or the unit-test file's existing
  tests; those are verified and owned elsewhere. Small, explicit additions
  to `DinnerTogetherApp.swift` (`LaunchOptions`) are expected and allowed,
  DEBUG-only. Do not bump the marketing version or build number.
- Deliver **one `.patch` per concern** against commit `0a63a87`, `diff -u`
  with `a/` `b/` prefixes, named `A1-U<n>-<slug>.patch` (the `U` keeps
  them distinct from your review findings `A1-1…A1-4`), plus the files
  themselves. Say explicitly which patches depend on which. **Attach the
  patch files** — twice now only the findings document arrived.
- Label every claim by how you know it: **source review**, **supplemental
  check** (dry run, scripts), **Swift compilation**, **XCTest execution**,
  **simulator rendering**. Your Linux toolchain can compile and run the
  `Package.swift` harness but not XCUITest or the app target; say so, and
  write for the CI run to be the first execution of the UI tests. Do not
  describe anything as working until a CI run shows it.

## 5. Assignment: an XCUITest target that photographs the interactive flows

Build a UI-test target that runs on the existing GitHub macOS runner, drives
the real app in the simulator, and attaches screenshots of the flows the
static screenshot pass cannot reach. Verified end to end by CI.

### 5a. Seeding from a UI test
`screenshots.sh` seeds the app by writing `dinner-together-v2.json` into the
app's Documents via `simctl`. A UI-test runner cannot write into the app's
sandbox. Add a DEBUG-only launch option — suggested: environment variable
`DT_SEED_JSON` carrying the seed file's contents (base64 if you prefer) —
that `DinnerTogetherApp` writes to the store's file **before** `SessionStore`
is created, only when present, only in DEBUG. Reuse
`native-validation/seed-sessions.py`'s scenarios; do not invent new seed
formats. Keep the existing `-dt-open-cooking` and `-dt-inert-reminders`.

### 5b. Flows to exercise (each with `XCTAttachment` screenshots,
`lifetime = .keepAlways`, named by flow and step)
1. **Review dinner time** (seed `late-prep`): open the sheet → screenshot;
   assert the sheet shows "Chosen dinner time" and "Estimated readiness";
   tap "Move dinner to …" → assert the DINNER AT time advanced by the
   displayed amount and the notice disappeared → screenshot; tap "Undo last
   action" → assert the previous time and the notice return.
2. **Review sheet, lower bound** (seed `expired-timer`): assert "Earliest
   readiness" and the amber note; "Keep … for now" dismisses and changes
   nothing.
3. **Adjust time** (seed `on-schedule`): "Adjust time" → "Add 10 minutes" →
   delay sheet screenshot (explanation lines; early-finish note if any) →
   "Add 10 minutes" → assert DINNER AT moved 10 min; "Undo".
4. **Expired timer completion** (seed `expired-timer`): "Mark done after
   checking" → assert the step reaches Done and the notice recomputes.
5. **Blocked start** ("Start anyway"): seed so a dependent step is due while
   its prerequisite is unfinished; tap "Review start" in the timeline →
   alert screenshot → Cancel (no change) → "Start anyway" (starts).
6. **Unstarted completion confirmation**: "Mark done" on a never-started
   step → alert screenshot → "Mark done" → completed with "start not
   recorded" in the Completed group.
7. **Stale plan** (seed with `lastOpenedAt` yesterday and progress): launch
   → the non-dismissable sheet → screenshot → "Resume this plan"; then the
   no-progress variant → "Keep menu, fresh time".
8. Repeat 1 and 3 on the iPad destination; one pass of 1 at
   accessibility text size if the launch option for content size can be set
   from the test (if not, say so).

Use accessibility identifiers only where labels are ambiguous; prefer the
existing accessibility labels (they are part of scenario 11 and are
deliberately descriptive). Do not change user-visible copy to make tests
easier; if a label is genuinely untestable, report it as a finding.

### 5c. Project and scheme
Add the target to `project.pbxproj` following its existing style (short
explicit IDs, one object per line): `PBXNativeTarget` of type
`com.apple.product-type.bundle.ui-testing`, `TEST_TARGET_NAME =
DinnerTogether`, `PRODUCT_NAME = "$(TARGET_NAME)"`, dependency on the app
target, `LD_RUNPATH_SEARCH_PATHS` as the unit-test target has, Debug and
Release configurations, sources phase, product reference in the Products
group. Add it to the shared scheme's Test action. This is the riskiest part:
the project has only ever been built by `xcodebuild`; expect the first CI
run to tell you what you got wrong, and write the patch so that is cheap to
fix.

### 5d. Harness and workflow
Extend `native-validation/run-native-pass.sh` with a required **UI tests**
section (`xcodebuild test-without-building … -only-testing:DinnerTogetherUITests`
on the iPhone, and the subset in 5b-8 on the iPad), reading counts from the
result bundle as the unit-test section does, failing on `executed <
expected` (count `func test` in the UI test file), on failures, and on
skips. Export attachments from the `.xcresult`
(`xcrun xcresulttool export attachments --path … --output-path …`, Xcode 16)
into `results/ui-screenshots/<device>/` so they publish to the `ci-results`
branch like the static screenshots. Extend `dry-run/run.sh` and the fake
toolchain so the new gates are proven on the failure paths before CI
(no UI tests executed, one failed, attachments missing). Keep the workflow's
gate semantics: red whenever something required could not run.

### 5e. What not to do
No TestFlight, signing, Developer Program, or bundle-ID changes. No timer
extension, no stale-plan redesign (§C stays a proposal), no changes to
thresholds or copy, no new persisted fields. No screenshot-diff "golden
image" comparisons — attachments are evidence for humans, not oracles.

## 6. Acceptance

- The CI macOS job is green with the UI tests included, and `SUMMARY.md`
  shows the UI-test counts from the result bundle.
- Attachments for every flow in §5b appear on the `ci-results` branch and
  are listed in a `docs/evidence/run-<n>/README.md` you draft (Agent 3 fills
  in the run number).
- The dry run proves the new gates fail when UI tests don't execute.
- Unit tests remain 61/61 on both simulators; static screenshots remain 24
  required + 4 bonus; nothing in the engine or store changed.

## 7. Deliverables

1. Patches `A1-U1…` against `0a63a87` (UI test target + `LaunchOptions`
   seed hook; harness + dry run; workflow; docs), with a one-paragraph
   `A1_UITEST_HANDOFF.md`: what each patch does, what you could and could not
   verify, the exact validation performed and its tier, open questions,
   and what you expect the first CI run to complain about.
2. `UITESTS.md`: how to run the UI tests locally on a Mac and what each test
   asserts.
3. A draft `docs/evidence/run-<n>/README.md` describing what each
   attachment should show, so Agent 2 can review the renders against intent.

Begin by reading the source and the evidence. Proceed autonomously with
reversible work; ask Joe only for a product choice that blocks you. Be
specific and candid; the standard is a calmer app that remains honest about
cooking — and a validation loop that cannot go green by omission.
