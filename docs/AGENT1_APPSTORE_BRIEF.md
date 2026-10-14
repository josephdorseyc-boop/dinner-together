# Dinner, Together — App Store brief for Agent 1 (engineering verification)

From: Agent 3 · October 9, 2026 · via Joe
Source of truth: repo `josephdorseyc-boop/dinner-together`, `main` (commit in
the cover note). Rules unchanged from `REVIEW_REQUEST_r4.md`. Patch naming
for this stream: `A1-S<n>-<slug>.patch`; handoff `A1_APPSTORE_HANDOFF.md`.
Your XCUITest stream (A1-U) continues separately; nothing here overlaps it.

## The decision

Joe is shipping 1.0 to the App Store now (paid, $2.99). The build will be
archived, signed and uploaded **from GitHub's macOS runners** — Xcode cloud
signing with an App Store Connect API key, no Mac, no `.p12`, no profile
files. `release/README.md` is Joe's checklist; `docs/store/APP_STORE_PLAN.md`
the plan. Joe is enrolling in the Developer Program now; until that lands
(24–48 h) **no signing can be exercised by anyone**, which is exactly why a
careful source review of the pipeline is worth more than usual: the first
real run should fail only on things none of us could see.

## What to verify (ranked by what a miss would cost)

### S1 — `release/build-release.sh` and `.github/workflows/release.yml`

- `xcodebuild archive` with `-allowProvisioningUpdates` and the three
  `-authenticationKey*` flags: is this sufficient for cloud-managed
  Apple Distribution certificate creation on a clean runner with
  `CODE_SIGN_STYLE=Automatic` and `DEVELOPMENT_TEAM` passed on the command
  line? Known requirement: API key role Admin. Anything else (keychain
  state, `-allowProvisioningDeviceRegistration`, the `private_keys`
  directory convention)?
- `-exportArchive` with `method = app-store-connect`, `destination =
  export` then a second export with `destination = upload`: confirm the
  key names and values are what Xcode 16.4 accepts (the older `app-store`
  spelling is deprecated; `manageAppVersionAndBuildNumber = false` is
  intended so CI controls `CFBundleVersion`). Is `uploadSymbols` right for
  a SwiftUI app with `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`?
- The identity check after archiving reads `CFBundleIdentifier`,
  `CFBundleShortVersionString`, `CFBundleVersion` with `plutil -extract …
  raw` — correct on macOS 15?
- Secret handling: the key is written under the results dir, 0600, deleted
  on exit, excluded from the artifact. Find a path by which it could leak
  into a log, the artifact, or `SUMMARY.md`.
- The `require_green` step queries
  `actions/workflows/native-validation.yml/runs?head_sha=…` with
  `GITHUB_TOKEN` — does `permissions: actions: read` suffice, and is
  `.workflow_runs[0]` the newest completed run?
- `DT_BUILD = github.run_number` of the release workflow: monotonic per
  workflow, starts at 1. Any reason to prefer a timestamp?

### S2 — Project settings for release (`project.pbxproj`, scheme)

Added in r9-store: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`;
`Assets.xcassets` (single 1024 universal icon, Xcode 14+ format) and
`PrivacyInfo.xcprivacy` in the app's Resources phase;
`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` (portrait) and
`_iPad` (all four); `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`;
`INFOPLIST_KEY_LSApplicationCategoryType`; Release:
`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, `SWIFT_COMPILATION_MODE =
wholemodule`; the unit-test target no longer builds for archiving. Questions:

- Does `GENERATE_INFOPLIST_FILE` honor the `INFOPLIST_KEY_` prefix for
  `ITSAppUsesNonExemptEncryption` and `LSApplicationCategoryType` (both are
  arbitrary keys, not the curated set)? If not, the fallback is an
  `Info.plist` file with `INFOPLIST_FILE` — say which.
- iPad with all four orientations and no `UIRequiresFullScreen`: the app
  must support Split View / Slide Over. `CookingView` keys off
  `horizontalSizeClass`, so a compact split should get the iPhone layout —
  confirm by reading, and name any view that assumes full width.
- App Store requires the asset-catalog icon to have no alpha. The PNG is
  RGB (no alpha channel) — confirm from the file if you can.
- Validation runs on the simulator: `build-for-testing` now compiles the
  asset catalog and copies the privacy manifest. CI run 13 is the first
  build with them; read it.

### S3 — Privacy manifest audit (`DinnerTogether/PrivacyInfo.xcprivacy`)

Declares no tracking, no collected data, **no required-reason APIs**. Audit
the app sources for the required-reason API categories (file timestamp
APIs, system boot time, disk space, active keyboards, `UserDefaults`). My
grep found none; `Data(contentsOf:)`/`write(to:)` and
`URL.documentsDirectory` are not in the list. Confirm or correct — a wrong
manifest is an App Store Connect upload warning that becomes a rejection.

### S4 — Harness knob

`DT_IPHONE_REGEX` / `DT_IPAD_REGEX` in `run-native-pass.sh` let the
`store-assets` workflow pick `iPhone 17 Pro Max` and `iPad Pro 13-inch
(M4)` for App Store screenshot sizes (1320×2868 and 2064×2752). Confirm
those device names and pixel sizes exist on the `macos-15` image's iOS
runtime, and that `screenshots.sh` produces full-resolution PNGs (no
scaling).

## What I did verify, by tier

Supplemental: `release/dry-run.sh` — 6 scenarios against the fake
toolchain (missing secrets, placeholder bundle ID, archive failure, upload
failure, build-only, build-and-upload), wired into the `supplemental` CI
job. Source review: pbxproj referential integrity after the additions;
asset-catalog JSON and plist XML parse. **No signing, archive or upload
has been executed by anyone.**

## What I'd like back

Findings ranked by severity with separate patches; for each "correct as
written" item, say what you checked it against (Apple documentation, Xcode
help output, a past project). Where only a real run can tell, say so —
that list becomes the first-run watch list in `release/README.md`.
