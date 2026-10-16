# A2 independent visual/product review for A3

Source reviewed: `2afd76db20504a4a68f035ea5f3c997928cbd746` (the active run's source). Render evidence: ci-results commit `f935826`, RUN.txt confirms run `38628522264`, source `89db1f7e17243cd51e0092269d49a4c02a72f402`. `git diff 89db1f7 2afd76d -- DinnerTogether/PlanView.swift DinnerTogether/ContentView.swift` is empty: the reviewed product implementation is unchanged from that render source, so the discrepancy remains relevant to the active run.

## Confirmed observations

1. **The light status-bar acceptance remains unmet after recipe navigation.** Current-run `ui-screenshots/iphone/r22a-tonight-cover-pastel.png` and `r24b-a-with-photo.png` show a black clock, WiFi and battery over the full-bleed pale photo. The navigation title is white. `r24c-b-without-photo.png` still has a black clock over the darker notebook's upper left after switching to a recipe without a photo. By comparison, `09-tonight-first-launch.png` and `r24d-tonight-first-launch-dark.png` have white status indicators. This is a rendered product discrepancy independent of the three reported XCTest failures. It appears associated with returning from Recipes, rather than only photo brightness.

   Original evidence: [photo A](https://github.com/josephdorseyc-boop/dinner-together/blob/f935826/ui-screenshots/iphone/r24b-a-with-photo.png), [photo-free B](https://github.com/josephdorseyc-boop/dinner-together/blob/f935826/ui-screenshots/iphone/r24c-b-without-photo.png), [pale photo](https://github.com/josephdorseyc-boop/dinner-together/blob/f935826/ui-screenshots/iphone/r22a-tonight-cover-pastel.png), [first launch](https://github.com/josephdorseyc-boop/dinner-together/blob/f935826/ui-screenshots/iphone/09-tonight-first-launch.png).
2. Full bleed, the frosted card, lower fade and separation of Tonight from the status bar are present in these standard-size captures. The approved aesthetics should be retained.
3. The standard-size long recipe title is partly below the pinned footer in `r24b` and `r22a`. A scrollable page can legitimately begin this way; the screenshot alone does not prove that the title is inaccessible. It does establish that the pinned area obscures the title at rest. No successful AX3 Tonight-cover render was produced for the failing cover test, so do not declare AX3 layout acceptance from the standard render.
4. SUMMARY.md records 207/207 iOS unit tests, 43/45 iPhone UI tests and 22/23 iPad UI tests; retries give no passing credit. All three failures must remain open until the active run completes successfully.

## Source inferences requiring native evidence

- PlanView's pinned footer repeats the entire selected title in a dynamic `.caption` with no height bound. A long title at AX3 combines with the headline CTA and tabs to reduce the visible viewport substantially. A corrected test gesture can establish reachability, but does not itself establish comfortable product usability. Check the full title, dinner picker, other recipe chooser and week strip by actual taps at AX3.
- The `.toolbarColorScheme(.dark)` is on PlanView, whereas ContentView applies recipe-derived `.preferredColorScheme` at the presentation root. The rendered discrepancy occurs after recipe navigation; inspect root presentation/hosting status appearance restoration when returning to Tonight. This is a possible explanation, not a confirmed root cause. Do not force the whole Tonight page into dark mode just to make the clock white.
- `coverUnderBar` uses global cover-bottom `> 160` as the switching threshold rather than a measured navigation/status lower boundary. A render at the transition is needed; source alone cannot verify the restored bar's legibility.
- `tableGlass` contains real environment branches for Reduce Transparency and Increase Contrast, but `-dt-solid-cards` exercises a debug override. A solid debug screenshot proves the solid appearance, not that the actual system settings or VoiceOver behavior were tested.

## Minimal optional layout proposal (not patched)

If native AX3 inspection confirms the footer leaves too little usable content, consider reducing repeated visual information: show a short “Dinner selected” caption at accessibility sizes, keep the full title in the scrollable recipe heading, and expose the full selection through the footer's accessibility label/value. Keep the primary action text legible and multiline; do not clamp Dynamic Type, shrink the text, or remove full-title access. This would require updating selected-title-dependent tests intentionally, so it is a follow-up product proposal, not a safe blind patch to the current run.

## Recommended A3 release gates

- Complete the active run without changing its source underneath it.
- Inspect the NEW run's `r22a`, `r24a/b/c/d`, and first-launch images. Verify status indicators are light at the top after recipe selection, after returning from Recipes and Cooking, after switching to a photo-free recipe, and after relaunch; inspect the scroll transition to plain chrome.
- Use the recovered AX3 test output to inspect title reachability and the pinned footer; a green assertion is necessary but not the complete visual review.
- Retain separate pending device-only checks for VoiceOver, actual Reduce Transparency/Increase Contrast, timers across compact/regular layout changes, and the intended iPhone device.

No source changes, remote changes or new native run were made by this reviewer. No Apple runtime is available here; observations above are limited to retrieved native evidence and source inspection.
