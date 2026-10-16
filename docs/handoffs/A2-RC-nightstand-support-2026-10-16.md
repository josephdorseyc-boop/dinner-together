# A2: RC nightstand support

Reviewed baseline: `9dd34692ad75c79735aaa33c7c7711d0f2b91849`, `wip/build22`.
Joe requested three parallel reviews and direct GitHub delivery. A3 remains implementation lead; these isolated candidates do not modify his branch or dispatch CI.

## Candidates (independently cherry-pickable)

1. `188e3e6`: small production copy correction. Selecting a later countdown now says **SELECTED TIMER**, rather than falsely claiming **NEXT TO FINISH**. Expired/single-timer wording is retained.
2. `ca994d8`: optional capture diagnostics. Keeps A3's XCUIScreen primary capture unchanged; adds a separately named raw application capture and text provenance (pixel sizes, image orientation, scale, app/window bounds, runner orientation). No image rotation, cropping, or evidence replacement. Consecutive captures are not atomic.
3. Nightstand test hardening: subscribe before rotating, pass selected destination name from harness, and limit the unsupported-pose return to the known closed Duo simulator with an actually observed portrait pose. Unknown pose, ordinary iPhone failure to present, and a presented page that never reaches landscape fail. The Duo exception explicitly records manual-only coverage; automatic presentation, landscape, suppression, and re-entry remain unverified.

## Findings and limits

The original test's successful early return was not limited to Duo, and its landscape assertions ran only if landscape was reached. This could allow future false-positive results. This finding does not invalidate the earlier measured 874×402 iPhone layout.

A3 already changed the landscape screenshot route at baseline. Its pending native run should be assessed before further changes. Paired original PNGs and element geometry help distinguish capture artifacts from layout defects; neither geometry nor a single screenshot certifies every control or pixel.

Source review found no additional confirmed timer persistence/night-mode lifecycle blocker. Countdown deadlines are retained across entry and exit. The page dims content without changing system brightness. Verify native/device automatic entry, unplug/upright exit, Done suppression, re-entry, and night/day transitions. Actual Duo tent behavior remains a hardware check.

## Validation

`git diff --check` and `bash -n native-validation/run-native-pass.sh` pass. Swift/Xcode are unavailable locally: native compilation, UI regression, and paired-capture results remain pending. Harness fake-toolchain results are reported separately in the GitHub handoff and prove shell control flow only.

At review, RC native run `38930011797` had Linux and JS checks green, iPhone part 1 started, and remaining Apple jobs queued. Duo run `38930015333` was queued. These baseline results do not validate these new candidates.
