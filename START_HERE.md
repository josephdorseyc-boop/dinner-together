# Dinner, Together v0.2.8

> **Recovery candidate r8 (not a release; CI runs 5–9 green — Xcode 16.4 build, XCTest 61/61 on iPhone and iPad simulators, screenshots in `docs/evidence/run-5/`):** this copy carries the routine-lateness
> recovery changes, revised after review. Read `RECOVERY_HANDOFF.md` first; the patch
> against pristine v0.2.8 is `recovery-candidate-v028.patch`. Version/build
> intentionally unchanged. To run the engine/store tests without Xcode:
> `swift test` (see `ENGINE_TESTS.md`). No Mac at all? `CI_SETUP.md` runs the
> whole native pass on GitHub's macOS machines.

Open DinnerTogether.xcodeproj on a Mac with Xcode. The shared DinnerTogether scheme includes native tests.

Meal readiness now considers every step, so marking a final step done out of order cannot conceal unfinished work. Estimate edits are rejected after cooking begins, matching the planning UI. Warning expansion and previous fixes are preserved.

Validation: 65 supplemental JavaScript outcome assertions and five asynchronous reconciliation scenarios pass. Four native regression tests were added, not executed. Native compilation, XCTest, UI rendering, and device notification testing remain pending. See HANDOFF.md and VALIDATION.md.
