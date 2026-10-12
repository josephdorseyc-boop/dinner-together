# A2-15: diagnose the recurring Delete transition

Prepared for A3/A1 on October 12, 2026. This is a diagnostic patch, not a verified production fix.

## Evidence

**Supplemental check:** completed native run 38287619636 at source cbe8c7f6e9087187c89d08993d37dcb5ef20331a passes 144 unit tests per simulator, but iPhone test16_deleteFailure fails waiting for the confirmation. Evidence ref: 0c93e2f45a76720b995f8f996b9b9fd7da9a2fcf.

The failed iPhone accessibility snapshot at 06-32-11-PM still contains the Delete menu button (label Delete recipe, identifier trash, frame 144/72/250/42) and More. It contains no delete confirmation. The test already retries once. This does not prove whether the action closure ran; increasing a presentation delay cannot answer that question.

## Separate patch

Apply A2-15-delete-dispatch-diagnostics.patch only if the current native run still has this failure and the owner has not already added equivalent diagnostics.

The patch:

- Increments a DEBUG-only counter on entry to the menu Delete action.
- Adds a DEBUG accessibility value on More with that counter, confirmingDelete and cannotDelete.
- Gives the menu action and confirmation action different identifiers.
- Adds keep-always before/after state and hierarchy attachments, plus a transition screenshot, to the existing delete-failure flow.
- Preserves the confirmation, recipe-retention and failed-save assertions. Adds no test methods and does not change test-count expectations.

Base: main eb04d8288a995e88e9653df4c6206694e043c7c9. Compatibility checked against palette head 8b70d05ff64977a4bf104b54d05f792b60f1d3ae, including byte-for-byte comparison with the expected edit. A3's 350ms deferred actions remain intact.

Because the patch uses short anchoring hunks to avoid incorporating A3's independently edited action body, use:

```bash
git apply --unidiff-zero --check docs/a2/delete-dispatch/A2-15-delete-dispatch-diagnostics.patch
git apply --unidiff-zero docs/a2/delete-dispatch/A2-15-delete-dispatch-diagnostics.patch
```

Check every hunk on a newer source revision. Alternatively add these small diagnostic lines manually around the owning implementation. No active branch was modified by A2; merging the handoff documents alone does not apply the source patch.

## Interpret the next run

Compare the counter before and after each attempt; do not assume its starting value after a retry.

| Observed state | What it establishes |
| --- | --- |
| Counter increments, confirmation true, dialog absent | The action and state request occurred; investigate presentation/anchor behavior. |
| Counter increments, both presentation flags false | The action ran; investigate deferred-task execution or a later state reset. |
| Counter unchanged, menu remains | Once the counter is verified readable, the attempted tap did not reach the action. Investigate the menu interaction target. |
| Locked alert true | The guard routed to the cooking lock; inspect fixture/session state rather than expect the delete confirmation. |
| Counter value absent/unreadable | Probe propagation is unverified. Do not infer that the action did not run from a missing accessibility value. |

The owner can first build the changed app/test targets and run only the existing iPhone test16_deleteFailure and iPad test09_deleteFailure_iPad, using the runner's supported focused-test path. Test-without-building against old app binaries will not contain the probe. After a real fix, the complete required suite remains the gate.

Do not launch an additional full native run merely to apply this diagnostic while the current palette run is finishing. If that run resolves the failure, no integration is needed. Remove the counter/value after diagnosis; stable action identifiers and useful transition captures can remain if the owner prefers.

## Validation limits

**Supplemental check only:** clean isolated application to both baselines; expected-source comparison; A3 deferred-action preservation; unchanged test-method counts. Swift compilation, probe propagation, XCUITest execution, simulator rendering of this patch and physical-device testing have not occurred. This patch diagnoses the transition and does not change its production presentation policy.
