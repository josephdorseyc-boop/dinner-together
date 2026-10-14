# A2 support: faster native workflow review

Fresh source reviewed: `393bc9559446cf45fdd89b8df98c4ac2c88c31bd`, A3's October14 four-runner parallelization. No remote branch, CI run, gate, or product files were modified.

## Timing evidence and chosen approach

Previous completed native job `116073808851` in run `38628522264` starts20:01:33UTC and ends22:24:21UTC: approximately143min, measured from its log (rather than treating a quoted149min as measured).

| Phase | Observed log interval | Approximate time |
|---|---|---:|
| Setup, Debug/Release build,207 unit tests |20:01:33→20:11:06|9.6min|
| iPhone UI, including retry through verdict |20:11:06→21:25:54|74.8min|
| iPhone exports/bundle, iPad UI through verdict |21:25:54→22:15:41|49.8min|
| macOS204 tests/result closing |22:15:41→22:16:32|0.9min|
| Static screenshots |22:16:32→22:23:23|6.9min|
| Publication/upload/cleanup |22:23:23→22:24:21|1.0min|

A3 has already applied the high-value fix: separate macOS runners for core, iPad, and two iPhone round-robin halves. This removes the serial74.8+49.8min bottleneck. Independent simulators and per-part gates avoid shared-runner contention and keep all207+45+23 native test coverage. The existing150min per-part job budget now encloses one110min device deadline plus15min retry and overhead, rather than two sequential110min deadlines.

Roughly40–60min is a reasonable planning estimate for parallel completion given the previous flow times, builds, exports, and queueing; it is not a measured speedup or promise. Gather fresh part timings before replacing round-robin with duration-balanced assignment. Do not build-once transfer DerivedData yet: all four parts build themselves, but previously core setup/build/unit combined was only9.6min, whereas native xctestrun portability, exactSDK/cache keys, simulator paths, and potentially large transfers introduce substantial complexity for a much smaller target.

## Concrete patch supporting safe parallel speedup

`merge-evidence-guard.patch` fixes A3's new merged review report:

- An entirely missing required part previously contributed no failure and could leave merged `REQUIRED_FAILURES=0`.
- An empty status file or one without a matching line also contributed no failure.
- Negative values could subtract failures.

The patch counts missing required parts and malformed/duplicate/nonnegative-integer-invalid status as failures. It changes no matrix, XCTest assertions, retries, workflow verdicts, or runtime budgets. Matrix job gates remain authoritative; this keeps merged evidence from claiming success when a part is absent. Failure summaries name the missing/invalid parts.

Validation: eight fixture scenarios passed (complete,missing part,empty status,wrong key,negative value,duplicate key,real failure,blank value). `git apply --check --directory=base` against freshly fetched393bc955 source passed; latest native shell `bash -n` passed. Native tests are not available locally and were not dispatched.

Reviewer companion patch: `team-support/speed-review/review-evidence-provenance.patch` writes exactSHA/run metadata before combined evidence upload and includes per-part summaries,status,andJSON. Important because the combined root iPhoneJSON is only one shard's copy while the root log concatenates both. Read authoritative `parts/<part>/...summary.json` until A3 adds true aggregateJSON.

Follow-up: record per-part wall time and retry/export time from first parallel pass; preserve existing unit/UI/static/accessibility gates. Optimize the slow geometry helper and repeated native queries separately. Avoid canceling current validation or dispatching competing runs.
