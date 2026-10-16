# Independent packaging and timing support for A3

Reviewed fresh source `393bc9559446cf45fdd89b8df98c4ac2c88c31bd`, fetched from `wip/own-recipes`. The new four-part workflow already parallelizes core, the two iPhone halves and iPad. This report does not propose a second parallel workflow or change the scrolling helper.

## Measured prior pipeline

Provenance: ci-results `f935826`, run `38628522264`, source `89db1f7e17243cd51e0092269d49a4c02a72f402`. Structured xcresult summaries give:

| Phase | Elapsed | Verdict |
|---|---:|---|
| iOS unit XCTest | 4.76 min | 207 passed |
| iPhone UI including simulator/test runner overhead | 62.00 min | 43 passed, 2 failed |
| iPhone diagnostic retry | 4.95 min | 1 passed, 1 failed; no credit |
| iPad UI including simulator/test runner overhead | 39.75 min | 22 passed, 1 failed |
| macOS engine | build 27.90 sec + suite 1.887 sec | 204 passed |

These are structured start/finish durations, not the final restarted suite's prose durations. For example the iPhone log's final suite alone contains 26 methods and ~40 minutes; it is not the whole 45-test pass. Unit test execution itself is 75.329 seconds wall time within a ~286-second xcodebuild lifecycle. Neither the per-phase logs nor SUMMARY timestamp exactly isolate ZIP, uploads, or build elapsed time, so savings for those phases cannot be claimed from this evidence.

Root independently retrieved job-step timing: prior native job 142.93 min; full upload 0.45 min, review upload 0.083 min, publication 0.417 min, static screenshots 6.85 min. Those external step measurements distinguish uploads from XCResult's inner durations and show that removing artifact uploads is not a useful intervention.

## Measured packaging experiment (defer adoption)

An isolated experimental `fast-xcresult-zip.patch` changes all three result-bundle ZIP invocations from default compression level 6 to level 1. It preserves every bundle file, naming, retry policy, source test count, verdict and screenshot export. No active source was changed. **Do not include this experiment in the immediate A3 change set:** its local gain is small, actual Mac bundle composition is unknown, and the full upload is already under half a minute.

Local benchmark uses 80 copies of original native PNGs plus the original iOS unit log (133,634,226 input bytes). This is a PNG-heavy proxy, not a downloaded xcresult bundle:

| Compression | CPU/wall on this Linux host | Archive bytes |
|---|---:|---:|
| default 6 | 4.909 sec | 132,787,095 |
| level 1 | 3.901 sec | 132,812,987 |

Content was verified byte-for-byte after extraction for both archives. The local proxy saved ~1 second with 25,892 extra archive bytes (~0.02%). The measured effect is modest; it must not be presented as minutes saved on the Mac runner. Level 1 was selected over level 0 to retain compression for text/structured result data and avoid a potentially large artifact-size increase. Native XCResult metadata composition and network performance differ.

Verification: `bash -n` passed for the updated latest-source script. Three ZIP occurrences changed and no other script text changed. Root/A3 should run the ordinary harness dry-run if adopting; native evidence is still needed for real runtime impact.

## Retain existing guardrails

- DerivedData `results/build/**` is already excluded from full artifact upload, so there is no redundant DerivedData-upload fix to make.
- `actions/upload-artifact` already uses outer compression level 0. Keep the small review artifact and ci-results export: their duplication is intentional recoverability for restricted artifact downloads, and removing them would slow review even if upload were marginally shorter.
- Do not add a cross-run DerivedData cache here without a separate cache-correctness change. DEBUG gate currently checks compiler output, and a cached no-op build may not emit `-DDEBUG` and could trigger a false required failure; stale test products also complicate provenance. Builds are not the principal measured bottleneck.
- Do not remove diagnostic retries or screenshot/video evidence to speed validation. Sharding is the material speed intervention; this patch only reduces packaging CPU work slightly.

Artifacts: `fast-xcresult-zip.patch`, `run-native-pass.fast-zip.sh`, `packaging-benchmark.json`, and the structured prior-run summaries. No CI runs, remote posts, source-branch edits or relaxed checks were made.
