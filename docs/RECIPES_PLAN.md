# Your recipes, timed — the "add a recipe" feature

Plan v1 · Agent 3 · October 11, 2026 · for Joe, Agent 1 and Agent 2
Status of the app this plan builds on: build 1.0 (5) in TestFlight, validation
green on Xcode 26.2 (`544ad9d`).

## 1. What Joe asked for, and what is actually possible

Joe wants people to cook *their own* saved recipes with Dinner, Together —
before Thanksgiving and before anyone outside tests the app — and wants an
added recipe to read like the Apple News+ Food recipe page (hero photo, title,
source, total time, yield, Ingredients / Directions tabs, orange timer chips
inside the directions, a Start Cooking button).

The one hard limit, stated once so nobody designs around a mirage: **no app
can read recipes a person has saved inside Apple News+, Safari, Notes, Paprika
or anywhere else.** Apple does not expose them. What we can do is make the
trip from any of those places into Dinner, Together take five seconds. Four
doors in, all private, all on-device:

| Door | How it works | Covers |
|---|---|---|
| **Paste a link** | User copies the recipe's link (Share → Copy Link works in News, Safari, Instagram, anywhere). On the Tonight screen, "Add a recipe" notices a link on the clipboard and offers it. The device fetches the page and reads the recipe data almost every recipe site embeds (schema.org `Recipe` JSON-LD: ingredients, steps, times, yield, photo). | EatingWell, Allrecipes, Food & Wine, Serious Eats, NYT Cooking, BBC Good Food, Bon Appétit, most blogs. Apple News+ Food recipes come from these publishers; the shared link should resolve to the publisher page (to be verified in week 1). |
| **Paste text** | Any recipe text — from Notes, a message, an email. A parser splits ingredients from steps and pulls the times out of sentences ("about 30 seconds", "3 hours", "8–10 minutes"). | Family recipes, anything already typed somewhere. |
| **Photo or screenshot** | Pick a photo of a cookbook page or a screenshot of any app. On-device text recognition (Vision), then the same text parser. | Cookbooks, cards, apps that don't share links. |
| **Type it** | A plain editor: title, ingredients, steps. Also how every imported recipe gets corrected. | Everything else. |

A **share extension** ("Share → Dinner, Together" straight from Safari/News)
is the fifth door. It is deliberately **1.2**, not now: an extension is a
second signed target and a second bundle ID, and the release pipeline has
worked end-to-end for exactly one evening. Paste-a-link delivers the same
result with one extra tap.

## 2. The part that makes this *our* feature: timing review

A recipe page tells you what to do. Dinner, Together tells you *when*. So an
imported recipe is not done when it is parsed — it is done when its steps
carry the three things the engine needs:

- **minutes** per step — pulled from the text when present (the orange chips),
  otherwise estimated from the verb (sauté 5, boil water 10, roast → from the
  recipe's total time) and shown as *estimated* until the cook confirms;
- **hands-on or hands-off** — inferred from the verb (bake, roast, simmer,
  freeze, chill, rest, marinate, rise → hands-off; everything else hands-on),
  one tap to flip;
- **order** — a recipe is one dish, so each step depends on the previous one,
  exactly like today's catalog dishes. (Parallel sub-components inside one
  recipe — "meanwhile, make the sauce" — become a second dish of the same
  recipe when the parser sees "meanwhile / while that / at the same time";
  otherwise the cook can split them in the editor. Good enough for 1.0.)

The **Timing** tab (our addition to Ingredients / Directions) is where the
cook confirms this in thirty seconds: every step as a row with its minutes
and a hands-on/hands-off toggle, estimated values marked, a total at the
bottom, "Looks right" to finish. This is the screen Agent 2 should design
first; everything else is a known pattern.

Long hands-off steps ("freeze 3 hours", "roast 3½ hours") are now first-class:
the catalog's 3–30 minute bounds test stays for the *catalog*, and a
hands-off step can be any length. The engine already handles long chains;
the attention-warning and "running behind" copy need a look for multi-hour
steps (Agent 2's S5 item about "1650 min behind" is the same work).

## 3. Custom dinners

"Tonight" gets a second section above the nine catalog menus: **Your
recipes**. Any recipe can be cooked alone (one dish, the engine plans it
backward from the dinner time like any menu) or combined: pick two or three,
"Cook these together", and they become a dinner whose dishes are the recipes.
That is the Thanksgiving case — turkey + stuffing + mashed potatoes + gravy +
green beans + rolls, each its own recipe, planned to finish together. Agent 2's
holiday menu (S7) ships as catalog content; a user's own version is built
from recipes the same way.

## 4. The recipe page (matching the reference)

Hero photo (from the link; none for text/photo imports unless the user picks
one) · title · source + author · Total time · Yield · Cook / Edit / Share ·
tabs **Ingredients · Directions · Timing**. Directions render step numbers,
ingredient names in bold where they match the ingredient list, and the
timer chips in our tomato red (tap one → that step's timer, once cooking).
"Start Cooking" sets dinner time and opens the cooking screen we already
have. No Nutrition tab — we don't have the data and won't guess it.

The reference is Apple's design language; ours keeps the cream/ink/tomato
palette, Fraunces display type and card grammar from the existing screens so
the recipe page looks like it belongs in Dinner, Together rather than in News.

## 5. Model and plumbing (Agent 3)

- `Recipe: Codable, Identifiable` — id, title, source (url, publisher, author),
  imageData (optional, downscaled ≤1600px), yield, totalMinutes, ingredients
  `[String]`, dishes `[[CookingStep]]` (reusing `CookingStep`), importedAt,
  importMethod (link / text / photo / manual), `needsTimingReview: Bool`.
- `RecipeLibrary: ObservableObject` — JSON file in Application Support
  (`recipes-v1.json`), same atomic-write discipline as `SessionStore`.
- `DinnerMenu` gains `kind: .catalog | .recipe(id) | .custom(ids)`; session
  `menuID` stays a string (`recipe:<uuid>`, `custom:<uuid>`), resolved through
  one `MenuResolver` that consults the catalog and the library. A session
  whose recipe was deleted falls back to the catalog with a notice — never a
  crash, never a silent swap.
- `RecipeImporter` — pure functions, fully unit-testable: `parseJSONLD`,
  `parseText`, `extractDurations`, `classifyAttention`, `splitParallel`.
  Network fetch is the only impure piece (one `URLSession` call, 15 s timeout,
  follows redirects, no cookies, no tracking) and is isolated behind a
  protocol so tests never touch the network.
- Vision OCR behind the same `TextSource` protocol; the simulator pass feeds
  it a fixture image.
- Privacy: nothing changes in the nutrition label (still "Data Not
  Collected"); `docs/privacy.html` gains one paragraph: a pasted link is
  fetched by the device directly from the publisher, we run no server.

## 6. Who does what

**Agent 3** — model, library, importer, engine relaxation, Tonight integration,
release builds. Phase 1 target: a TestFlight build where paste-a-link produces
a cookable recipe.

**Agent 2** — (a) the Timing tab, (b) the recipe page and the Add-a-recipe
flow in the house style, (c) copy for estimated-vs-confirmed times and for
multi-hour "behind" states, (d) S7 Thanksgiving menu as catalog content,
(e) five test recipes with known-good timings for the validation seeds.
Format: renders/specs as before (`A2-R1…`), Swift patches welcome for views.

**Agent 1** — (a) unit tests for the importer against a fixture set of 20
real recipe pages (JSON-LD variants: `HowToStep`, `HowToSection`, plain
strings, ISO-8601 durations like `PT1H30M`), (b) XCUITests: import by paste,
timing review, cook a recipe alone, cook two together, delete a recipe that
a session uses, (c) OCR fixture pass, (d) the usual verification pass on every
build. Series `A1-R1…`.

## 7. Schedule (honest)

| Week | Dates | Deliverable |
|---|---|---|
| 1 | Oct 12–18 | Model, library, importer (link + text), Timing tab, "Add a recipe" on Tonight. TestFlight build. Verify Apple News links. |
| 2 | Oct 19–25 | Recipe page in house style, photo/OCR door, custom dinners (combine recipes), Thanksgiving catalog menu, long-step copy. TestFlight build. |
| 3 | Oct 26–Nov 1 | External TestFlight (Beta App Review takes 1–2 days — submit the build Oct 26). Friends cook with it. Fix what they find. |
| 4 | Nov 2–4 | Store listing updated (new screenshots: the recipe page becomes frame 2), submit for review. |
| — | Nov 5–15 | App Review, likely one round of back-and-forth. Live. |
| — | Nov 26 | Thanksgiving. Eleven days of buffer. |

What this costs: 1.0 ships about three weeks later than the plan of October 10.
What it buys: the first public version answers "can I use my own recipes?"
with yes, the 4.2 "thin content" risk (nine fixed menus) disappears, and the
Thanksgiving pitch is real.

Option to run in parallel at no cost: submit the *current* build for review
with "Manually release this version" and hold it. If Apple approves, we know
the privacy pages, listing and signing pass review before the big version
goes in; if they reject, we learn why three weeks early. Joe decides.

## 8. Risks, named

- **Apple News links** may not resolve to a parseable page. Mitigation: the
  text and photo doors exist; verified in week 1 before anyone depends on it.
- **Parsing is never perfect.** Mitigation: the editor is always one tap away
  and the Timing tab makes the cook confirm the only numbers that matter.
- **App Review 5.2.x (intellectual property):** the app stores a personal copy
  of a recipe the user chose, on their device, like every recipe manager on
  the store. We display source and author on the page and link back. No
  sharing of imported recipes between users in 1.0.
- **Scope creep.** Not in this version: share extension, nutrition, scaling
  ingredients, grocery lists, cloud sync, sharing recipes with other people.
  Each is a fine 1.x; none is needed to cook Thanksgiving.
