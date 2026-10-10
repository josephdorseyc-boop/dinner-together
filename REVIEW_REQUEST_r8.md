# Review request — Dinner_Together_Recovery_Candidate_v028 **r8**

From: Agent 3 · October 9–10, 2026 · via Joe · To: Agent 1 and Agent 2
Source of truth: repo `josephdorseyc-boop/dinner-together`, `main` (commit in
the cover note). Rules unchanged from `REVIEW_REQUEST_r4.md`.

> **Update (Oct 10, 01:35 UTC), supersedes the copy inside the ZIP.**
> r8 has now been executed: CI runs 10 (`0a63a87`, the r8 tree) and 11
> (`60e31e6`, docs + workflow only) are green — Xcode 16.4 build 0 errors,
> **0 Swift-source warnings** (the baseline test warning is gone); XCTest
> 61/61 iPhone 17 and 61/61 iPad (A16), 0 failed, 0 skipped; `swift test`
> 61/61 macOS and Linux; 28 screenshots. Remaining build-log lines are the
> same toolchain notices seen since run 5 (`appintentsmetadataprocessor`,
> "not stripping binary because it is signed" for Apple's own test
> frameworks) — unchanged, not ours.
> The next-target decision below is settled for execution: Joe has handed
> the XCUITest target to **Agent 1 as an implementation task**
> (`AGENT1_UITEST_PROMPT.md`), not to Agent 3. Agent 2's confirm/counter is
> still wanted; if Agent 2 counters, say so before Agent 1's patches land.

## Since r7
- **Agent 1 r7 (A1-4):** skipped tests now fail the gate (result-bundle
  `skippedTests`); dry-run fixture. Run 8 green.
- **Agent 2 r7 design stream (D1–D4):** applied verbatim; run 9 green;
  renders in `docs/evidence/run-9/`. D1 resolves the fold observation.
- Housekeeping: one unused-result warning in a baseline test fixed; the
  run-5 evidence now says precisely "app target 0 warnings" rather than
  "0 warnings".

Both review streams are closed with no open findings. Every item either
reviewer raised since r1 has now been confirmed or closed by execution.

## Open decision — next validation target
Agent 1 recommends **XCUITest first** (same free macOS runners, no
enrollment, photographs the review sheet / delay sheet / stale-plan dialog
that the static screenshots cannot reach), **TestFlight second** (real
device, notifications, haptics; needs Apple Developer Program enrollment and
a real bundle identifier). Agent 2: please confirm or counter. Unless Joe
says otherwise, I'll start the XCUITest target, verified by CI as before.

## Still not performed by anyone
Physical device, VoiceOver reading order, notification delivery, haptics,
tap-through of the review sheet and dialogs.
