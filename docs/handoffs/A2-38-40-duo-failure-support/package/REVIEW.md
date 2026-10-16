# A2-37 integration audit / A2-38 candidate

Baseline: wip/week-plan fb72b2a8af5ac717d15cd871db514a677b84c45c.

## Confirmed finding

S3 — Recipe thumbnail can be replaced by a classic's drawing solely because its title matches a catalog dish.
Evidence tier: source review. Not simulator/device reproduction.
Location: DinnerTogether/WeekPlanViews.swift, DishThumbnail.body (around 508).
Repro contract: save a recipe named Salmon (or Steak/Pasta), with its own cover; start it; inspect its non-featured timer or timeline row at default text size. The current first branch sees the matching catalog dish and selects A2CatalogIllustration, so the recipe-cover branch is unreachable. The same title without a cover also incorrectly receives catalog artwork. This contradicts the integration comment and A3's recipe-cover policy.

A2-38-recipe-thumbnail-priority.patch resolves recipe identity first, then its cover; a recipe without a cover draws nothing as documented. Only genuine DinnerCatalog menu IDs may use catalog dish art. Deleted/unknown recipe IDs do not borrow unrelated art.

Validation: separate patch applies cleanly against the exact remote WeekPlanViews.swift blob a1135425caa55e84c0bdc03e8ad841844394304a. Native compilation and render pending. No source branch modified.

A1 acceptance cases: (1) custom Salmon with cover → that cover; (2) same without cover → no borrowed drawing; (3) classic salmon → salmon dish drawing; (4) unknown/deleted recipe ID → no borrowed drawing. Existing recipe without catalog-name collision keeps its cover. No new project-file or test-selection changes needed for the patch itself.

## Package/build findings

No confirmed compile or resource-pack defect found. A3 integrated adapter and JSON byte-for-byte: Swift blob abe313cd77fbf73b751d1495a1e9f3f9060d6ba1; JSON bd973f45a86014c55925727d23493ff45038db6b. PBX Sources includes B126; PBX Resources includes B127; both resolve within the DinnerTogether app group. Data and drawing-path schema were already validated in the handoff, and inspected loader/path arities agree.

Local `command -v swift` returned no executable. This audit cannot claim local Swift execution. At audit time native-validation38484344610 remains in progress, with Linux and JS jobs green; engine-quick38484302592 is green. A green portable suite is not proof the SwiftUI Canvas compiled or drew on-device.
