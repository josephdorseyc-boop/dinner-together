# Dinner, Together — Launch Plan, revision 2 (shareable version for AI collaborators)

Prepared for Joe · October 2026 · revised October 10 with Agent 3's review
Source: interactive `launch-plan.html` (this file is the plain-text equivalent — no JavaScript, no localStorage).

## What changed in revision 2

1. **Paid test lab funnel fixed (§6).** For a paid-upfront app every new download *is* a purchase; the old "downloads vs purchases" split cannot occur (any gap is redownloads). The funnel is now taps → new units → proceeds, and CAC is computed from new units.
2. **Expectation set for the ad test (§6).** CAC ≤ $1.25 on a paid utility in a crowded category would be unusually good; plan for a "pause" verdict and treat it as information.
3. **TestFlight timing added (§5, Week 01).** Beta cooks are external TestFlight testers, which needs a one-time Beta App Review (typically about a day) after the first build.
4. **Promo codes added (§3, §7).** Free download codes for creators and beta cooks instead of paying them or asking them to buy.
5. **Thanksgiving dependency made explicit (§5).** The holiday menu must ship in a 1.0.1 update by early November for a November 9 promotion.
6. **Dated timeline added (§5)**, conditional on Developer Program enrollment approval this weekend.

## 1. Product & pricing

- Product: Dinner, Together — native iOS app. Coordinates multi-dish home cooking around one serving time via backward scheduling (dishes as sequential chains, concurrent across dishes). Completion tracking, "running late" delays shift unfinished steps, local persistence.
- Launch price: **$2.99** (one-time purchase).
- Tagline: "Plan your whole dinner around one serving time — and adjust when cooking runs late."
- Goal of this plan: get the first 100 buyers and **learn what convinces cooks to buy**. Break-even is a cost-recovery milestone, not the goal.

## 2. The deal — proceeds per sale

Formula: `proceeds_per_sale = 2.99 × (1 − apple_fee)`

- Small Business Program (15% fee): $2.99 × 0.85 = **$2.54** per sale. 100 sales → **~$254** proceeds. After $99 Apple Developer membership → **~$155**.
- Standard (30% fee): $2.99 × 0.70 = **$2.09** per sale. 100 sales → **~$209** proceeds. After $99 membership → **~$110**.
- Note: the 15% rate applies once the Small Business Program takes effect — use the actual commission until then.
- At 15%, 100 sales ≈ $254. Spend $99 on membership + the full $150 promotion budget and about $5 is left before other costs.

## 3. The $150 promotion budget

Promo codes cost nothing: paid apps can issue free download codes in App Store Connect for creators, beta cooks and reviewers. Check the current limits there (Apple has been revising this system).

Default allocation (adjustable in the interactive version):

- Search-ad test: **$50**
- Content help: **$25** (editing or filming supplies, only if needed)
- Reserve: **$75** — only releases when a channel shows promise.

Rules:
- Ad test runs only after the app and store page are ready.
- Reserve stays held until a channel demonstrates promise (see paid test lab verdict).

## 4. Break-even explorer

Formula:
- `total_cost = 99 + promotion_spend`
- `sales_to_break_even = ceil(total_cost / proceeds_per_sale)` (uses the fee rate selected)

Example at defaults ($150 promo spend, 15% fee): total cost $249 → ~98 sales to break even.

## 5. Four-week roadmap

Dates follow product readiness. (Interactive version has tap-to-open weeks.)

**Week 01 — Prepare the demonstration** (Spend $0)
- Recruit up to 20 beta cooks.
- Ask each to try an actual dinner.
- Record one 20–30 second demo from the validated app.

**Week 02 — Prepare the audience** ($0–$25 if needed)
- Make six short clips.
- List 20 cooking creators.
- Prepare a landing page, launch signup, and store screenshots.

**Week 03 — Make a small public launch** (Ad test ≤ $50)
- Share organically and approach creators — use campaign links.
- Test ads once the app is live and reporting is ready.

**Week 04 — Review before spending more** (Hold the $75 reserve)
- Compare sales and feedback.
- Refine one thing at a time.
- Treat a later $4.99 price test cautiously.

Seasonal aim: late October / early November launch; November 9–22 Thanksgiving promotion, if the holiday guide is tested.

**Dated timeline (assumes enrollment approved by about October 12):**

| When | What | Gate |
|---|---|---|
| Oct 12–14 | Secrets in GitHub, app record created, first TestFlight build; Joe cooks one real dinner with it | Enrollment approval |
| Oct 14–15 | Submit the build for Beta App Review (external testers) | Joe's dinner finds no blockers |
| Oct 15–22 | Week 01: up to 20 beta cooks, demo recorded | Beta App Review (~1 day) |
| Oct 22–25 | Week 02: clips, creator list, store screenshots re-rendered at dinner time; submit 1.0 | — |
| Oct 26–31 | 1.0 live; Week 03 small public launch | App Review (~1–2 days) |
| By Nov 5 | 1.0.1 with the Thanksgiving menu (Agent 2) submitted | Menu tested by beta cooks |
| Nov 9–22 | Thanksgiving promotion | 1.0.1 live |

**Week 01 dependency:** beta cooks are *external* TestFlight testers. The first build for external testers goes through Beta App Review (typically about a day). Joe, as an internal tester, can install immediately.

**Thanksgiving dependency:** the holiday menu is a content update. It must be in a 1.0.1 build and live by early November to support a November 9 promotion. If it slips, run the promotion with the existing menus or skip it — do not promote a menu that is not in the shipping app.

## 6. Paid test lab

One US App Store Search Ads campaign. Enter real numbers as they come in.

Inputs: ad spend ($), ad taps, **new units** (first-time downloads attributed to the campaign).

**Revision 2:** for a paid-upfront app every new download is a purchase, so "downloads" and "purchases" are the same number. Any apparent gap is redownloads, which earn nothing. Use **new units** from the campaign report, not total installs.

Calculated:
- `cost_per_tap = ad_spend / taps` (if taps > 0)
- `cost_per_paying_customer (CAC) = ad_spend / new_units` (if new_units > 0)
- `tap_to_purchase = new_units / taps` as %
- `proceeds_from_campaign = new_units × proceeds_per_sale`

Verdict logic (target: **$1.25** per paying customer):
- If new_units = 0: "Enter new units to judge the test."
- If CAC ≤ $1.25: GOOD — "Under the $1.25 target — a channel showing promise. The reserve can release."
- If CAC > $1.25: BAD — "Over the $1.25 target — pause cash expansion, learn first."

Example: $15 spend, 40 taps, 8 new units → $0.38/tap, **$1.88** CAC, 20% tap→purchase → over target, pause.

**Expectation:** CAC ≤ $1.25 for a $2.99 paid utility in a crowded, mostly free category would be unusually good. Expect the verdict to be "pause" and treat that as the test working — it tells you to put effort into organic and creator channels instead of cash.

Checkpoints & cautions:
- Inspect results at **$15** gross spend before continuing; pause at **$50**.
- Set an end date — $5 average daily budget for ten days is a starting setup, though a single day can exceed $5.
- Count the **full ad cost before credits**. Apple's $100 new-advertiser credit does **not** raise the $50 gross test limit — confirm it in Billing.
- Total installs include redownloads; judge the test on new units and proceeds only.
- Sparse results give direction, not proof.

## 7. Organic playbook ($0)

Join the cooking conversation — late sides, several dishes finishing together, holiday hosting. Five thoughtful conversations a week.

- Tailor each comment to the video and the question.
- Give a useful tip first; mention the app only when it directly helps.
- Say you are the creator. Describe the app as in testing until launch; link where welcomed.
- Follow the replies — reply to genuine questions. Log interested cooks; likes and replies do not equal sales.
- Creators: invite a beta trial, with no obligation to promote. Before launch, invite them as TestFlight testers; after launch, give them a promo code so they get the real app free.

Comment template (verbatim):
> Including resting time when working backward from serving time really helps. I'm building Dinner, Together around that idea: a timing guide for multi-dish dinners, with a way to review the plan when cooking runs late. It's in testing now.

## 8. Weekly check-in

Keep the next step clear. Use sales data and real cooking feedback to decide what to improve. (Interactive version saves ticks on-device via localStorage.)

Check-in categories:
1. Discovery — product-page exposure and first-time downloads.
2. Revenue — paid purchases, refunds and proceeds.
3. Advertising — gross spend, taps, new downloads and search terms.
4. Product value — dinners completed, confusing moments, use again.
5. Budget — cash spent and reserve remaining.

Notes:
- App Store usage data covers participating users and has privacy thresholds.
- Use tester feedback for completed dinners — it is not an automatic analytics metric.
- Keep an expense log alongside the results.

Next step: film the short demonstration. Choose a menu and time. Show the current action. Review a delay while the running timer keeps its deadline.

After launch: evaluate adding your own dishes before scanning. Current menus are timing guides, not complete recipes. Protect earlier buyers if the pricing model changes.

---
End of shareable plan.
