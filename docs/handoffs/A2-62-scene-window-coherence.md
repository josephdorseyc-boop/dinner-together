# A2-62 — require coherent wide scene and window

Requested by A3 in issue15 comment6196401701. Candidate baseline: 131b75792259d319a3ae6164c7d28473007d661c on wip/duo-spread. Apply the sibling A2-62-scene-window-coherence.patch from repository root with git apply --check, then git apply. A3 owns integration; no active branch or native run changed by A2.

The prior predicate was insufficient: window678x466 with scene466x678 passed the geometry gate. This patch rejects that exact observed mismatch before openRecipe.

## Change
- Parse the existing diagnostic's scene=WxH AND window=WxH fields; fail closed on missing, duplicate, malformed, nonfinite, zero, error or non-requested data.
- Require both scene and window to be wide and at least600x450; require actual app.frame to agree with both dimensions within2pt (probe dimensions are rounded). Preserve the same dimensional minimum for app.frame.
- Scene orientation ENUM remains diagnostic only: a portrait enum is allowed when actual scene and window are both genuinely wide/coherent.
- Check coherent geometry during the bounded wait, before first tap and again at the recipe eligibility decision.
- Retain full first-screen capture/hierarchy/text; require screenshot aspect to agree with actual window and the seeded Tonight open-recipes control to be hittable and fully contained within window bounds (1pt rounding allowance). This prevents the known first-tap mismatch from masquerading as usable coverage.
- Leave the existing upright path, ordinary suite discovery, test selector and full spread interaction assertions unchanged. No app/probe/production-mask/CI/engine changes.

## Verification and acceptance
Whitespace/reverse-apply checks passed, and the full interaction suffix from the original nearSquare decision onward is unchanged apart from surrounding whitespace. Ten native parser assertions (one valid portrait-enum/wide-scene case and nine invalid telemetry cases including the exact recorded mismatch) are included in the existing explicit one-test method. Native Swift cases and UIKit checks have NOT been executed on this Linux host.

A3: native-compile and select DinnerTogetherDuoWindowTests/test01_wideNativeWindowCookbookSpread using the existing ui-duo-window part. With the same broken launch, expect failure at the scene/window gate rather than an open-recipes tap timeout. A successful real pose must pass coherent geometry AND all existing spread interactions. Preserve its screenshots/hierarchy/direct evidence.

Screenshot aspect + control accessibility are necessary automated fit checks, not a general image-clipping proof. The new r26-wide-first-screen-fit capture still requires visual review for black bands, sideways content, rail/safe-area clipping and readable/reachable controls before declaring native wide-Duo acceptance. Do not mark this gap closed solely because an automated predicate passed. A1 owns finding the simulator pose route; this patch does not supply it.

— A2
