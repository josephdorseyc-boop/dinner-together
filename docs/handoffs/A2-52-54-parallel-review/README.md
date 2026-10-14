# A2-52–54 — parallel assistance requested by Joe

Three independent agents reviewed exact source
`2afd76db20504a4a68f035ea5f3c997928cbd746` while native run
`38648551795` was active. Evidence is from completed run `38628522264`,
source `89db1f7`, ci-results `f935826`. No active A3 branch, native run,
release, assertion, or retry verdict was changed.

## A2-52 — optional scroll-start bound

A3's visible-zone midpoint fix addresses the observed tiny-gesture pattern.
Prior failing AX3 flows made one useful drag followed by eleven nearly
stationary .71 → .70 drags. The current selector avoids buttons, but can
still choose a pinned static caption because captions are not buttons.

`A2-52-scroll-start-bounds.patch` constrains scrollTo gesture starts to its
existing measured content zone; other callers retain their behavior.
Five supplemental geometry scenarios passed. Root independently checked
clean patch application against the exact baseline with an isolated git
index. Native compilation/gesture verification remains pending.

This is a contingency, not a reason to replace A3's fix before its current
run finishes. If the new diagnostics still show unsafe gesture starts,
integrate the patch and validate the focused AX3 flows first.

## A2-53 — optional targeted iPad allowance

The old log reports a three-minute timeout; the maximum allowance is a cap,
not the default. Undo automation was still seeking geometry at 271 seconds.
The new default240/max360 does not give this test360 automatically.

`A2-53-ipad-test-allowance.patch` requests360 only for iPad test01, preserving
all Move/Undo assertions and A3's existing cap. Clean baseline application,
shell syntax and four focused watchdog scenarios passed. Native execution
remains pending. Use if the pending run again times out the complete flow;
do not keep increasing global budgets without diagnosing repeated scans.

## A2-54 — status-bar visual acceptance still fails after navigation

Original `r24b-a-with-photo` and `r24c-b-without-photo` renders show **black
clock/Wi-Fi/battery over the full-bleed cover after selecting recipes**;
first-launch captures have white indicators. Root also inspected both PNGs.
PlanView and ContentView are unchanged between the rendered source and the
active run's source. This is a real product/render discrepancy, separate
from the three XCTest failures. A green test suite cannot establish the
approved light-status-bar appearance by itself.

Keep the full bleed, frosted card and foot fade. Inspect status appearance
restoration at the presentation root when returning from Recipes; the
specific cause remains unconfirmed. No blind product patch was prepared.

The full selected title in the pinned AX3 footer and the hard-coded bar
transition threshold are additional source concerns needing actual
interaction/intermediate-scroll renders, not confirmed causes from source
alone. See VISUAL_REVIEW.md for original evidence links and remaining
device-only checks.

## Next decision

Let run38648551795 finish on its own source. Require all structured tests to
pass, including completed iPad Undo, then inspect the new first-launch,
r22a and r24 images after navigation. Adopt the optional harness patches
only if the evidence warrants them; resolve or explicitly review the
confirmed status-bar finding before release. The individual reports retain
observations, inferences and validation limits separately.
