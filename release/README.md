# Shipping Dinner, Together to the App Store — without a Mac

Everything technical runs on GitHub's macOS machines. Your part is the Apple
account side, which only the account holder can do. Do the steps in order;
each one is a few minutes except where noted.

## 0. Enroll in the Apple Developer Program  (critical path: 24–48 h approval)

- https://developer.apple.com/programs/enroll — or the **Apple Developer**
  app on your iPhone, which verifies your ID in-app and is usually faster.
- Enroll as an **Individual** (the seller name on the App Store is your name).
  An organization enrollment needs a D-U-N-S number and adds days.
- $99/year. Nothing below works until the enrollment email arrives.

## 1. Collect the five secrets

| Secret | Where it comes from |
|---|---|
| `APPLE_TEAM_ID` | developer.apple.com/account → **Membership details** → Team ID (10 characters, e.g. `A1B2C3D4E5`). |
| `DT_BUNDLE_ID` | You choose it: reverse-DNS, lowercase, no spaces — e.g. `com.josephdorsey.dinnertogether`. **It can never change once the app exists in App Store Connect.** |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | appstoreconnect.apple.com → **Users and Access** → **Integrations** tab → **App Store Connect API** → Team Keys → **+**. Name: `GitHub CI`. Access: **Admin** (required: Xcode creates the signing certificate in the cloud with this key, and only Admin can). Download the `.p8` file — **Apple lets you download it exactly once**; keep it somewhere safe. The **Issuer ID** is shown at the top of that page; the **Key ID** is in the key's row. `ASC_KEY_P8` is the whole text of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. |

Put them in the repository: GitHub → `dinner-together` → **Settings** →
**Secrets and variables** → **Actions** → **New repository secret**, one at a
time, names exactly as above. (Secrets are write-only; nobody, including
CI logs, can read them back.)

## 2. Register the bundle identifier

developer.apple.com/account/resources/identifiers → **+** → **App IDs** →
**App** → Description `Dinner, Together`, Bundle ID **Explicit** = your
`DT_BUNDLE_ID`. No capabilities need ticking (timer reminders are local
notifications; they need no entitlement). Register.

## 3. Create the app record in App Store Connect

appstoreconnect.apple.com → **My Apps** → **+** → **New App**:
Platforms iOS · Name `Dinner, Together` (if Apple says the name is taken,
`Dinner Together — Cook on Time` is the fallback; the display name on the
phone stays "Dinner, Together") · Primary language English (U.S.) · Bundle
ID: pick the one you registered · SKU `dinnertogether-ios` · User Access
Full. Create.

## 4. Build and upload from GitHub

Actions tab → **release** → **Run workflow** → version `1.0`, submit ✅,
require_green ✅ → Run. About 10 minutes. The job refuses to run unless the
validation workflow is green for that exact commit.

- First run: Xcode registers the certificate and profile automatically
  (cloud signing). If it fails, `SUMMARY.md` in the run's artifact says why;
  the usual causes are a secret pasted with a stray space, or an API key
  that isn't Admin. The same verdict lines are also check-run annotations
  and the text outputs are pushed to the `release-results` branch
  (`run-N/`), for anyone who cannot download artifacts.
- When "uploaded build 1.0 (N)" appears, Apple processes the build for
  5–30 minutes; then it shows under **TestFlight** in App Store Connect.

What the first five runs taught (October 11, 2026 — build 1.0 (5) was the
first accepted upload):

- **The archive is built unsigned; the export signs.** An automatic-signing
  archive asks Apple for an *iOS App Development* profile, and the portal
  refuses to generate one for a team with no registered devices (run 2).
  Overriding the identity to Apple Distribution is rejected as a conflict
  with automatic signing (run 3). So `build-release.sh` archives with
  `CODE_SIGNING_ALLOWED=NO` and lets `-exportArchive`, which runs with cloud
  signing, apply the Apple Distribution certificate and App Store profile —
  no device needs to be registered, ever (run 4 onward).
- **Xcode 26 is required.** App Store Connect refuses uploads built with the
  iOS 18 SDK ("must be built with the iOS 26 SDK or later", run 4). The
  macos-15 image's default Xcode is 16.4, so every macOS job selects
  Xcode 26.2 via `DEVELOPER_DIR` (newest 26.x as fallback; override with
  `DT_XCODE`). Validation and store-assets use the same selection so what is
  tested and photographed is what ships. Validation run 30 was the first
  on 26.2: 69/69 unit tests on both simulators, 10/10 + 3/3 UI flows (the
  iPad popover case that was an expected failure on 16.4 passes outright).

## 5. Put it on your iPhone (TestFlight)

App Store Connect → your app → **TestFlight** → the build → add yourself
under **Internal Testing** (create a group, add your Apple ID). Install the
**TestFlight** app from the App Store on your iPhone, accept the invitation,
install. Cook a dinner with it. This is the first time anyone will have run
the app on real hardware — notification delivery, haptics and VoiceOver are
all first seen here.

## 6. Money: agreements, tax, banking  (can be done in parallel with 4–5)

App Store Connect → **Business** (formerly Agreements, Tax, and Banking):
accept the **Paid Apps Agreement**, add a bank account, complete the tax
forms (W-9 for a U.S. individual). Apple takes a day or so to activate it.
A paid app cannot go live until this is active. Then apply for the **App
Store Small Business Program** (same place; cuts Apple's commission from
30% to 15% while you earn under $1M/year).

## 7. The listing

`docs/store/LISTING.md` has every field, ready to paste: name, subtitle,
description, keywords, promotional text, category, age-rating answers, the
privacy "nutrition label" (Data Not Collected), review notes, and the URLs.
Screenshots come from the **store-assets** workflow (Actions → store-assets
→ Run workflow → download `app-store-screenshots`): 6.9-inch iPhone and
13-inch iPad, light and dark, already at the exact pixel sizes App Store
Connect requires.

The privacy policy and support pages are in `docs/`; turn on GitHub Pages
once (repo **Settings** → **Pages** → Source: Deploy from a branch → `main`,
folder `/docs` → Save) and they are live at
`https://josephdorseyc-boop.github.io/dinner-together/privacy.html` and
`…/support.html`. The support page carries Joseph.DorseyC@gmail.com as the
contact; App Store Connect's "Support URL" and "App Review contact" fields
use the same address.

## 8. Submit

App Store Connect → the app → **1.0 Prepare for Submission**: pick the
build, paste the listing, upload screenshots, set the price, answer the
age-rating and export-compliance questions (`LISTING.md` has the answers),
**Add for Review** → **Submit**. Review typically takes 24–48 hours.
Set release to **Manually release this version** so you choose the day it
goes live.

## What each piece of this folder is

- `build-release.sh` — archive → export `.ipa` → upload, with cloud signing.
  Records the bundle ID, version and build it actually signed, so the
  summary can't claim a build it didn't make.
- `dry-run.sh` — proves the script's control flow against the fake
  toolchain (6 scenarios, run on every push by the `supplemental` CI job).
  It exercises no signing; the first real signing happens in step 4.
- `../.github/workflows/release.yml` — the manual workflow around it.
- `../.github/workflows/store-assets.yml` — App Store screenshots.
