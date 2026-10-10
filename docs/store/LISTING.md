# App Store listing — Dinner, Together 1.0 (draft for Agent 2's review)

Paste-ready. Character limits are App Store Connect's; counts are given so
nothing gets truncated. Agent 2: edit freely, keep the voice (calm, honest,
no hype), and return the file.

## App Information

| Field | Value |
|---|---|
| Name (30) | `Dinner, Together` (16) |
| Subtitle (30) | `Every dish ready at the same time` (29) |
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
`Pick a dinner, pick a time, and cook with a plan that stays honest when things run late.` (89)

**Description** (4000)

```
Dinner, Together plans a whole meal backward from the moment you want to eat, then walks you through it one step at a time.

Pick a dinner — steak au poivre with mash and green beans, garlic mushroom pasta and a salad, or an easy salmon evening — choose when you want to sit down, and every step of every dish gets its place in a single timeline so that everything is ready together.

While you cook, the screen answers one question: what do I do right now?

• The next thing that needs your hands is always at the top, with running timers and what's coming up underneath.
• Timers count down to a deadline, not from a guess. When one ends, the app says "check the food" — it never decides a step is done for you.
• Running behind is normal. A quiet notice shows the new estimate next to the dinner time you chose; nothing moves on its own. "Review dinner time" shows exactly what would change, and Undo takes it back.
• Starting a step before the one it depends on is finished takes an explicit "Start anyway," never a silent skip.
• Pick up where you left off. If life interrupts, the plan waits; the next day it asks whether to resume or start fresh.
• Reminders arrive as notifications when the phone is in your pocket (optional — the in-app timers work without them).

Designed for the counter: large, readable times, a warm cream-and-tomato palette, full Dark Mode and Dynamic Type support, and a two-column layout on iPad. No account, no ads, no tracking, nothing leaves your device.

Timing in the app is a planning estimate. Always confirm doneness with your recipe and a thermometer.
```

**Keywords** (100, comma-separated, no spaces after commas)
`cooking timer,dinner planner,meal timing,kitchen timer,recipe timer,cook time,multiple timers,sous chef` (99)

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
