# AX3 scrolling review for A3 (A2 support)

Reviewed source at exact commit `2afd76db20504a4a68f035ea5f3c997928cbd746` in an isolated detached worktree. No active branch, remote, CI or application code changed.

## Evidence

Fetched `ci-results`; RUN.txt identifies native run `38628522264`, source `89db1f7e17243cd51e0092269d49a4c02a72f402`. Both test18_recipeReviewGateAX3 and test42_recipeCoversAX3 failed the `tonight-recipe` comfortable-visibility assertion after 12 drags. Their last 12 scrolling gestures are identical: first `.47 -> .26`, then eleven `.71 -> .70` center-column gestures. Test18 also reached the three-minute test allowance.

A3's latest commit correctly uses the measured comfort zone midpoint rather than screen midpoint, keeps the comfortable-visibility assertion intact, and reports target frame/hittability/zone on failure. That directly addresses the tiny-drag stall supported by those logs. We should let live run `38648551795` establish whether it resolves the observed failure.

## Remaining source-level gap and optional patch

`dragStart` searches only button frames. It can choose a point inside the pinned static Selected caption because captions are not buttons; its candidate order explicitly reaches `.71` after `.55`, `.47`, `.63`, `.39` are blocked. Source comments claim starts stay above the pinned bar, but no bound enforces that. The existing captions are included in `comfortZone` calculation, so scrollTo already has the required geometry.

`ax-scroll-start-bounds.patch` is a minimal 13-line optional test-harness patch against exact latest commit: give scrollTo's measured zone to dragStart, exclude candidates within 12 points of its edges, and keep its fallback at the zone midpoint. Other dragStart callers retain existing behavior. No assertions, retry counts, test gates or product code are relaxed.

The patch prevents this unsafe candidate selection by construction. Whether the observed `.71` starts actually hit the pinned caption is an inference: prior logs do not include caption/title geometry at failure. No need to interrupt the active run; A3 can retain this as a focused follow-up if the live diagnostics still implicate gesture starts.

## Supplemental checks and limits

- `git diff --check` passed.
- Patch reverse-application check passed against the isolated edited worktree.
- `verify-scroll-start-geometry.py`: five supplemental geometry scenarios passed, covering the AX-like blocked-center candidate, all-candidates-blocked fallback, nonzero screen origin, iPad height and ordinary clear-screen behavior.
- The geometry script models selection math, not UIKit gestures. This Linux host has no Swift/Xcode/native simulator toolchain; native compile and test18/test42 verification remain with A3's run.

Suggested next validation: inspect native run's test18/test42 outcomes and new frame/zone failure diagnostic. If green, avoid replacing A3's passing fix solely for a theoretical risk. If these tests fail with valid geometry and insufficient drags, apply the bounds patch in A3's branch and run the focused tests before the full pass.
