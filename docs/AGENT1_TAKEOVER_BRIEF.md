# Dinner, Together — Agent 1 takeover brief (Agent 3 paused)

From: Agent 3 · October 10, 2026, 12:15 AM MT · via Joe
Repo: `josephdorseyc-boop/dinner-together`, `main` at `5ad370e` (+ this
docs commit). You have GitHub access; **you are the integrator until
Agent 3 resumes**: apply, push, read CI, keep the loop honest. Rules
unchanged (`REVIEW_REQUEST_r4.md`): cumulative tree, tiers labeled, never
claim what was not executed. Your patch series for this phase: `A1-T<n>`.

## Where everything stands (read `docs/evidence/run-22/README.md` first)

- Unit tests **69/69** on iPhone 17 and iPad (A16) simulators, `swift test`
  69/69 on macOS and Linux. Build 0 errors.
- XCUITest: **iPhone 10/10**, iPad 2/3. The remaining iPad item is the
  "Adjust time" popover (frames unlaid out for XCUITest). From run 23 it is
  a non-strict `XCTExpectFailure`, reported in `SUMMARY.md` every run.
- Two real app bugs were found by the UI tests and fixed on `main`:
  (1) `CookingView` had two `.alert` modifiers on one view, so the
  blocked-start alert never presented → one `.alert(item:)` with
  `CookingPrompt`; (2) the delay sheet is now handed its proposal 350 ms
  after the dialog action (iPad popover dismissal could drop it — the
  second half of that is still unverified, see below).
- App Store readiness is in the repo: `release/` (cloud-signed archive →
  export → upload, `release/README.md` is Joe's checklist),
  `.github/workflows/release.yml` and `store-assets.yml`, icon + asset
  catalog, `PrivacyInfo.xcprivacy`, Info.plist keys, `docs/store/`,
  `docs/privacy.html`, `docs/support.html`. Your `AGENT1_APPSTORE_BRIEF.md`
  review of the pipeline is still wanted — nobody has executed signing.

## How to read CI (no artifact download needed)

Every push runs `native-validation`. Results are force-pushed to the
`ci-results` branch (and `ci-results-linux`); App Store screenshots to
`store-assets`. Read with plain git:

```
git fetch --force --depth 1 origin '+refs/heads/ci-results:refs/remotes/origin/ci-results'
git archive origin/ci-results | tar -x -C /tmp/ci
cat /tmp/ci/RUN.txt /tmp/ci/status.txt /tmp/ci/SUMMARY.md
ls /tmp/ci/ui-screenshots/iphone      # UI-test attachments, named by flow
```

Verdict lines also appear as check-run annotations
(`gh api repos/<repo>/check-runs/<job id>/annotations`). The gate is
`status.txt` `REQUIRED_FAILURES=0`. The unit step runs only
`DinnerTogetherTests`; the UI step runs each UI class with per-test time
allowances; expected test counts come from `grep -c 'func test'`.

## Your queue, in order

1. **Read run 23** (`5ad370e`). Expected: iPhone 10/10, iPad 3/3 with 1
   expected failure reported, gate green. If anything else is red, fix
   forward.
2. **A1-T1 — Flow 8 at accessibility size.** The
   `-UIPreferredContentSizeCategoryName` launch argument is not honored;
   `08-ax-review-sheet.png` renders at default size. Add a DEBUG launch
   option in `LaunchOptions` (e.g. `-dt-type-size accessibility3`) and apply
   it in `DinnerTogetherApp.body` with
   `.transformEnvironment(\.dynamicTypeSize) { if let s = LaunchOptions.forcedTypeSize { $0 = s } }`;
   have `flowReviewDinnerTimeAXTextSize` pass it. Keep the whole thing
   inside `#if DEBUG`; release builds ignore it (same pattern as
   `-dt-open-cooking`). Then the compact notice and Agent 2's S2 header
   stack finally get UI-test renders.
3. **A1-T2 — iPad popover tap (optional, time-boxed).** Evidence:
   `docs/evidence/run-22/ipad/03-after-dialog-tap.png` and the hierarchy
   attachments on the `ci-results` branch (`03-delay-choice-dialog-hierarchy.txt`
   from run 23 on). If a reliable tap path exists (`app.popovers…`,
   coordinates from the dialog's real frame), remove the expected failure.
   If not, leave it documented — it is not a release blocker.
4. **Harness nit:** XCTest's own failure attachments ("UI Snapshot",
   "Synthesized Event") are binary plists; the renamer gives them `.png`
   when the manifest suggests no extension. Give extension-less files
   `.plist`. One line in `run-native-pass.sh`'s rename block.
5. **When Joe says the five secrets are in** (`release/README.md` §1–3):
   Actions → `release` → Run workflow (version `1.0`, submit ✅). Read the
   run's `SUMMARY.md` from its artifact (or ask Joe to attach it). First-run
   failures will be specific (API-key role, bundle ID, export options);
   fix forward. **Never print or log a secret.**
6. **Store screenshots for submission:** run `store-assets` around
   5:30 PM Mountain Time (the runner is set to America/Denver so clocks
   read like dinner), fetch the `store-assets` branch, run
   `python3 release/compose-store-frames.py <checkout> <out>`, zip the 12
   frames for Joe. The October 10 04:00 UTC set is in
   `docs/store/frames-preview/` for layout only.

## Not yours

Product copy, menus, icon, screenshot story: Agent 2 (their brief is
`docs/AGENT2_TAKEOVER_BRIEF.md`). Pricing is decided ($2.99, paid).
