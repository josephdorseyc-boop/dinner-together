# A1 UI-test handoff — XCUITest target for the interactive flows

Agent 1 (engineering verification) → Agent 3 (build owner). Against r8,
commit `0a63a87`. Apply in order; each patch is `diff -u` with `a/`/`b/`
prefixes.

## The patches

**A1-U1-app-seed-hook.patch** — `DinnerTogether/DinnerTogetherApp.swift`,
`DinnerTogether/CookingView.swift`. (1) DEBUG-only `DT_SEED_JSON` launch
environment variable: `DinnerTogetherApp.init()` writes the payload to the
store's file before `SessionStore` is created, so a UI test launches into
its seeded state. Release builds ignore the variable entirely; the hook
never deletes (screenshots.sh keeps writing seeds via simctl). The App's
store moved from a property initializer to an explicit `init()` so the
write provably happens first — same main-actor context as before.
(2) Two invisible test hooks, no copy or behavior change:
`.accessibilityIdentifier("serving-time")` on the DINNER AT readout and
`"timeline-step-<id>"` on timeline step cards.

**A1-U2-ui-test-target.patch** — new `DinnerTogetherUITests/` target (3
Swift files), `project.pbxproj`, shared scheme. `UITestSupport.swift`
holds the in-test seed builder (same JSON shape `SessionStore` decodes as
`seed-sessions.py`; validated structurally — see below) plus the base
class and the 9 flow implementations. `DinnerTogetherUITests.swift`
runs flows 1–7 + the AX pass on iPhone (9 tests);
`DinnerTogetherUITests_iPad.swift` re-runs flows 1 and 3 on iPad (2
tests). pbxproj follows the file's hand-written style (T003/D003/D004/
S003/F003/R003/C030–C032, groups G005/P003); target type
`com.apple.product-type.bundle.ui-testing`, `TEST_TARGET_NAME =
DinnerTogether`, no `BUNDLE_LOADER`/`TEST_HOST` (those are unit-test-only),
bundle id `com.example.dinnertogether.uitests`. Scheme: T003 builds for
testing, added to the Test action.

**A1-U3-harness.patch** — `native-validation/run-native-pass.sh`. New
required XCUITest section: `test-without-building -only-testing:` per
device class, counts from the result bundle (expected counts from the UI
test sources: 9 + 2), failing on executed < expected, any failure, any
skip; keep-always attachments exported via `xcresulttool export
attachments` into `results/ui-screenshots/<device>/` (published to
`ci-results` by the existing workflow step — no workflow change needed),
failing when tests ran but no PNGs exported.

**A1-U4-dryrun.patch** — `native-validation/dry-run/run.sh` (+4
scenarios: no UI tests executed, one failing UI test per device,
attachment export failure, skipped UI test) and the fake toolchain
(`xcodebuild` UI branch keyed by `-only-testing`, `xcrun xcresulttool`
`export attachments` + per-device summary counts).

**A1-U5-docs.patch** — `UITESTS.md` (local runs, per-test assertions) and
`docs/evidence/run-UI-README-DRAFT.md` (what each attachment should show;
Agent 3 fills in the run number).

Dependencies: U2 needs U1 (seeds + identifiers); U3 needs U2 (the target
it runs); U4 needs U3 (the gates it proves); U5 stands alone. No engine,
store, model, or existing unit-test changes. Marketing version and build
number untouched.

## What I verified, by tier

- **Supplemental check (dry run, executed):** all 16 dry-run scenarios
  pass, including the 4 new UI failure paths and the 12 pre-existing
  ones unchanged. The gates provably fail when UI tests don't execute,
  when one fails, when attachments are missing, and when a UI test is
  skipped.
- **Supplemental check (seed validation, executed):** a Python mirror of
  the Swift seed builder produces payloads structurally identical to
  `seed-sessions.py` for the three shared scenarios (keys, states, times,
  minutes), and both stale seeds satisfy the real `staleStatus()` logic.
- **Source review:** pbxproj referential integrity (all 16 new object
  IDs defined, no dangling references); scheme XML well-formed;
  `bash -n` clean on all touched scripts.
- **Not verified:** Swift compilation of the new/changed sources (no
  Swift toolchain on my machine), XCUITest execution, and the attachment
  export path — the first CI run is the first execution, as briefed.

## What I expect the first CI run to complain about (most likely first)

1. The hand-edited pbxproj — a missed key (`TEST_TARGET_NAME` spelling,
   a build-phase ordering Xcode dislikes) fails `build-for-testing`.
   The patch is small and the failure will be specific; fix forward.
2. `xcresulttool export attachments` argument shape on Xcode 16.4 — if
   the subcommand differs, the attachments log will say so and the gate
   fails loudly (by design).
3. A query miss in the tests (most likely: the `timeline-step-s2` card
   container with `children: .contain`, or the `Completed (` disclosure
   label). The test names the missing element; the fix is a query tweak,
   not app logic.

## Open questions (not blocking)

- Flow 6 reaches the unstarted-completion confirmation via a seeded
  cooking record with no `actualStart` — the only UI-reachable path,
  since `startStep` always records the start. Product question for
  Agent 2: should the timeline offer "Mark done" on never-started steps
  at all, or is this confirmation purely a safety net?
- The +10-minute assertion round-trips displayed times through a
  short-style `DateFormatter`, assuming the simulator uses the host
  locale (true for CI's en_US runners).
- I did not add the UI target to the `supplemental` dry-run job's
  expectations beyond the 16 scenarios — nothing else references the
  old 12-count except `dry-run/run.sh` itself, which is updated.
