# A2 independent speed and evidence review

Reviewed A3 exact source `393bc9559446cf45fdd89b8df98c4ac2c88c31bd` in isolated team source. No active branch edits or remote mutations.

- A3 already split native validation across four isolated macOS runners: core, 23 iPhone flows, 22 iPhone flows, 23 iPad flows. Source partition check proves the iPhone union is exactly all45 tests with zero overlap and zero duplicate names. No test omission or repeated same-host simulator competition introduced.
- Each job builds its own checked-out workflow SHA. No DerivedData/app cache is shared. This avoids stale build/test artifacts and absolute-path relocation risks. Matrix fail-fast=false preserves independent evidence. Each job retains its own required gate; publication remains best effort and cannot turn failed test jobs green.
- Original UI retry identity/count/command-exit gates remain unchanged by sharding and geometry patch. Deadline kills remain failures. Increased timeout alone should not be claimed to fix user interaction.
- Reviewed geometry snapshot patch. It preserves predicates and remeasures on every later scroll operation. Independently reran 10,010 equivalent geometry cases. Qualifying bar frame lookups reduce from5 to1 per bar, app frame lookups from2/bar to1/call. Native elapsed-time improvement is not yet measured.
- Reviewed merge evidence guard. Independently exercised six missing/malformed status cases: missing, empty, arbitrary text, negative, duplicate, non-ASCII digits. All counted failures. This closes publishing a misleading zero-failure merged status despite missing evidence while the matrix gate already stays authoritative.
- Evidence defect: existing merged root iPhone JSON is first-shard-only, whereas root log combines both shards. Never treat root JSON as all45 results. Per-part summaries/status/JSON must be retained for review.

## Prepared optional evidence patch

`review-evidence-provenance.patch` writes RUN.txt with GitHub run ID and exact source SHA before combined artifact upload, and includes per-part summaries, status, and structured results in the combined artifact. It changes no assertions, tests, timeout, native gate, release criteria or runtime pipeline. Existing later branch provenance write is retained.

Validation: exact-source git apply --check; YAML parse; assertions checking RUN before upload, run/SHA identity, per-part evidence paths, unchanged four-part matrix and fail-fast false. Linux checks prove control flow, not native compilation or actual speed.

Do not promise fourfold wall-clock acceleration: longest shard, four duplicate builds, macOS runner queue and evidence overhead still bound elapsed time. Current matrix source aims to materially shorten the longest sequential UI phase; collect per-part times from its first completed run before more changes.
