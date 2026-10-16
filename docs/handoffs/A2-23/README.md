# A2-23 — colored-page system chrome proposal

October 13 morning, Denver. Proposed source delta for A3; active app source remains untouched.

## Problem and evidence

**Evidence tier: simulator rendering**, A2-19 review: build12 run 38341383318, source 50e74dd7, light r14a photo / Tomato / iPad AX captures still show black status content over a dark colored page. Default Dark captures show readable light status content. This is an unresolved S3 finding, not a new device execution by A2.

**Evidence tier: source review**, share-extension **9a08174eb7ed91c8cb8de01c4f8219e3311f1070**:
- RecipeDetailView specifies toolbarColorScheme, but the status bar/presentation must also receive an appropriate appearance.
- DinnerTogetherApp separately sets preferredColorScheme from the DEBUG forced appearance at an ancestor. Higher presentation preferences can override lower preferences.
- Root navigation still uses separate compact and regular selections. The original A2-19 patch **applies cleanly to this branch** and preserves the newer share-inbox sheet.

Apple's preferredColorScheme documentation says the preference propagates to the enclosing presentation, can be overridden higher in the hierarchy, and nil defers to system appearance: https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:). The proposed behavior is an inference from source/API semantics; native rendering must verify it.

## Patch, dependency and baseline

**Apply original A2-19-shared-destination.patch first**, from PR #14's docs/handoffs/A2-19/, then **A2-23-recipe-system-chrome.patch** here. Exact baseline is **9a08174e + A2-19**. Do not apply A2-19 again if the shared Destination already exists; adjust the new delta to your newer head.

A2-23 adds a root appearance decision:
- Active Recipes detail with a resolved colored palette → dark presentation appearance, giving the window's status/sidebar/tab chrome the dark-page context.
- Recipes collection, Classic cream, Tonight and Cooking → DEBUG forced appearance if specified, otherwise nil/system appearance.
- It removes the duplicate DEBUG ancestor preference in DinnerTogetherApp so the two cannot contradict one another. Forced Dynamic Type seeding remains.
- Recipe-path navigation, incoming-share sheet, store alerts, timer logic and data persistence are retained. Existing palette hues/stops and recipe parsing are unchanged.

The current recipe palette is always a dark-page palette. If A3 implements a lighter automatic palette with dark ink for Joe's icing photo, this rule must be derived from the new palette's appearance rather than treating every non-nil palette as dark. This patch addresses current system-chrome readability; it does not claim to implement Joe's softer-photo aesthetic.

## Validation and ownership

**Evidence tier: supplemental check.** In isolated scratch copies fetched at exact 9a08174e:
1. Original A2-19 passed git apply --check, then was applied only to those verification copies.
2. A2-23 passed git apply --check against that result.
3. Share-inbox sheet and uiTestTypeSize transformation remain in the proposed files.
4. No app source branch edited and no CI workflow dispatched by A2. No Swift compilation or simulator execution of this proposal.

A3 owns integration and any preferred appearance policy adjustment. A1 owns compile/interaction verification. A2 reviews resulting status/header/tab renders. No duplicate harness requested.

Small useful next validation on the owner’s next implementation run:
- System light → photo colored detail and typed Plum/Tomato detail: top and scrolled captures; status content light, chrome readable.
- Switch to Classic cream, pop to collection, switch Tonight/Cooking: system-light appearance restored.
- Repeat with system dark; preserve the existing dark appearance outside the page.
- Open Page color, save/fail/rollback selection, dismiss; incoming-share sheet on a colored page remains legible.
- With A2-19 integrated, change size class / Duo pose and keep the selected destination, recipe path and running timer deadline.

A clean source application is not visual signoff. Keep current native CI running; this is ready for review and the next integration commit.
