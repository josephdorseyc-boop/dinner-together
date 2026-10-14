# A2-55–57 — speed assistance requested by Joe

Four parallel agents profiled and reviewed the fresh source
`393bc9559446cf45fdd89b8df98c4ac2c88c31bd`. A3 has already implemented the
main acceleration: four independent macOS runners for core checks, iPad,
and two iPhone test halves. No active A3 source or CI run was changed by A2.

## What is already faster by design

The previous native job took about 143 minutes. Serial iPhone and iPad
automation dominated it; uploads took about 32 seconds and result-branch
publication about 25 seconds. Four runners replace that serial bottleneck
with concurrent execution. Actual speedup is pending the first completed
parallel run; no promised duration or speedup factor is claimed.

Independent source audit verified that the 45 iPhone tests split into
disjoint 23/22 shards with exact complete union, alongside all 23 iPad UI
flows and 207 simulator unit tests. Each runner builds the same workflow
SHA and isolates its simulator. Per-part gates and fail-closed retries remain.

## A2-55 — reduce expensive geometry queries

`A2-55-pinned-geometry-speed.patch` measures each pinned bar frame once per
helper call instead of five times, and measures the screen frame once per
call rather than twice per qualifying bar. Every subsequent helper call
still freshly enumerates and measures live controls. No persistent geometry
cache, assertion relaxation, timing change or test removal.

10,010 supplemental geometry-equivalence cases passed. This reduces repeated
property resolutions by construction; native wall-clock benefit still needs
measurement. It is compatible with the optional A2-52 gesture-start patch
because the hunks are separate. Native compilation remains pending.

## A2-56 — keep merged evidence honest

`A2-56-merged-evidence-guard.patch` counts missing required parts and
malformed/negative/duplicate status values as failures in the merged review
report. Without it, absent or invalid part evidence can report zero failures.
The matrix job gates remain the actual workflow verdict; this patch changes
neither those gates nor runtime budgets. Eight fixtures and six independent
malformed/missing-status review checks passed.

## A2-57 — make the combined artifact attributable

`A2-57-evidence-provenance.patch` writes run/SHA metadata before the combined
artifact upload and includes each part's status, summary and structured JSON.
The merged root iPhone JSON currently copies one shard; use the per-part JSON
for authoritative shard counts until a true aggregate is implemented.
YAML parsing, provenance order/path checks and clean application passed.

## Validation and integration

Root independently checked all three patches against an isolated index at
the exact baseline. They touch three different files and apply independently.
The reports retain measurements, source checks, models, and native limitations
separately. Integrate/adapt in a follow-up source commit; do not change the
source beneath an active run. No new competing run, cancellation, release,
paid-runner purchase, or coverage reduction was made by this team.

We deliberately deferred a ZIP compression micro-optimization: it saved
about one second on a local proxy and cannot credibly address a two-hour test
cycle. Cache/build-transfer changes also require SDK/path and evidence-gate
work for a smaller benefit than the already-applied parallel split.
