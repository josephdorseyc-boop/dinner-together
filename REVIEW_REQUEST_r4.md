# Review request — Dinner_Together_Recovery_Candidate_v028 **r4**

From: Agent 3 (build owner / integrator) · October 9, 2026
To: Agent 1 (engineering verification) and Agent 2 (product/design review)
Via: Joe (no direct agent-to-agent channel was reachable from my session; I
have not contacted either of you directly)

Both of you receive the **same artifact**:

```
Dinner_Together_Recovery_Candidate_v028r4.zip
SHA-256: <see cover note — compare before reviewing>
```

If your SHA-256 differs from the other reviewer's, stop and tell Joe; we
must all be looking at one build.

## 1. What this build is

A recovery-UX candidate on top of the unmodified v0.2.8 package. Marketing
version/build are deliberately still 0.2.8 / 9; the next canonical number is
assigned at integration. Read in this order: `RECOVERY_HANDOFF.md` (behavior,
changed files, validation, open questions), `RECOVERY_REVIEW.md` (why),
`RECOVERY_COPY_AND_FLOWS.md` (copy; A implemented, B/C proposed),
`CI_SETUP.md` + `ENGINE_TESTS.md` (how to get native results without a Mac).

### Change summary (vs. v0.2.8)

Cooking behavior (r2, unchanged since):
- The cached `pendingServingProposal` and its automatic sheet are gone.
  Timing drift is **derived live** (`Scheduling.readinessReport`) and shown
  inline under DINNER AT: "Running about N min behind", chosen time vs.
  estimated readiness, one derived reason, a quiet "Review dinner time"
  button. No modal opens on its own; nothing is cached, so undo/reset/menu
  change/delay/background cannot leave a stale estimate. Finished dinners
  show nothing.
- Estimate is now-aware (`projectedReadiness`): idle time past a planned
  start counts; an expired timer floors at *now* and the notice says "At
  least N min behind … can't finish before …" (lower bound, not prediction).
  Dependency carry is a running maximum over the dish (your finding 1).
  `expectedMealEnd`, `plan`, `proposeDelay`, `applyDelay` are byte-identical.
- The review sheet reads live state, previews the existing `DelayProposal`
  (explanation + early-finish notes) built from minutes **rounded up**, and
  "Move dinner to X" applies exactly that proposal once, undoably
  (`readinessMoveProposal` / `moveDinnerToEstimatedReadiness`).
- Copy: "check the food; mark this step done when it's ready". PlanView no
  longer says "Running late".
- Thresholds: notice ≥ 1 min, amber ≥ 10 min — named constants, labeled as
  initial UX choices.

Validation tooling (r2–r4):
- `Package.swift` harness: `swift test` compiles the real engine + store +
  the canonical test file on Linux (via a two-type `SwiftUI` stand-in) or
  macOS. 60 XCTest methods, 12 classes.
- `.github/workflows/native-validation.yml` + `native-validation/`: GitHub
  macOS runner builds the Xcode project, runs XCTest on an iPhone and an iPad
  simulator, `swift test`, and seeded simulator screenshots of six recovery
  states in light/dark/large text; artifact upload; a gate that fails the
  job when any required step fails **or cannot run**.
- Two DEBUG-only launch flags (`-dt-open-cooking`, `-dt-inert-reminders`) in
  `DinnerTogetherApp.swift`/`ContentView.swift`; `project.pbxproj` Debug
  configs now define `DEBUG` (r4).
- `native-validation/dry-run/run.sh`: the validation scripts against a fake
  toolchain in nine pass/fail scenarios (runs in CI too).

Exact file list: `RECOVERY_HANDOFF.md` §1. Patches: `recovery-candidate-v028.patch`
(cumulative vs. pristine v0.2.8), `recovery-candidate-r1-to-r2.patch`,
`recovery-candidate-r2-to-r3.patch`, `recovery-candidate-r3-to-r4.patch`,
and `optional-expired-timer-copy.patch` (proposal B, **not applied**).

### Agent 2's pre-run findings — status in r4
1. `#if DEBUG` never defined → **fixed** (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`
   in both Debug configs; pass script verifies `-D DEBUG` in the build log).
2. Incomplete validation could look successful → **fixed** (required-step
   accounting, `status.txt`, non-zero exits, workflow gate requires
   `SUMMARY.md` + `status.txt` + zero required failures; `pipefail` on the
   Linux `swift test`).
3. `grep -c … || echo 0` double-zero counters → **fixed**; executed counts
   verified against the 60 methods in source on iPhone, iPad and `swift test`.
4. (Found by the new dry run) `devices.env` values unquoted → real simulator
   names broke `source` → **fixed**.

## 2. Validation status — labeled precisely

**Executed here (Linux, Node 22), r4:**
- JS model: 120/120 assertions; reconciliation model 5/5.
- Seed files validated through the JS engine model: all six scenarios land
  in the intended state (drift, tone, lower bound, featured expired timer,
  no-notice controls).
- Harness dry run: 9/9 scenarios behave as specified (fake toolchain).
- Bracket-balance check on all Swift files; YAML parse of the workflow;
  `bash -n` on scripts.
- Cumulative patch applies to a fresh v0.2.8 extraction and reproduces the
  candidate tree byte-for-byte.

**Source review only (no execution):** every changed Swift hunk, the
pbxproj edit, the shims. Compiler watch items are listed in
`RECOVERY_HANDOFF.md` §3.

**Not performed by anyone yet:** Swift compilation, XCTest execution,
SwiftUI rendering, simulator or device runs, VoiceOver, notification
delivery. The 60 XCTest methods, the `swift test` harness, the workflow and
the screenshot scripts are **written, unexecuted**. The first CI run is
expected to surface project/SDK issues before it surfaces test results.

## 3. Known limitations and open questions
- `plan()` has the same out-of-order carry shape I fixed in the projection
  (`prevEnd = actualEnd` for a done step). Cosmetic (starts are already
  gated by `dependencyInfo`), baseline behavior, not changed — flagged for
  the implementation owner's call.
- Lower-bound drift ticks up a minute at a time while an expired timer stays
  unconfirmed; the notice and sheet say so. Hiding the Review button in that
  state is a one-line option (`estimateIsLowerBound`), not taken.
- Minute rounding: display rounds to nearest, the move rounds up; a 7 m 20 s
  drift shows "about 7 min" and "Move dinner to 7:08". Caption explains it.
- `completeStepEffects` still computes the plan-anchored estimate for its
  (now history-only) sentence; the notice uses the now-aware projection.
- "Keep … for now" writes no history line (the old `keepServingTime` did).
- B (expired-timer copy) and C (stale-plan recovery) remain proposals; B is
  an unapplied patch.
- Harness/CI first-run risks: Swift 6 Foundation on Linux for
  `URL.documentsDirectory`; `@MainActor` XCTest classes on Linux; the
  Linux-only `SwiftUI` module name; `launchctl` label format in the
  app-running check (it stands down if the format is unknown).
- Screenshots are static states; the review sheet and dialogs need an
  XCUITest target (planned after the first clean run).
- Project file has never been opened by Xcode.

## 4. What I need from each of you

**Agent 1 — engineering verification.** Compile-risk review of every Swift
hunk (watch items in handoff §3), invariant check against AGENT_PROMPT §4,
test quality (behavior, not source-string assertions), harness and workflow
review. If you have *any* Swift 6 toolchain (Mac CLT or Docker), run
`swift test` and report `swift --version`, platform, and per-class results —
that would be the first native execution of anything in this project. If
you have Xcode, run `bash native-validation/run-native-pass.sh` and send
`results/`.

**Agent 2 — product/design review.** Copy and tone of the notice and sheet
(`RECOVERY_COPY_AND_FLOWS.md` §A), the two thresholds, the lower-bound
wording, accessibility labels, the iPad placement, and the B/C proposals.
`optional-expired-timer-copy.patch`: apply or not? Your three pre-run
findings are addressed above — please confirm or reopen.

**Both:**
- Return **reproducible issues ranked by severity** using the format below.
- Keep proposed patches **separate** from the issue list, one `.patch` per
  issue, generated against this r4 tree (`diff -u` with `a/` `b/` prefixes),
  named `A1-<n>-<slug>.patch` / `A2-<n>-<slug>.patch`. Do not edit the
  candidate tree itself; I integrate. If two patches must touch the same
  hunk, say so in the issue and I'll reconcile.
- Label every claim by how you know it: **source review**, **supplemental
  check** (JS model, dry run, scripts), **Swift compilation**, **XCTest
  execution**, or **device/simulator**. Please don't let "it reads right"
  become "it builds".

### Issue format
```
ID: A2-3            Severity: S1 | S2 | S3 | S4
Title: one line
Evidence: source review | supplemental check | Swift compilation | XCTest execution | device/simulator
Repro: file:line or fixture + steps + expected vs. actual (numbers, not adjectives)
Scope: which invariant / scenario (AGENT_PROMPT §4/§6) or copy/flow item
Proposed fix: one line (patch, if any, attached separately as A2-3-<slug>.patch)
```
Severity: **S1** wrong cooking outcome, invariant broken, data loss, or
build cannot proceed · **S2** wrong or misleading information to the cook,
test gap for a stated scenario, validation that could pass falsely · **S3**
copy, layout, accessibility, maintainability · **S4** nit.

## 5. What happens next
I integrate accepted patches into r5, keep the three patch streams separate
in the handoff, and send the same ZIP + SHA-256 to both of you again. Joe
runs the GitHub workflow when he's ready; its artifact comes to me and I
circulate the results with the same evidence labels.
