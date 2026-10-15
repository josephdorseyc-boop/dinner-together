# App Store listing — Dinner, Together 1.0 (A2-17 recipe-import draft)

Public copy below reflects main `cb28c05` (build 9): ten preset timing guides,
a Recipes library, link/text/screenshot import, and an optional cover crop.
It does not advertise page-color customization until build 10 is the selected
submission build. Verified lengths: name 16/30; subtitle 24/30; promotional text 88/170;
keywords 74/100; description 2167/4,000.
Submission fields marked for owner verification are not paste-ready answers.

## App Information

| Field | Value |
|---|---|
| Name (30) | `Dinner, Together` (16) |
| Subtitle (30) | `Your whole dinner, timed` (24) |
| Primary category | Food & Drink |
| Secondary category | Utilities |
| Content rights | Owner verification required: users can import publisher recipes/photos. Reconcile permissions with Apple's Content Rights question; do not reuse the old “no third-party content” answer. |
| Age rating | Complete the current questionnaire for the shipping build; do not prescribe blanket answers from the earlier preset-only build. |
| Privacy policy URL | `https://josephdorseyc-boop.github.io/dinner-together/privacy.html` |
| Support URL | `https://josephdorseyc-boop.github.io/dinner-together/support.html` |
| Marketing URL | (optional; leave blank for 1.0) |
| Copyright | `2026 Joseph Dorsey` |

## App Privacy (the "nutrition label")

**Proposed label: Data Not Collected; Tracking: No — A1/Joe to verify for the
shipping build.** The app's local recipe/session storage is distinct from
collection by the developer. Link import does make network requests: it
fetches the chosen page, any followed redirect, and an available recipe photo.
`URLSessionRecipeFetcher` uses an ephemeral session and refuses cookies.
There is no app account or analytics service in the reviewed source.

Do not justify the label with “no network connection.” Verify the actual data
flows against [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
and reconcile the linked privacy page with recipe import before submission.
The companion A2-17 patch supplies factual privacy-page wording for review;
it does not change the privacy manifest or certify the final label.

## Pricing

Paid app, no in-app purchases, **$2.99** (Tier 3) at launch. Reasoning in
`APP_STORE_PLAN.md`. Availability: all territories. Pre-orders: no.

## Version 1.0

**Promotional text** (170; can change without a new build)
`Pick a dinner, pick a time, and cook with a plan that stays honest when things run late.` (88)

**Description** (4000)

```
Dinner, Together helps you time a multi-dish dinner, working backward from when you want to eat.

Choose from ten preset dinner timing guides, including steak night, salmon, lemon chicken, turkey tacos, meat-free dinners, and Thanksgiving. Review the timing estimates and pick your serving time. The app brings each menu's dishes together in one timeline.

The preset menus are timing guides, not complete recipes. Use your trusted recipes for ingredients and cooking instructions.

Bring your own recipes into the Recipes tab: paste text, import a supported recipe link, or choose screenshots. Review the imported ingredients and directions, confirm the step estimates, and save a recipe to cook with a timed plan. Screenshot text is recognized on your device, and you can choose an optional cover crop. Import support varies by page; when a link cannot be read, use screenshots or pasted text instead.

While you cook, see what needs your attention now, which timers are running, and what's coming next.

• Start a timer using the step's duration estimate. Once started, its deadline stays fixed when you move dinner time.
• When a timer ends, the app says “Check the food.” You decide when the step is done.
• Running behind? Compare your chosen dinner time with the latest readiness estimate. Review a proposed time change before applying it, with Undo available afterward.
• If a step depends on unfinished work, the app explains the dependency before you choose whether to start anyway.
• Your plan and progress are saved on your device. When you return to an old plan, choose whether to continue or start fresh.
• Optional local notifications remind you when timers end. In-app timers work without notification permission.

Large times, a warm cream-and-tomato palette, Dark Mode, adjustable text sizes, and a two-column cooking layout on iPad help you follow the plan at the counter.

Plan and cook with saved recipes offline. Importing a web link requires internet access. No account, ads, tracking, or subscription.

Timing estimates help with planning; they cannot determine doneness. Follow your recipe and check food with a thermometer where appropriate.
```

**Keywords** (100, comma-separated, no spaces after commas)
`cooking,kitchen,timer,meal,planner,schedule,multiple,offline,recipe,import` (74 bytes)

**What's New in This Version** (4000)
`First release.`

**Screenshots** — produced by the `store-assets` workflow (Actions →
store-assets → Run workflow) on the iPhone 17 Pro Max and iPad Pro 13-inch
simulators and composed into captioned frames by
`release/compose-store-frames.py` (Agent 2's six-frame story, their
captions). Twelve files, exact App Store sizes: iPhone 6.9-inch 1320×2868,
iPad 13-inch 2064×2752. Upload in this order:

| # | Caption | Render |
|---|---|---|
| 1 | Pick dinner. Pick a time. | Tonight screen, Steak night selected (`tonight-steak-light`) |
| 2 | Know what to do now. | Cooking, on schedule, timer running (`on-schedule-light`) |
| 3 | Running late? Review the plan. | The review sheet from the UI tests (`01-review-sheet`) |
| 4 | A timer ends. You check the food. | Expired-timer cooking screen (`expired-timer-light`) |
| 5 | Nine dinners to choose from. | Tonight list scrolled, tofu selected (`09-tonight-menus`) |
| 6 | A calmer counter, even after dark. | Dark Mode cooking screen (`on-schedule-dark`) — **replace before submission:** from build 20 only Tonight goes dark (Joe, October 15); use Tonight in Dark Mode (`r24d-tonight-first-launch-dark`, or a recipe's cover at night) and a caption about the evening, e.g. “Tonight, even after dark.” |

The table describes existing generated assets. Before submission, replace
frame 5 with **“Your recipes. Your timing.”** using a real Recipes/detail
capture with original or licensed sample content. The store-assets workflow
and composer still need that change; this text patch does not generate it.
Keep the other five frames focused on whole-dinner timing. Do not use the
synthetic CI cover as consumer-facing food photography, or advertise build
10's page colors in a build 9 listing.

Run the workflow in the late afternoon Mountain Time so the clocks in the
frames read like dinner (the runner is set to America/Denver); a run at
4 AM UTC produced "Dinner at 5:03 AM" renders, usable for layout review only.

## App Review Information

- Sign-in required: **No** (there is no account).
- Contact: Joe's name, phone, email (Apple uses these only to reach you).
- **Notes to the reviewer**:

```
Dinner, Together is a cooking-timing planner with a local recipe library. No account is required. Planning and cooking work offline; importing a web link fetches the selected page and an available recipe photo. To see the timing planner: on the Tonight tab pick "Steak night", choose a dinner time comfortably later than the menu's displayed estimate, and tap "Build my cooking plan". If the selected time is too soon, the button reads "Build plan for <time>" and applies that feasible time. The Cooking tab leads with the step to do now; tap "Start this step" to begin a timer. When a timer ends the app asks you to check the food and mark the step done — it never marks steps done by itself. If a step finishes late, a notice shows the new estimate next to the chosen dinner time; "Review dinner time" lets you move dinner to it, and Undo restores it. Notifications are optional local timer reminders.

To inspect recipe import, open Recipes and add a recipe using Link, Screenshots, or Text. Imported content is reviewed before saving; check directions and step estimates before cooking. Screenshot recognition runs on the device. If a recipe link has no readable recipe data (including some Apple News links), the app offers screenshots or pasted text instead. A screenshot cover crop is optional.
```

- Export compliance: the Info.plist key `ITSAppUsesNonExemptEncryption = NO`
  is set in the project, so App Store Connect should not ask; if it does, the
  app uses **no** encryption beyond what iOS provides.

## Release

**Manually release this version** after approval, so the privacy/support
pages, pricing and the Small Business Program status are all confirmed
before it goes live.
