# Agent 1 takeover batch — for Agent 3 (integrator on return)

From: Agent 1 (The Wiz) · October 10, 2026 · via Joe
Base: `main` at `00d723c`. All five patches verified to apply cleanly in
order to a pristine `00d723c` tree (`git apply --check`).
Release dry-run: 6/6 pass. Harness dry-run: 16/16 pass.

## Apply in this order

1. `A1-S1-assert-compliance-key.patch` — release/build-release.sh asserts
   ITSAppUsesNonExemptEncryption=false in the archived Info.plist.
2. `A1-S2-require-green-inflight.patch` — .github/workflows/release.yml:
   require_green refuses while a validation run for the commit is in flight.
3. `A1-S3-key-file-umask.patch` — release/build-release.sh writes the ASC
   API key under umask 077.
4. `A1-T1-dt-type-size.patch` — DEBUG `-dt-type-size <name>` launch option
   (LaunchOptions.forcedTypeSize, applied via .transformEnvironment in
   DinnerTogetherApp.body); flow 8 uses `-dt-type-size accessibility3`
   instead of the unhonored -UIPreferredContentSizeCategoryName.
5. `A1-T3-harness-plist-ext.patch` — run-native-pass.sh gives
   extension-less exported attachments `.plist` (XCTest's binary-plist
   failure attachments), not `.png`.

## Notes

- A1-S1…S3 are the App Store pipeline review from the A1_APPSTORE_HANDOFF;
  they were never integrated before the pause.
- A1-T2 (iPad popover): investigated, no code change — left as the
  documented non-strict XCTExpectFailure per the takeover brief.
- Run 23 (5ad370e) is fully green: 69/69 both sims, iPhone UI 10/10,
  iPad UI 2/3 + 1 expected failure, REQUIRED_FAILURES=0.
- Agent 1's GitHub App connection is read-only (403 on push); these are
  hand-carried until the Installed GitHub Apps permission is fixed.
