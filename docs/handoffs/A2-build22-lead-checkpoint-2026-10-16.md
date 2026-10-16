# Build 22 temporary lead checkpoint

Joe assigned A2/Codex implementation ownership through October 17, 2026,
10 p.m. America/Denver. A3 resumes ownership then. Coordination: issue #24.

Baseline: `4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667` on `wip/build22`.
Continuation branch: `a2/build22-lead-20261016`.

## Baseline validation

- Native run 38931626337: all jobs passed, including iPhone/iPad UI and core.
- Duo run 38931629825: all three required gates failed. Every part reached
  its suite summary, then hit the post-suite deadline with unreadable results.
  Direct captures survive; these runs remain failures.
- Part 1: 19 executed, 18 passed, test55 failed. The diagnostic reports exact
  simulator `iPhone Duo`, empty hinge, portrait frame 466x678, runner orientation
  0 (unknown). Do not reinterpret unknown orientation as a verified portrait
  pose or credit automatic nightstand coverage.
- Part 2: 19 executed, 18 passed, one skipped (test53). A1 owns the explicit
  platform-selection recommendation and isolated test-only patch.
- Part 3: 18 executed, 16 passed, two failed: test03 launch timed out; test35's
  Page color Done tap did not dismiss the sheet. Cause remains under review.

## First continuation change

Landscape screen captures now use the existing `turnedToReading` renderer
before PNG export and image attachment. A3's handoff identifies an orientation
flag dropped by raw PNG export. Preserve separately named, unmodified screen
and app captures and their provenance. This fixes the export path; a new native
capture must establish the rendered result. No app layout or gate changes.

## Ownership boundaries

- A2: integration, runtime/harness changes, workflow management and readiness.
- A1 (assigned via issue #24; acknowledgment pending): independent Duo verdict,
  test53 selection, raw capture review, hardware checklist, and reproducer for
  the latent mainonly Bash 3.2 concern. No overlapping app/harness edits.
- A3: requested to pause implementation and push unfinished checkpoints;
  handoff received in issue #24. Release requires Joe's explicit word.

## Remaining work

Investigate Duo finalization hangs without converting incomplete runs to passes;
verify test35 dismissal and test03 launch failures; validate landscape export;
resolve test53 with A1. Tent/cover rotation, actual alarm delivery, charging
auto-entry, and other physical-device checks remain on the October 23 checklist.
Do not treat native baseline success as validation of continuation changes.

The continuation branch's non-wip name triggers native-validation on code push.
No TestFlight upload or release is requested by this checkpoint.

## A1 review follow-up

A1 acknowledged the assignments and supplied read-only findings. Harness changes
are staged on `wip/a2-build22-harness-20261016` for review while native run
38947972243 validates the orientation export commit `ff86f2a`:

- Exclude test53 only on the exact selected closed/default-hinge Duo simulator.
  Filter after sharding, retain all other assignments, recompute counts and
  report missing Duo rotation coverage. Ordinary iPhone remains required.
- Reject invalid shard indices and empty/zero-count test selections before
  invoking Xcode. This prevents both the latent Bash 3.2 empty-array crash and
  accidental unfiltered execution. No skipped-test allowance is introduced.
- Eight targeted selection/guard regression checks pass; the full fake-toolchain
  suite is rerun before publishing. These checks do not validate native behavior.

A1's proposed `.unknown` accommodation for test55 is not adopted. Automatic entry
remains unverified on closed Duo; an explicit manual/automatic test split has
been requested. Test03/test35 remain open pending targeted native evidence.

Baseline capture provenance was read directly: screen pixels 1206x2622,
imageOrientation=2; app comparison 2622x1206 with the same orientation flag;
application/window bounds 874x402. This supports normalizing the screen route;
new screenshots must still verify the visible result.

## Evening continuation: finalization and explicit nightstand coverage

Current release intent: Joe requested Build 22 in TestFlight today after
required checks pass. A2 owns implementation, dispatch and upload until
Saturday October 17 at 10 p.m. America/Denver. A3 resumes ownership then.
The former October 23 physical-Duo assumption is superseded: Joe will have
hardware in December; automatic tent/nightstand hardware checks remain open.

Candidate baseline `772f8be14924154ac3084f28c67ed249d324288c` passed native
validation 38953971764. Duo run 38966260203 failed all seven UI job gates:
five job logs had zero test failures, iPad test04 hit a snapshot timeout,
and closed-Duo test55 could not demonstrate automatic nightstand entry.
All UI result exports failed; logs alone do not credit a completed run.

Following A1's corrected recommendation in issue #24, increase the
post-suite idle allowance from 120 to 300 seconds. This is a candidate
remedy, not evidence that finalization is solved. Preserve the process,
skip/count and attachment-export gates. Keep the iPad test unchanged.

Split timer coverage: test55 manual, test56 dark, test57 automatic entry,
landscape fit, suppression, re-entry and upright dismissal. The exact
closed/default-hinge Duo simulator excludes rotation-only tests 53 and 57
after sharding and reports the missing coverage as UNVERIFIED. Ordinary
iPhone keeps both strict rotation tests; unknown orientation earns no pass.
No app runtime code changes are part of this patch. New native and Duo
validation must match the published commit before release.

Local verification: all 25 fake-toolchain harness scenarios passed, including
explicit exit-124 checks for both mid-run hangs. Also passed: 10 log-parser,
seven screenshot-process, 10 selection and four real-process deadline checks.
The hang fixture now emits the suite-start marker so it tests a mid-run
hang rather than the no-start reboot path. Shell syntax and diff checks
passed. No native Swift/Xcode execution is available in this Linux session;
the new UI test still needs the native build and simulator runs.

## Release-readiness correction after A1's preflight

A1 identified an empty required-reason API declaration. Confirmed against
production `@AppStorage(TonightGlass.key)` usage in PlanView and CookingView,
not only the DEBUG-only direct UserDefaults call. These use app-local
standard defaults; no shared-suite defaults usage was found. Add category
NSPrivacyAccessedAPICategoryUserDefaults with CA92.1, matching Apple's
approved app-local reason. The existing B114 entry already includes the
manifest in the app resource build phase. No widget defaults access was found.

The corrected candidate also incorporates the previously isolated retry
finalization consistency patch: one 300-second setting for main and retry
commands, retry completion markers, and the matching wrapper default. Four
deadline checks and three targeted retry scenarios passed on that patch.

Because a release must match its validated commit, supersede the 6b320f4
validation runs (38979495541 and 38979504518) with runs of this correction.
Do not credit the old candidate's results to this new candidate. Preserve
the completed historical runs as evidence; no TestFlight upload has started.

A1's SDK build-number parsing errors support a toolchain investigation,
but their causal link to the finalization hang is not yet demonstrated.
Keep the export/process gates intact. If 300 seconds still times out,
inspect the new log and isolate the toolchain/result-writing problem
before choosing another runner or Xcode version.
