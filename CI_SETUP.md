# Native validation without a Mac — GitHub Actions setup

GitHub Actions provides macOS machines with Xcode and iOS simulators. This
project ships a workflow (`.github/workflows/native-validation.yml`) that
builds the app, runs the XCTest suite on an iPhone and an iPad simulator,
runs the `swift test` harness on Linux and macOS, and photographs the cooking
screen in six seeded recovery states. Everything comes back as a downloadable
artifact you can hand to whoever is reviewing — no Mac involved at any point.

## One-time setup (about 15 minutes)

1. **GitHub account and repository.** Create a repository, e.g.
   `dinner-together`. A **public** repo gets unlimited free Actions minutes.
   A **private** repo also works: the free plan includes 2,000 minutes/month
   and macOS counts 10×, so a ~15-minute run costs ~150 — roughly a dozen
   runs a month. (The source has placeholder bundle IDs and no secrets; the
   choice is about how visible you want the code to be, not safety.)

2. **Put the project at the repository root.** The repo root must contain
   `DinnerTogether.xcodeproj`, `DinnerTogether/`, `DinnerTogetherTests/`,
   `native-validation/`, `Package.swift` and `.github/`. Two ways:
   - **GitHub Desktop (Windows/Mac/Linux):** File → New repository, point it
     at the unzipped `DinnerTogether-RecoveryCandidate-v028` folder, commit,
     Publish. Simplest; it includes the hidden `.github` folder.
   - **Web upload:** "Add file → Upload files" and drag the *contents* of the
     folder in. Check afterwards that `.github/workflows/native-validation.yml`
     made it — some browsers skip dot-folders; if so, create that file via
     "Add file → Create new file" and paste its contents.

3. **Run it.** Every push runs the workflow automatically. To run it by hand:
   Actions tab → *native-validation* → *Run workflow*.

## Each run (20–30 minutes of waiting, 2 minutes of your time)

1. Actions tab → the latest *native-validation* run.
2. Three jobs: *Engine model + swift test (Linux)* (fast), *Supplemental JS
   model* (seconds), *Xcode build, XCTest, simulator screenshots* (the long
   one, ~15–25 min).
3. When the macOS job finishes — green or red — scroll to **Artifacts** and
   download `native-validation-results.zip` (and `engine-linux-log`).
4. Upload the zip(s) back into this conversation. The important files:
   - `SUMMARY.md` — pass/fail per step, Xcode version, simulators used.
   - `20-test-iphone-cases.txt` / `20-test-ipad-cases.txt` — every XCTest
     method with passed/failed.
   - `10-build-for-testing-iphone.log` — the compiler's words if the build
     failed (first errors are also echoed into `SUMMARY.md`).
   - `screenshots/iphone/*.png`, `screenshots/ipad/*.png` — the cooking
     screen in each seeded state, light and dark, plus two large-text shots;
     `screenshots/EXPECTATIONS.tsv` says what each one should show.
   - `ui-screenshots/iphone/*.png`, `ui-screenshots/ipad/*.png` — the
     interactive flows photographed by the UI tests (`UITESTS.md` lists
     what each one asserts); `25-ui-test-*-summary.json` has the counts.
   - `*.xcresult.zip` — the full Xcode result bundle, for anyone with Xcode.

I read the summary, the logs and the screenshots, fix what they show, and
return a new patch/ZIP; you replace the files in the repo (GitHub Desktop
makes that a commit) and the next run starts on its own.

## How to read a run

The macOS job is **red** whenever any required step failed *or could not
run* — no simulator, app not built, fewer tests executed than the source
defines, screenshots missing, no summary produced. It is never green by
omission. The artifact is uploaded either way; `SUMMARY.md` lists every
required item with ✅/❌ and `status.txt` carries the count the gate used.
The "JS model + harness dry run" job checks the validation scripts
themselves against a fake toolchain, so a green there means the gates work,
not that the app does.

## Where this stands

As of r7 all three jobs are green on `josephdorseyc-boop/dinner-together`
(run 5, Xcode 16.4): build, XCTest 61/61 on iPhone and iPad simulators,
`swift test` on macOS and Linux, 28 screenshots. It took five runs; each red
run named one real problem in `SUMMARY.md`. Results are also pushed to the
`ci-results` (macOS) and `ci-results-linux` branches so they can be read
with plain git when artifact downloads aren't available. A push that breaks
something shows up as a red macOS job with the reason in `SUMMARY.md`.

## What this does and does not prove

Proves, once green: the Swift compiles for iOS 17+; the 61 XCTest methods
pass under Xcode; the seeded recovery states render as designed on an iPhone
and an iPad simulator in light, dark, and accessibility text size.

Does not prove: notification delivery on a real device, VoiceOver reading
order (needs a person or an accessibility audit test), haptics, battery/
background behavior, App Store readiness. Those stay on the device checklist
in `README.md`.

## Later additions this path supports

- ~~A UI test target~~ — added in r9 (`DinnerTogetherUITests/`, see
  `UITESTS.md`): the macOS job now also taps through the review sheet, the
  delay sheet, the stale-plan sheet and the confirmation alerts, and
  publishes those screenshots under `ui-screenshots/<device>/`.
- TestFlight builds from CI (requires an Apple Developer Program membership
  and signing secrets in the repo). That is how an iPhone in your hand runs
  the app without a Mac.
