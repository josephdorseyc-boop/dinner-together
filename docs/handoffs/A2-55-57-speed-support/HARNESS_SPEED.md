# Harness-local speed proposal (A2 support)

Baseline: freshly fetched `wip/own-recipes` exact SHA `393bc9559446cf45fdd89b8df98c4ac2c88c31bd`. Isolated detached checkout under `team-support/speed-harness/source`. A3 already owns parallel DT_PART scheduling; this proposal changes no workflow, scheduling, CI invocation or active branch.

## Concrete redundant work

`pinnedBarTop(excluding:)` enumerates the two pinned queries, then reads each qualifying bar frame five times (height, maxY, minY, target comparison, result mapping) and app.frame twice per bar. Each property resolution appears separately in prior native logs; in a representative AX3 cycle (prior `38628522264` iPhone log, around elapsed 114.99–116.58 seconds) repeated `tonight-primary`, Selected-caption and target-application resolves dominate the interval. These calls recur in each comfortable-visibility/scroll-target calculation.

The patch reads each existing bar frame once and screen frame once per function call, then evaluates exactly the same geometric predicates locally. Qualifying geometry reads become 5 per bar → 1 per bar; screen frame reads become 2 per bar → 1 per call. Nonqualifying frames still cost one read; there is no persistence across helper calls, gestures, layout changes, device changes or tests. Every call freshly enumerates captions/buttons and checks existence. This retains changing pinned-bar sizes at AX3.

## Delivered patch

`pinned-bar-geometry-snapshot.patch` modifies ONLY `pinnedBarTop` (13 added/removed lines overall). It preserves both query predicates, strict/inclusive boundaries, target exclusion, selected minimum top, zero-height handling and absent-bar behavior. No visibility/assertion/time allowance/retry/gate changes.

A2-52's optional bounded dragStart patch edits different hunks and remains compatible. Fresh SHA393bc95 has not integrated that optional bounds patch; this speed proposal neither duplicates nor applies it.

## Checks

- `git diff --check`: pass.
- Reverse apply check against edited exact-head isolated worktree: pass.
- `verify-pinned-geometry.py`: 10,010 deterministic geometry-equivalence cases passed (random screens/bars/targets, exact .6 threshold, +1 maxY tolerance, hidden/empty bars, excluded target); property-count model confirms reduction above.
- Native compile/runtime cannot be run on this Linux host. The model validates geometry equivalence, not XCTest performance. Wall-clock improvement must be measured on A3's next native pass; no speedup factor is claimed.

Recommend A3 consider this as a small follow-up after the active run: it avoids changing current runtime or workflow, keeps all coverage, and eliminates a repeated accessibility-RPC cost rather than extending timeouts or reducing checks.
