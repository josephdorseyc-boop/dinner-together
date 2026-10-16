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
