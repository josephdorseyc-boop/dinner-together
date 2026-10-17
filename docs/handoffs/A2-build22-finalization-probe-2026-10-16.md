# Build 22 finalization diagnostic

Baseline: `79aecbad03f7d47055d100ca7c28e3f24f43a332`.
The release candidate and its required process/result/export gates are unchanged.
This branch supplies diagnostic evidence only.

## A1 proposals reviewed

- Xcode 27.0 is installed on the observed `xcode-27-arm64/20261012.0260`
  image. Compare it on the same ordinary iPhone 17 / iOS 27.0 destination as
  27.1. This comparison cannot replace required Xcode 27.1 / Duo coverage.
  Apple's Duo toolchain guidance: https://developer.apple.com/iphone-duo/ .
- Do not promote `read-ui-log-counts.py` into release authority. Its diagnostic
  totals accept a failed-case line followed by passing totals, duplicate case
  identities with a missing selected case, and an earlier completed suite
  followed by a new incomplete suite. A done-marker grep does not prove each
  selected test ran. An `Info.plist` existence check does not prove result
  integrity or successful attachment export.
- Capture a bounded macOS `sample` before timeout signals. Preserve the timeout
  reason and process state. Exits 124/125 remain failures.
- Compare `.keepAlways` and `.deleteOnSuccess` retention on 27.1. The latter is
  opt-in through a test-runner-only environment variable; direct PNGs remain.

## Run

Manually dispatch `toolchain-probe.yml` on this diagnostic branch with runner
`xcode-27` and `finalization_smoke=true`. Three comparisons run, at most two
concurrently: 27.0 / keep, 27.1 / keep, and 27.1 / discard successful attachments.
Each selects exactly `test10_recipeLibraryEmpty` and `test22_coverCropHappyPath`.
The latter failed a real assertion in full-run job `117243473459`, waiting for
`choose-screenshots`; it is separate from the finalization failure.

The diagnostic allows only 60 seconds of post-suite silence. It then samples
the live process and preserves a red result, readable logs and available direct
captures. Successful diagnostics still require process exit 0, exactly two
passing tests in a readable result summary, no skips/expected failures,
successful attachment export, and direct PNGs. They confer no release credit.

Artifacts retain logs, provenance, any result bundle, screenshots and timeout
samples; compiled products are removed before upload. Normal production app
sources, release workflow and validation harness verdicts are unchanged.
