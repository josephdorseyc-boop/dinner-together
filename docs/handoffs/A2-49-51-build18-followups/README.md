# A2-49–51 — small follow-ups for A3

Baseline: `ef404bafb4eff006484a92a5a4ba36064afb4886`.
Prepared October 14, 2026. A3 integrates; A1 verifies native execution.
No active source branch or live CI run was changed by A2.

## A2-49 — platform-correct expected test counts (S1)

`CoverPhotoTests.swift` adds three UIKit-only tests. The simulator must run
207 unit tests; the macOS Package.swift harness must run 204. The current
native script requires the all-source 207 total from both and therefore
rejects a complete, passing macOS run.

Apply `A2-49-platform-test-count.patch`. It leaves `EXPECTED_TESTS=207` and
the simulator verdict unchanged. A separate `EXPECTED_ENGINE_TESTS=204`,
derived using the same UIKit-only-file filter as Linux CI, controls only the
macOS swift-test count and its summary. This baseline's only UIKit-guarded
test file is CoverPhotoTests.swift and the guard encloses the whole file.

**Executed supplemental checks:** shell syntax; clean patch application on
the exact baseline; isolated fake-tool boundary checks:

| Executed counts | Required verdict | Observed |
| --- | --- | --- |
| iOS 207, macOS 204 | Pass | Pass: exit 0, 0 required failures |
| iOS 207, macOS 203 | Fail: missing engine test | Fail: exit 1, 1 required failure |
| iOS 204, macOS 204 | Fail: missing simulator tests | Fail: exit 1, 1 required failure |

These checks execute the proposed script with fake tools, not Swift/Xcode.
They establish that the fix does not lower the simulator threshold or accept
an incomplete engine test run. Native validation of the integrated change
is still required. Boundary outcomes are in VALIDATION.json.

## A2-50 — keep photo-source test metadata out of Release (S3)

The new `coverSource` values `notebook`, `cover`, and `plate` are expressly
for r24 UI assertions, but the cover currently publishes them as an
accessibility value in Release too. Decorative photo-source test labels
are not useful cooking content.

Apply `A2-50-debug-cover-accessibility-value.patch`. Both the computed
property and its modifier are DEBUG-only. Debug r24 retains its value;
Release retains the cover's identifier/container and all child controls.
Source review establishes the Release metadata exposure; no claim that
VoiceOver's exact spoken announcement was observed. Debug/Release compile
and VoiceOver verification remain pending.

## A2-51 — exercise a corrupt cover, not only a corrupt plate (S3)

The existing missing/corrupt test checks corrupt plate bytes with a valid
cover, then missing plate and cover files. It does not exercise corrupt
cover bytes when there is no plate.

Apply `A2-51-corrupt-cover-regression.patch`. It adds that case inside the
existing test: a distinct corrupt cover file, no plate, nil resolved hero
(Tonight's notebook fallback), followed by the existing missing-file and
recipe-preservation assertions. No new test method or CI flow is added;
counts remain iOS 207 / engine 204. Execution needs UIKit and is pending.

## Integration

The three patches touch separate files and each passes `git apply --check`
against ef404ba. They may be applied independently; A2-49 is the gate blocker.
Do not stack an already-adapted change onto these hunks. A3's navigation,
status-bar/header, r24, and photo lifecycle work is preserved.
