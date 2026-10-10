# App Store listing — Dinner, Together 1.0 (Agent 2 review A2-5 applied)

Paste-ready. Character limits are App Store Connect's; counts are given so
nothing gets truncated. Agent 2's A2-5 ("honest store listing") is applied:
the copy claims only what 1.0 does (three preset menus, timing guides rather
than recipes, no custom menus), and the keywords are single terms so the
store can combine them. Lengths verified: subtitle 24/30, promotional text
88/170, keywords 79/100, description 1,736/4,000.

## App Information

| Field | Value |
|---|---|
| Name (30) | `Dinner, Together` (16) |
| Subtitle (30) | `Your whole dinner, timed` (24) |
| Primary category | Food & Drink |
| Secondary category | Utilities |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | Answer **None** to every question → **4+** |
| Privacy policy URL | `https://josephdorseyc-boop.github.io/dinner-together/privacy.html` |
| Support URL | `https://josephdorseyc-boop.github.io/dinner-together/support.html` |
| Marketing URL | (optional; leave blank for 1.0) |
| Copyright | `2026 Joseph Dorsey` |

## App Privacy (the "nutrition label")

**Data Not Collected.** No data types selected. Tracking: No. (The app has no
network connection, no account, no analytics, no SDKs; see
`DinnerTogether/PrivacyInfo.xcprivacy`.)

## Pricing

Paid app, no in-app purchases, **$2.99** (Tier 3) at launch. Reasoning in
`APP_STORE_PLAN.md`. Availability: all territories. Pre-orders: no.

## Version 1.0

**Promotional text** (170; can change without a new build)
`Pick a dinner, pick a time, and cook with a plan that stays honest when things run late.` (88)

**Description** (4000)

```
Dinner, Together helps you time a multi-dish dinner, working backward from when you want to eat.

Version 1.0 includes three preset dinner menus: steak au poivre with mash and green beans, garlic mushroom pasta with salad, and a salmon dinner. Choose a menu, review its timing estimates, and pick your serving time. The app brings the steps together in one timeline.

These are timing guides, not complete recipes. Bring your own recipe for ingredients and cooking instructions. Adding or importing your own menus is not included in this release.

While you cook, see what needs your attention now, which timers are running, and what's coming next.

• Start a timer using the step's duration estimate. Once started, its deadline stays fixed when you move dinner time.
• When a timer ends, the app says “Check the food.” You decide when the step is done.
• Running behind? Compare your chosen dinner time with the latest readiness estimate. Review a proposed time change before applying it, with Undo available afterward.
• If a step depends on unfinished work, the app explains the dependency before you choose whether to start anyway.
• Your plan and progress are saved on your device. When you return to an old plan, choose whether to continue or start fresh.
• Optional local notifications remind you when timers end. In-app timers work without notification permission.

Large times, a warm cream-and-tomato palette, Dark Mode, adjustable text sizes, and a two-column cooking layout on iPad help you follow the plan at the counter.

Works offline. No account, ads, tracking, or subscription.

Timing estimates help with planning; they cannot determine doneness. Follow your recipe and check food with a thermometer where appropriate.
```

**Keywords** (100, comma-separated, no spaces after commas)
`cooking,kitchen,timer,meal,planner,schedule,multiple,offline,steak,salmon,pasta` (79 bytes)

**What's New in This Version** (4000)
`First release.`

**Screenshots** — from the `store-assets` workflow artifact, in this order
(captions are optional on the App Store; if Agent 2 wants captioned frames,
they can be composed from the same PNGs):

| # | iPhone 6.9" (1320×2868) | What it shows |
|---|---|---|
| 1 | `on-schedule-light.png` | Cooking screen, on time: DINNER AT, RIGHT NOW, running timer |
| 2 | `late-prep-light.png` | "Running about 7 min behind" — the estimate beside the chosen time |
| 3 | `expired-timer-light.png` | "Check the food" — a timer ending is a prompt, not a completion |
| 4 | `way-behind-dark.png` | Dark Mode, amber emphasis at 15 min behind |
| 5 | `late-prep-ax-large-text.png` | Accessibility text size, compact notice |
| 6 | `all-done-late-light.png` | "Time to enjoy dinner." |

Same six for iPad 13" (2064×2752) from `ipad/`. The Tonight (planning)
screen is not yet photographed by the harness; `screenshots.sh` could add a
`-dt-open-cooking`-less variant — Agent 2 to say whether it's wanted.

## App Review Information

- Sign-in required: **No** (there is no account).
- Contact: Joe's name, phone, email (Apple uses these only to reach you).
- **Notes to the reviewer**:

```
Dinner, Together is an offline cooking-timing planner. No account, no network. To see it work: on the Tonight tab pick "Steak night", choose a dinner time about 45 minutes from now, tap "Start cooking". The Cooking tab leads with the step to do now; tap "Start this step" to begin a timer. When a timer ends the app asks you to check the food and mark the step done — it never marks steps done by itself. If a step finishes late, a notice shows the new estimate next to the chosen dinner time; "Review dinner time" lets you move dinner to it, and Undo restores it. Notifications are optional local timer reminders.
```

- Export compliance: the Info.plist key `ITSAppUsesNonExemptEncryption = NO`
  is set in the project, so App Store Connect should not ask; if it does, the
  app uses **no** encryption beyond what iOS provides.

## Release

**Manually release this version** after approval, so the privacy/support
pages, pricing and the Small Business Program status are all confirmed
before it goes live.
