# A2-58: late validation support

Joe requested agents and patches without overstepping A3. Four agents reviewed app source, UI harness, CI and candidate fixes. No A3 branch or active run was modified.

## Installed test-only fix on an isolated branch

Branch: `a2/build20-favorites-test-fix-20261014`.
Commit: `1f7cf0d1a98f9f00453f2956e767d36fecf22fe0`.
Baseline: `wip/duo-spread`, `e7b7c7ca078680fb8fc0426a5ee2411f4a1ee88e`.

Linux engine run38682408633 failed testFavoritesStarFirstAndPersist because the fixture expected oldest-first order. RecipeLibrary.add inserts at index0; reload sorts importedAt descending; favorites stably partition that existing order. Correct initial order is [c,b,a], not [a,b,c]. This is separate from current Build19 validation on wip/own-recipes.

The fix changes only DurationPersistenceTests.swift: distinct whole-second importedAt timestamps; correct newest-first expectation; star middle recipe b so it genuinely moves to [b,c,a]; verify that order after relaunch; verify unstarring restores [c,b,a]. Legacy JSON decoding assertions and test count remain. No app behavior changed.

Verification: exact base blob fa10bb7f3c93ab94e42f190a2a373e351c385761; clean patch application; applied file matches installed contents; source-contract and ordering-model checks including all six reload permutations passed. Independent review confirmed timestamps, contract, retained assertions and applicability. Swift/Xcode unavailable here; actual engine/native execution remains required. No run dispatched.

A3 may cherry-pick the single test commit if not superseded. It was not installed on wip/duo-spread or wip/own-recipes.

## Release harness: A3 already owns the fix

Baseline2b3f724c395cdc2e6d30ae79ddc6448cfb338962; active native38682393276. Previous38677804763 passed core, iPad and even iPhone shard; odd shard failed test36 on recipe-edit-notes snapshot. A3 already moved Notes entry before title entry and keyboard obstruction. Source confirms clearing title does not request focus. Blank-title warning, disabled Save, exact title/notes persistence, delete/cancel assertions and normal Notes hittability remain. Seven source checks passed; native confirmation pending. No extra harness patch justified.

Fresh source has46 iPhone flows, partitioned23+23 with no omissions or overlap. Previous merge/provenance patches are adopted. Held A2-55 optimization still applies and its10010 supplemental cases pass, but remains held per A3.

## Optional Duo evidence patch

duo-evidence-gate.patch applies to2b3f724. Adds RUN.txt before execution and includes it in evidence; requires a nonempty clean summary and rejects native-wrapper failure while retaining status/screenshot gates. Nine shell scenarios, YAML parsing, provenance ordering and application checks passed independently.

This is a fixture-proven latent gate inconsistency, not a runtime fix or observed cancelled-run false green. Reviewed cancelled Duo gates already failed because status was absent. No new hang/timeout proven; no timeout increases or relaxed retries. Adoption can wait until A3 next touches the workflow.

No CI cancellation/dispatch, merge or release action. Current run result remains authoritative; elapsed30–40minutes alone does not establish a hang. Test-only commit and optional workflow patch are separate.

— A2
