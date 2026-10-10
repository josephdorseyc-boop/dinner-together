# App Store plan — Dinner, Together

Goal (Joe, Oct 9): get on the App Store and start monetizing, as fast as is
honest. This file is the plan; `release/README.md` is your checklist;
`LISTING.md` is the listing.

## The shortest path, and who does what

| Day | Joe | Agent 3 (me) | Agents 1 & 2 |
|---|---|---|---|
| 0 (tonight) | Enroll in the Developer Program. | Release pipeline, icon, privacy manifest, Info.plist, listing draft, pages — all in the repo now. | A2: review the listing, icon and screenshot plan; propose menu content. A1: verify the release pipeline and project settings. |
| 1–2 | Enrollment lands → secrets (five), bundle ID, app record, Paid Apps Agreement + banking + tax, turn on GitHub Pages, put your support email in the support page. | Integrate reviewer patches; keep the validation loop green. | — |
| 2 | Run **release** (submit ✅). Install from TestFlight. **Cook one dinner with it.** | Read the run; fix what signing complains about (first-run issues are normal and specific). | — |
| 2–3 | Run **store-assets**; upload screenshots; paste the listing; set $2.99; submit. | Final evidence package. | A2 looks at the real-device notes you write after cooking. |
| 3–5 | App Review (24–48 h typical). Release manually. | Prepare 1.0.1 fixes from review feedback if any. | — |

Realistic: **live within a week of enrollment approval** if nothing in
review or on the device surprises us. Two things could add days: a 4.2
"minimum functionality" review response (see below) and anything the first
real-device run reveals (notifications, haptics) — both have plans.

## Monetization: paid upfront at $2.99, then grow

**Why paid, not free-with-purchase, for 1.0:** it ships with zero new code.
In-app purchases need StoreKit 2 integration, receipt/transaction handling,
restore, a paywall screen, product configuration, and a new round of
reviewer testing — a week of work that would sit between us and the store.
A paid app needs none of that, and the price can change any day.

**Why $2.99:** the app is a focused utility with three dinners. $0.99 reads
as disposable; $4.99 invites "for three menus?" in reviews. $2.99 (Tier 3)
is where single-purpose cooking utilities sit. With the Small Business
Program, Apple keeps 15%, so each sale nets about $2.54 before tax.

**What to expect, plainly:** cooking timers are a crowded, mostly free
category. The thing this app does that the free ones don't — honest
recovery when dinner runs late — is a real differentiator but a subtle one
to sell in a screenshot. Early revenue will be modest; the goal of 1.0 is to
be on the store, learn from real cooks, and have the pipeline so that 1.1
ships in days, not weeks.

**Growth path (after 1.0 is live):**
1. **More dinners** — the single biggest lever for both reviews and
   Guideline 4.2. Agent 2 is asked for six to eight new menus in the
   catalog's format (each must pass the engine's feasibility checks; the
   JS mirror and `swift test` catch an infeasible plan).
2. **1.1: "Your own dinner."** Let the cook build a dinner from their own
   steps. This is the feature people will ask for first.
3. **Then consider freemium:** free with three dinners, one-time $4.99
   "Full kitchen" unlock for all menus + custom dinners, via StoreKit 2.
   Only once there's a reason to believe the free funnel converts.
4. Subscriptions: not for this product unless it grows a recurring content
   stream (weekly menus). Don't start there.

## App Review risks and what's already done about them

| Guideline | Risk | Mitigation |
|---|---|---|
| 4.2 Minimum functionality | Three menus can read as thin. | The planning engine, dependency-aware timeline, recovery flow and iPad layout are substantial; the review notes point the reviewer at them. More menus from Agent 2 before submission if they arrive in time; otherwise in 1.0.1. |
| 2.1 Completeness | Crashes, placeholder content. | 61 unit tests + 11 UI flows on CI per push; no placeholders in the UI; bundle ID placeholder is refused by the release script. |
| 5.1.1 Privacy | Missing policy / wrong label. | Privacy manifest in the bundle; policy page; "Data Not Collected." |
| 2.3 Accurate metadata | Screenshots must be the real app. | They are simulator captures of the shipping build, at Apple's sizes. |
| 1.4.1 Physical harm | Food-safety claims. | Copy says timing is an estimate and to use a thermometer, in-app and in the listing. |
| 2.5.4 Background | — | No background modes requested. |

## Still unproven until the first TestFlight build

Notification delivery on a real device, haptic feedback, VoiceOver reading
order, battery behavior with a long cook, and how the app feels on a counter
with wet hands. Day 2's "cook one dinner with it" is not a formality; write
down everything that annoys you and send it to me and Agent 2.

## Names and legal (quick checks you should make)

- "Dinner, Together" — search the App Store for the name before creating
  the record; if taken, the fallback in `release/README.md`.
- The seller name is yours (individual enrollment). Axis-1 is unrelated and
  should stay out of this listing.
- Copyright line: `2026 Joseph Dorsey`.
