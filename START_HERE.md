# Dinner, Together v0.2.8

> **Recovery candidate r9 (not a release):** `main` at `5ad370e`+docs. UI tap-through executed on CI (iPhone 10/10 flows, iPad 2/3), 69/69 unit tests, nine menus, App Store readiness in `release/` and `docs/store/`. Read `docs/evidence/run-22/README.md`, then `RECOVERY_HANDOFF.md`;
> recovery changes, revised after review. Read `RECOVERY_HANDOFF.md` first; the patch
> against pristine v0.2.8 is `recovery-candidate-v028.patch`. Version/build
> intentionally unchanged. To run the engine/store tests without Xcode:
> `swift test` (see `ENGINE_TESTS.md`). No Mac at all? `CI_SETUP.md` runs the
> whole native pass on GitHub's macOS machines.

Open DinnerTogether.xcodeproj on a Mac with Xcode. The shared DinnerTogether scheme includes native tests.

Meal readiness now considers every step, so marking a final step done out of order cannot conceal unfinished work. Estimate edits are rejected after cooking begins, matching the planning UI. Warning expansion and previous fixes are preserved.

Validation: 65 supplemental JavaScript outcome assertions and five asynchronous reconciliation scenarios pass. Four native regression tests were added, not executed. Native compilation, XCTest, UI rendering, and device notification testing remain pending. See HANDOFF.md and VALIDATION.md.
