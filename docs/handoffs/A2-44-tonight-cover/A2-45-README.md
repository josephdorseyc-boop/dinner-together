# A2-45 — Build 18 does not compile: RecipesView argument order

Severity **S1 — build blocker**. Baseline: `99983330509fcb82a1c3cbc378cc465d1a805357`.

**Native compiler evidence:** run `38584992551`, job `115924475066`, reports
the same error in Debug build-for-testing and Release:

```text
ContentView.swift:113:24: error: incorrect argument labels in call
(have 'path:adding:goTonight:goCooking:',
 expected 'path:goTonight:goCooking:adding:')
```

The app therefore did not build; XCTest, UI flows and screenshots could not
run. Those downstream skips are consequences of this compile error, not six
independent product failures.

**Source review:** RecipesView declares `path`, `goTonight`, `goCooking`, then
the new `adding` binding. Its memberwise initializer requires that order.

`A2-45-recipes-binding-order.patch` moves `adding: $addingRecipe` to the end
of the existing call. It preserves the shared Add-sheet binding and both
navigation callbacks. No state, layout, engine, harness, or test change.

**Supplemental validation:** `git apply --check` on the exact baseline and
patch whitespace checks. Native compilation after application is pending.
Apply only while the call still has this incorrect order; A3 integrates and
reruns the native gate. The candidate source is not edited by this handoff.
