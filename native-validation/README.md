# native-validation/

Scripts the CI workflow runs on a macOS machine. They also run on any Mac
with Xcode (`bash native-validation/run-native-pass.sh` then
`bash native-validation/screenshots.sh`). Written on Linux; first executed by
the workflow — see `../CI_SETUP.md`.

| File | What it does |
|---|---|
| `run-native-pass.sh` | Records the environment; `xcodebuild -list`; `build-for-testing` on the newest available iPhone simulator; `test-without-building` on that iPhone and on an iPad, each with an `.xcresult` bundle and a per-test-case text file; `swift test` for the Package.swift harness. Writes `results/SUMMARY.md`. Never aborts early — every step's exit code is recorded. |
| `seed-sessions.py` | Writes six `dinner-together-v2.json` session files (the app's own save format) with times relative to now: `late-prep`, `late-to-start`, `expired-timer`, `way-behind`, `all-done-late`, `on-schedule`. Prints the expected screen state for each. |
| `screenshots.sh` | Boots the simulators, installs the built app, copies each seed into the app's Documents, launches with `-dt-open-cooking -dt-inert-reminders`, and captures PNGs in light and dark, plus two accessibility-large-text shots. |
| `results/` | Created at run time; uploaded as the CI artifact (minus the DerivedData build folder). `SUMMARY.md` is the human summary; `status.txt` carries `REQUIRED_FAILURES=n` for the CI gate. |
| `dry-run/` | `run.sh` executes both scripts against a fake `xcodebuild`/`xcrun`/`swift` (in `faketools/`) in twelve pass/fail scenarios and checks exit codes, required-failure counts and screenshot counts. Proves the harness's own gates on any machine in seconds; proves nothing about the app. |

Required vs. bonus: both simulators, the Debug build with `-D DEBUG`, XCTest
executing the expected number of methods on both devices (count taken from
the test source, so "0 tests executed" cannot pass), `swift test`, and every
scenario screenshot in light and dark on both devices are required, and a
requested appearance that cannot be set fails that appearance's captures
(r5, A2-3); the two large-text screenshots are a bonus. Any required item that fails or cannot
run is a ❌ in `SUMMARY.md`, increments `REQUIRED_FAILURES`, and makes the
script exit non-zero; the workflow gate then fails the job even though the
artifact was still uploaded. `SHOT_SETTLE_SECONDS` (default 4) is the wait
between launch and capture.

The two launch options are DEBUG-only (`LaunchOptions` in
`DinnerTogetherApp.swift`): one opens the Cooking screen directly, the other
substitutes an inert reminder service so the notification permission alert
never covers a screenshot. Release builds ignore both. `DEBUG` is defined by
`SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG"` in the Debug
configurations of `project.pbxproj` (added in r4 — the hand-written project
had never defined it), and `run-native-pass.sh` verifies `-D DEBUG` reached
the compiler.

`screenshots.sh` covers static states only. The interactive flows — the
review sheet, the delay sheet, the stale-plan sheet and the confirmation
alerts — are driven and photographed by the XCUITest target
(`DinnerTogetherUITests/`, r9), which `run-native-pass.sh` runs on both
simulators as a required section and whose attachments land in
`ui-screenshots/<device>/`. See `UITESTS.md`. The UI tests seed the app
through the DEBUG-only `DT_SEED_JSON` launch-environment variable rather
than `simctl` file copies; the two mechanisms do not interfere because the
UI tests run first and `screenshots.sh` writes its own seed before every
launch.
