# New native failure and targeted candidate — supersedes earlier no-new-failure report

Baseline source: `2b3f724c395cdc2e6d30ae79ddc6448cfb338962`.
Native evidence: run `38682393276`, job `116249621909`, iPhone shard 2/2. Test37_swipeEditAndDeleteAX3 fails and retry fails. Source2b3f724's Notes-first reordering is insufficient. Earlier REPORT.md was written before this new completed failure became available.

## Verified evidence

Downloaded ci-part artifact11949374362 to `fail.zip`; relevant logs extracted under `fail/`. Retry log records Notes as frame `(38,722.6667,326,102.3333)`, `hittable true`, comfort zone `60…748`, screen402×874. The field's bottom825 exceeds required comfort bottom748. Twelve attempts use long centre-column drags `.55→.12/.13` without bringing Notes into the comfortable area. This is not the former zero-length drag or oversized Notes-height problem. The editor already requests a large detent. Logs identify the editor's Save as measured bottom control, not a stale underlying Tonight caption.

No failed-modal screenshot is available in this ci-part: r20a captures only swipe actions before entering Edit. We cannot prove which textfield consumed the gesture from logs alone.

## Candidate rationale and scope

The center start y480.7 is plausibly inside a vertical title/yield textfield, whose internal gesture can absorb a drag. Existing dragStart excludes button frames but not textfields. Candidate `editor-margin-scroll.patch` adds up to four r20-local host-scroll gestures at constant12pt inside the Notes-containing ScrollView's left edge. The application supplies24pt outer content padding; fields begin after additional14pt internal padding (failed Notes startsx38), so this path avoids their editing area. Using the actual ScrollView coordinate base handles floating iPad sheets instead of assuming screen-left is content.

After prepositioning, the original `scrollTo(notes)` is retained in full, including hittability and unobscured-frame requirement, followed by the same tap/type and exact persisted notes assertion. All title/Save/delete/cancel checks remain. No generic helper, retry policy, test gate, product file or workflow changed. If still not comfortable, attach a screenshot and accessibility hierarchy before generic fallback can fail. This closes the current evidence gap.

This is a reviewable candidate, not a proven native fix. Gesture consumption is a source-supported inference; viewport margin hit testing and actual field movement require A3's focused native test36/test37 and iPad equivalent.

## Checks

- `git diff --check` and reverse-apply check: pass.
- `verify-editor-margin.py`: five viewport geometry scenarios (including floating iPad origin), two offscreen-rejection cases and eight source checks for bounded attempts, finite frames, both actual gesture points inside app.frame, retained visibility assertion, typing, exact persistence and deletion checks passed.
- No native Swift/Xcode/simulator available on this host. No active source branch, remote comments or CI changed.

Suggested validation: focused iPhone test37 AX3 first, standard test36 and iPad r20 next; inspect Notes-before-fallback evidence if it fails. Do not declare the remaining run green or waive the failing test.
