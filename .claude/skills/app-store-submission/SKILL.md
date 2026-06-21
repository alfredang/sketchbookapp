---
name: app-store-submission
description: End-to-end submission of a native iOS/iPadOS app to the App Store, driven by the App Store Connect (ASC) API + Xcode CLI, with Playwright MCP for the UI-only steps (App Privacy label, age rating). Use when archiving, uploading a build, capturing/uploading screenshots, setting metadata/pricing, and submitting for review. Covers screenshot device-size requirements and how to capture real Simulator screenshots, the hard-won API gotchas, the API-vs-Playwright split, and a field-tested App Review rejection checklist.
license: MIT
metadata:
  version: "2.3.0"
---

# App Store Submission (API-first)

Submit a native iOS/iPadOS app to the App Store with the **App Store Connect (ASC) API**
and the **Xcode command line**, doing as much as possible programmatically. This skill
captures a complete, repeatable workflow plus the non-obvious blockers that waste hours.

Use the bundled scripts in [scripts/](scripts/). Per-project values and the metadata copy
go in the project's `.env` (see [.env.example](.env.example)) and the template at the end of
this doc. Placeholders below use `<ANGLE_BRACKETS>` — replace them with your own values.

## What the API CAN and CANNOT do

**API can:** create/read the app record, set category & pricing, set version metadata
(description, keywords, subtitle, promo text, support/marketing URLs, copyright,
**privacyPolicyUrl**), create the **App Review contact**, upload builds (via `altool`),
attach a build, upload screenshots, create a review submission, and **submit for review**.

**API CANNOT (must be done once in the web UI):**
- **App Privacy "nutrition label"** (`appDataUsages`). There is **no public API** — the
  app resource exposes no `appDataUsages` relationship; every path 404s. Set it in the UI:
  *App Privacy → Get Started → declare what you collect (or "No, we do not collect data") → Publish*.
- **Age rating / content rights** declarations are also effectively UI-only.
- **Deleting an empty draft review submission** returns 403 — harmless, leave or delete in UI.

Plan for one short UI visit per app for the App Privacy publish. Everything else is scriptable.

## Two ways to drive a submission: API and Playwright

This skill is **API-first** — scripts are faster, deterministic, and reviewable. But every
submission has a few **UI-only** steps (App Privacy label, age rating, content-rights) and
sometimes the API is wrong or down. Use **Playwright MCP** to drive the App Store Connect web
UI for exactly those cases. The two approaches compose; pick per step.

| Submission step | API (`scripts/asc_submit.py`) | Playwright (ASC web UI) |
|---|---|---|
| App record create | ✗ (403) — UI `+ → New App` | ✓ |
| Build upload | ✓ `altool` | ✗ (Xcode/Transporter only) |
| Version metadata (desc, keywords, URLs, copyright) | ✓ `set-metadata` | ✓ (fallback) |
| Screenshots | ✓ `screenshots` (3-step) | ✓ (drag-drop; good for re-ordering) |
| Review contact | ✓ `review-contact` | ✓ |
| **App Privacy nutrition label** | ✗ **no public API** | ✓ **required path** |
| **Age rating / content rights** | ✗ effectively UI-only | ✓ **required path** |
| Pricing / availability | ✓ | ✓ |
| Submit for review | ✓ `submit` | ✓ |

**Rule of thumb:** do everything scriptable via the API; use Playwright **only** for App
Privacy + age rating (and as a fallback when an API call misbehaves). Always finish with
`python3 scripts/asc_submit.py status` to confirm the true state regardless of which path you used.

### Playwright recipe for the UI-only steps

App Store Connect uses **Apple ID sign-in with 2FA**, which a headless/automated browser
cannot complete unattended. So:

1. **Authenticate — with auto-read 2FA.** `mcp__playwright__browser_navigate` to
   `https://appstoreconnect.apple.com`. Fill the sign-in form from `.env`
   (`ASC_LOGIN_EMAIL` / `ASC_LOGIN_PASSWORD`) via `browser_type` + `browser_click` **Continue**.
   Then handle two-factor **without a human** as follows:
   - Apple's *trusted-device* prompt shows the code only in an on-device popup (unreadable).
     So on the 2FA screen `browser_click` **"Didn't get a code?"** → **"Send code via text
     message"** (a.k.a. *Text Me a Code* / *More Options → Text*). This delivers an **SMS**.
   - Read the code from the Mac's Messages with the bundled script (polls until it arrives):
     ```bash
     python3 scripts/read_imessage_2fa.py --wait 90 --within 180
     ```
     It prints the latest 6-digit Apple code to stdout (exit 0), or exits 1 if none/denied.
   - `browser_type` that 6-digit code into the verification field; submit. If the page offers
     **"Trust"**, click it so the session sticks. Reuse this session for the rest of the run
     (don't close the browser between steps).
   - **Prerequisites for the auto-read** (one-time): grant **Full Disk Access** to the terminal /
     Claude Code (System Settings → Privacy & Security → Full Disk Access) — otherwise `chat.db`
     is "authorization denied"; and the trusted phone number's SMS must sync to this Mac's
     Messages. If either isn't set up, fall back to a human entering the code once.
2. **App Privacy** (the one step the API can't do):
   - Navigate to `https://appstoreconnect.apple.com/apps/<APP_ID>/distribution/privacy`.
   - `browser_snapshot` to read the accessibility tree, then `browser_click` **Get Started** /
     **Edit**. For an app that collects nothing, choose **"No, we do not collect data"** and
     `browser_click` **Publish**. Otherwise tick each collected data type + usage + linkage.
   - Re-`browser_snapshot` to confirm it shows **Published**.
3. **Age rating:** open the app's **App Information** page, click **Edit** next to Age Rating,
   answer the questionnaire (`browser_click` the radio options from the snapshot), **Save**.
4. **App Availability (do this EVERY time — see step 2b):** navigate to
   `https://appstoreconnect.apple.com/apps/<APP_ID>/distribution/pricing`. If the **App
   Availability** section shows a bare **Set Up Availability** button, `browser_click` it →
   **All Countries or Regions** → **Next** → **Confirm**. Re-`browser_snapshot`; it should now
   read **"Availability (N Countries or Regions)"** with rows **Processing to Available**.
5. **Verify, then submit via API.** Re-run `status`; if no blockers remain, `submit`.

Notes: prefer `browser_snapshot` (structured, stable) over `browser_take_screenshot` for
deciding what to click; ASC is a heavy SPA, so `browser_wait_for` text after each navigation.
With the SMS-code auto-read above (`scripts/read_imessage_2fa.py`) the whole flow can run
**unattended** once Full Disk Access is granted; without it, fall back to a human typing the
one-time code.

## Prerequisites (one-time per Apple account)

1. **Paid Apple Developer Program** membership (accept the latest PLA in the portal).
2. **Generate the App Store Connect API key — the ONE unavoidable portal step.**
   An ASC API key **cannot be created via API** (chicken-and-egg); the account holder must
   generate it once in the web UI. After that, this skill drives everything else without
   touching the portal. The exact clicks:

   > 1. Sign in at <https://appstoreconnect.apple.com> as the **Account Holder / Admin**.
   > 2. **Users and Access** → top tab **Integrations** → **App Store Connect API** →
   >    **Team Keys**.
   > 3. Click **+** (Generate API Key). Name it (e.g. "automation"), set **Access = Admin**
   >    (or at least **App Manager**), **Generate**.
   > 4. **Download** the **`AuthKey_<ASC_KEY_ID>.p8`** — this is offered **only once**. Save it to
   >    `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8` then `chmod 600` it.
   > 5. Copy the **Key ID** (the 10-char id in the row) and the **Issuer ID** (UUID shown
   >    above the keys list).

   These three values are all the skill needs. If a key is ever lost/leaked, **Revoke** it
   in the same screen and generate a new one.
3. Put the **Key ID** and **Issuer ID** in a local **`.env`** (gitignored) and point
   `ASC_PRIVATE_KEY_PATH` at the `.p8`. See [.env.example](.env.example). The `.p8` lives
   outside the repo and is **never** committed (`.gitignore` excludes `.env` and `*.p8`).

```bash
# .env  (gitignored)
ASC_KEY_ID=<ASC_KEY_ID>
ASC_ISSUER_ID=<ASC_ISSUER_ID>            # xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_PRIVATE_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8
```

Load it before running scripts: `set -a; source .env; set +a`

> **Bootstrapping the `.env`:** the **[create-env](create-env/SKILL.md)** sub-skill writes a
> `.env` pre-filled with the org-standard values (ASC key/issuer ids, web-login Apple ID,
> copyright, review contact) so only the per-project values remain. It contains secrets, so the
> `create-env/` directory is **kept out of git** (local-only) even though the rest of the skill
> is committed. Run `bash create-env/create_env.sh` from a project root.

## The workflow

### 0. Pre-flight code checklist (in the repo)
- ⚠️ **Verify you are targeting the RIGHT app record FIRST.** Before any upload/submit, confirm
  `ASC_BUNDLE_ID` / `ASC_APP_ID` in `.env` point at *this app's own* listing — never an unrelated
  existing app. Run `python3 scripts/asc_submit.py status` and check the returned app **name**
  matches the app you intend to ship. A bundle id / app id left over from a different project will
  silently push your build as a new version of *that* app (e.g. submitting a food-sharing app into
  an unrelated "PotLuckHub" record). Each app gets its **own** reverse-DNS bundle id and its **own**
  ASC app record. If no record exists yet, create one (UI: **+ → New App**; the API cannot create
  apps — `POST /v1/apps` returns 403), then put its numeric id in `ASC_APP_ID`.
- App icon **1024×1024, no alpha** in the asset catalog.
- `CFBundleShortVersionString` (marketing, e.g. `1.0`) and `CFBundleVersion` (build, integer,
  **bump on every upload**).
- `ITSAppUsesNonExemptEncryption = false` in Info.plist (skips the export-compliance prompt)
  — only if you use no non-exempt crypto.
- Usage-description strings for every permission (`NSMicrophoneUsageDescription`, etc.).
- `UIRequiredDeviceCapabilities = arm64` (never the legacy `armv7`).
- **`PrivacyInfo.xcprivacy`** privacy manifest (tracking false, collected types, required-reason APIs).
- For **iPad-only**: `TARGETED_DEVICE_FAMILY = 2`. For iPhone-only: `1`. Universal: `1,2`.
- **Per-config entitlements** if using CloudKit/push: Debug → `aps-environment=development`,
  Release → `production`.

### 1. Archive + upload the build (Xcode CLI)
Replace `<YourApp>.xcodeproj` and scheme `<YourApp>` with your project's names.

> **Optional pattern — XcodeGen.** If you generate the Xcode project with
> [XcodeGen](https://github.com/yonaskolb/XcodeGen) from a `project.yml`, regenerate it first
> (`xcodegen generate`) so version/build/bundle id/device family live in one source of truth,
> and edit `project.yml` instead of the `.pbxproj`. This is entirely optional — a hand-managed
> `.xcodeproj` works the same way for everything below.

```bash
# xcodegen generate          # only if you use XcodeGen (produces <YourApp>.xcodeproj)
xcodebuild -project <YourApp>.xcodeproj -scheme <YourApp> -configuration Release \
  -archivePath /tmp/<YourApp>.xcarchive archive
xcodebuild -exportArchive -archivePath /tmp/<YourApp>.xcarchive \
  -exportPath /tmp/export -exportOptionsPlist ExportOptions.plist   # method: app-store
xcrun altool --validate-app -f /tmp/export/<YourApp>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app   -f /tmp/export/<YourApp>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```
`altool` reads the `.p8` from `~/.appstoreconnect/private_keys/` automatically (the file is
`AuthKey_<ASC_KEY_ID>.p8`). Manual signing: set the **`<DISTRIBUTION_IDENTITY>`** signing
identity (e.g. "Apple Distribution: <Your Name>") and the **`<PROVISIONING_PROFILE>`** profile
in `ExportOptions.plist`. Build processing takes ~5–30 min; poll until state is `VALID`.

### 2. Everything else (ASC API)
Use [scripts/asc_submit.py](scripts/asc_submit.py) — it loads `.env`, mints a JWT via
[scripts/asc_jwt.swift](scripts/asc_jwt.swift), and exposes subcommands:

```bash
python3 scripts/asc_submit.py status                 # app id, version, build, blockers
python3 scripts/asc_submit.py set-metadata           # copyright, privacyPolicyUrl, URLs
python3 scripts/asc_submit.py review-contact         # App Review contact (required)
python3 scripts/asc_submit.py attach-build  --build 2
python3 scripts/asc_submit.py screenshots   --type APP_IPAD_PRO_3GEN_129 a.png b.png
python3 scripts/asc_submit.py submit                 # create review submission + submit
```

### 2b. Set App Availability — ALWAYS, every submission (the easy-to-miss one)
**Pricing and availability are two separate settings.** Setting a price does NOT make the app
available anywhere. If **App Availability** is left empty, an otherwise-perfect build sails
through review, reaches **"Ready for Distribution," and still never appears on the App Store** —
the listing shows **"Removed from App Store."** This bites silently because review passes.

So on **every** submission, before (or right after) submitting, confirm availability is set:

- **Where:** App Store Connect → your app → **Pricing and Availability** → **App Availability**.
- **Do:** click **Set Up Availability** → **All Countries or Regions** → **Next** → **Confirm**.
  Countries flip to **"Processing to Available"** (live on the store within ~24 h).
- **Verify:** the App Availability section should read **"Availability (N Countries or Regions)"**,
  not a bare **"Set Up Availability"** button. A bare button = availability is empty = it will be
  invisible on sale.
- **EU note:** the available count can be **less than the priced count** (e.g. 148 vs 175) until
  you provide **trader status** (Business section, EU Digital Services Act). EU/EEA territories
  stay gated until then — fill trader status if you want EU availability.

This is **UI-only / Playwright** (no `asc_submit.py` subcommand). Drive it via the Playwright
recipe above, or do it by hand — but never skip it.

### 3. Submit for review
`submit` creates a `reviewSubmission`, adds the version as a `reviewSubmissionItem`, then
PATCHes `submitted=true`. On success the version state becomes `WAITING_FOR_REVIEW`. The
command prints any blocker codes returned in `associatedErrors`.

### 3b. Existing app → ship a NEW version (1.0 → 1.1 → 1.2 …)

The **API cannot create an app** (`POST /v1/apps` → 403), but for an app that already exists in
App Store Connect you do **not** create a new app — you create (or repurpose) a new **version**
under the same app record. The developer-controlled **`MARKETING_VERSION`** (project.yml /
`CFBundleShortVersionString`) is the source of truth; reconcile ASC to it:

1. **Bump the marketing version** in the project (e.g. `1.0` → `1.1`) and build with it.
2. **Ensure an App Store version with that string exists and is editable:**
   - If a version with that string exists → reuse it.
   - **If the previous version is already RELEASED** (live on the store) → create the next one:
     `POST /v1/appStoreVersions` with `versionString=1.1` (carry over metadata + screenshots from
     the previous version — a fresh version starts with empty localizations).
   - **If the previous version is still un-released** (`PREPARE_FOR_SUBMISSION` / `WAITING_FOR_REVIEW`
     / `*REJECTED`) → an app **can't hold two un-released versions**, so `POST` 409s. Instead
     **rename the pending version**: `PATCH /v1/appStoreVersions/{id}` `versionString=1.1` (cancel
     any active review first so the string is editable; retry on 409 while the cancel settles).
3. Attach the new build, set **What's New** (only meaningful on an update of an already-released
   app), and submit.

> **"What's New" only applies to updates.** On a first-ever release the field is rejected/ignored.
> Bumping to 1.1 while 1.0 has **never been released** just renames the in-flight version — it does
> not produce a separate "update", so no What's New shows until 1.0 is actually live.

This is automated end-to-end by the **`ios-auto-release`** skill's `scripts/ci_submit.py`
(`next-version` reads `project.yml`; `submit` does the create-or-rename reconciliation above), so
each push to `main` ships the project's current `MARKETING_VERSION`.

> **Before you call this submission done:** re-confirm **App Availability** is set (step 2b).
> "Ready for Distribution" with empty availability = "Removed from App Store." Easiest miss in
> the whole flow.

### 4. CloudKit Production schema deploy (if the app uses CloudKit/SwiftData+CloudKit)
**Not a review blocker, but ships broken sync if skipped.** App Store builds use the
**Production** CloudKit environment; the schema you developed against is in **Development**.
In **CloudKit Console → your container → Schema → Record Types → Deploy Schema Changes…**,
review the Development→Production diff and **Deploy**.
- A record type only exists in the schema **after a record of that type was created** in the
  Development environment. Production **cannot auto-create** new record types. So if a model
  was never exercised in dev (e.g. a rarely-used record type), its type is **absent** and
  that data won't sync until you create one record in a Debug build and **re-deploy**.
- **If your app has no CloudKit** (e.g. data lives on a backend REST API), skip this step.

## Submission blockers cheat-sheet (the 409 `associatedErrors`)

| Blocker code / message | Fix |
|---|---|
| `appInfoLocalizations … privacyPolicyUrl` required | PATCH `appInfoLocalizations/{id}` `privacyPolicyUrl` |
| `appStoreVersions … copyright` required | PATCH `appStoreVersions/{id}` `copyright` (always `YYYY Tertiary Infotech Academy Pte Ltd`, e.g. `2026 Tertiary Infotech Academy Pte Ltd`) |
| `appStoreReviewDetail … was not found` | POST `appStoreReviewDetails` with contact name/phone/email, `demoAccountRequired` |
| `APP_DATA_USAGES_REQUIRED` | **UI-only**: App Privacy → publish "Data Not Collected" (or fill labels) |
| `SCREENSHOT_REQUIRED.APP_IPHONE_65` | See the iPhone-screenshot quirk below |

## Gotchas (the time-savers)

- **iPhone 6.5" screenshot demanded for an iPad-only app.** The API submission validator
  spuriously requires an `APP_IPHONE_65` screenshot even when the binary is `UIDeviceFamily=2`.
  The **web UI** usually won't ask, but the **API** will. Fastest unblock: generate valid
  1242×2688 (or 1284×2778) images and upload them to an `APP_IPHONE_65` set —
  [scripts/make_iphone_screenshot.swift](scripts/make_iphone_screenshot.swift) frames an
  existing iPad capture on a branded gradient so it looks intentional, not letterboxed.
  Harmless for an iPad-only listing (the binary still determines device compatibility).
- **A stale earlier build keeps the app "universal."** If build 1 was uploaded universal
  (before you set `TARGETED_DEVICE_FAMILY=2`) and is still `VALID`, expire it
  (`PATCH /v1/builds/{id}` `expired=true`) so it stops influencing device support.
- **Screenshot upload is a 3-step dance**, not a single PUT: (1) `POST /v1/appScreenshots`
  reserve with `fileSize`+`fileName` → returns `uploadOperations`; (2) PUT the bytes to each
  operation's `url` with its `requestHeaders`; (3) `PATCH /v1/appScreenshots/{id}`
  `uploaded=true` + `sourceFileChecksum` = **MD5 hex** of the file. Then poll
  `assetDeliveryState.state == COMPLETE`.
- **Bundle ID already taken** → pick a namespaced reverse-DNS id you control
  (`com.yourorg.appname`); update the project (and the iCloud container, if any) to match.
- **Device not registered / iCloud container mismatch** when test-installing on hardware →
  register the device UDID in the portal and ensure the iCloud container is created and
  assigned to the App ID.
- **JWT lifetime** ≤ 20 min (`exp = iat + 1200`), `aud = "appstoreconnect-v1"`, ES256.
  Regenerate per script run; don't cache.
- **Empty draft review submissions** created during testing can't be deleted via API (403).
  Ignore them or remove in the UI.
- **Replacing screenshots = DELETE then upload** (the API *appends*). To swap a bad set, first
  `GET /v1/appScreenshotSets/{setid}/appScreenshots`, `DELETE /v1/appScreenshots/{id}` each,
  then run the 3-step upload. Otherwise you end up with 6 screenshots (3 stale + 3 new).
- **Resubmitting a REJECTED version → `STATE_ERROR.ITEM_PART_OF_ANOTHER_SUBMISSION`.** The
  rejected `reviewSubmission` still "holds" the version. Free it with
  `PATCH /v1/reviewSubmissions/{id}` `{"canceled": true}`, then create a fresh submission, add
  the version as a `reviewSubmissionItem`, and `PATCH submitted=true`. A stray *empty*
  submission left over from a failed attempt may 409 on cancel — just **reuse** it (add the
  item + submit it) instead of creating another.
- **Attach a reviewer screen recording via the API** (works even while `WAITING_FOR_REVIEW`):
  3-step like screenshots — `POST /v1/appStoreReviewAttachments` (attrs `fileName`+`fileSize`,
  relationship → `appStoreReviewDetails/{id}`) → PUT bytes to `uploadOperations` → `PATCH`
  `uploaded=true` + `sourceFileChecksum` (MD5). Poll `assetDeliveryState.state == COMPLETE`.
- **`releaseType: AFTER_APPROVAL`** on the version means **approval auto-publishes** it — no
  manual "Release" click needed. Confirm via `GET appStoreVersions/{id}` before submitting.
- **Build must be `processingState == VALID`** before `attach-build`; list with
  `GET /v1/builds?filter[app]={aid}&sort=-uploadedDate`. Processing takes ~5–15 min after `altool`.
- **Build "UPLOAD SUCCEEDED" but never appears in ASC** (no build after an hour) → almost always a
  **missing top-level `CFBundleIconName`** in the app's Info.plist. `altool --validate-app` passes,
  but ASC processing silently rejects and emails the account. If only the nested
  `CFBundleIcons→CFBundlePrimaryIcon→CFBundleIconName` is present (no top-level key), it fails. Fix:
  add `CFBundleIconName: AppIcon` to Info.plist (XcodeGen: `info.properties`), bump `CFBundleVersion`,
  re-archive + re-upload. Verify pre-upload:
  `/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" Payload/<App>.app/Info.plist`.
- **`90129` "bundle name or display name is already taken"** — the other reason a build uploads then
  shows **Failed** in TestFlight → Build Uploads. `CFBundleDisplayName` (or `CFBundleName`) must be
  **globally unique** on the App Store. If "AppName" is taken, the binary's display name can't be it
  either — set `CFBundleDisplayName` to your unique registered app name (e.g. a branded prefix).
- **Diagnose a vanished build via the UI, not the API.** A rejected build's `processingState` never
  appears via `/v1/builds` (looks identical to "still processing"). The real error is in **TestFlight
  → Build Uploads** (click the **Failed** status) and emailed to the account.
- **`submit` → `STATE_ERROR.APP_PRICING_REQUIRED`** → set the app's price first (Pricing and
  Availability → Add Pricing → Free/$0.00 → confirm). The `appPriceSchedule` API is fiddly; the UI
  is faster. Re-run `submit` after.

## Screenshot requirements & capture

### Required device sizes (what "meet all the requirements" means)

App Store Connect requires at least **one** screenshot for the largest size of **each device
family the binary supports**. Provide more (up to 10) — only the first 3 show on the install
sheet, but a fuller set reads as a more complete listing and de-risks a 2.3.3 rejection.

| Device | `screenshotDisplayType` | Accepted size (px, portrait) | Capture on |
|---|---|---|---|
| iPhone 6.9" (current primary) | `APP_IPHONE_67` | 1290×2796 **or 1320×2868** | iPhone 16/17 Pro Max |
| iPhone 6.5" (legacy, still accepted) | `APP_IPHONE_65` | 1242×2688 or 1284×2778 | iPhone 11 Pro Max, or `sips`-resize a 6.9" shot |
| iPad 13" / 12.9" | `APP_IPAD_PRO_3GEN_129` | 2064×2752 **or 2048×2732** | iPad Pro 13"/12.9" |

- **iPhone:** one of 6.9"/6.5"/6.7" satisfies the iPhone requirement. **6.9" (`APP_IPHONE_67`)
  is the modern default** — if a listing only has the old 6.5" set, add 6.9". The 6.9" slot
  accepts the iPhone 17 Pro Max native 1320×2868, so no resize is needed there.
- **Universal app (iPhone + iPad):** you need **both** an iPhone set **and** the iPad 13" set.
- A 6.5" set can be produced from a 6.9" capture with `sips -z 2688 1242 in.png` (slot accepts
  the slightly-off aspect; minor, and Apple does not reject for it).

### Capturing real screenshots from the Simulator (no third-party tools)

App Review 2.3.3 requires **real captures of the working app** (not mockups, not splash/login
screens). Capture per device size, then upload (see the screenshot 3-step dance in Gotchas).

```bash
APP=build-sim/Build/Products/Debug-iphonesimulator/<App>.app   # build with -sdk iphonesimulator
UDID=<sim-udid>                                                 # xcrun simctl list devices
xcrun simctl boot "$UDID"; open -a Simulator
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch  "$UDID" <bundle.id>
xcrun simctl io "$UDID" screenshot /tmp/shots/route.png         # capture the current screen
```

The capture resolution equals the device's native points×scale, which already matches the
slot (iPhone 17 Pro Max → 1320×2868; iPad Pro 13" → 2064×2752). Verify with
`sips -g pixelWidth -g pixelHeight file.png`.

### ⚠️ Synthetic taps into the Simulator are unreliable — design around it

Driving the app to different screens with synthetic mouse clicks (`cliclick`, AppleScript
`click at`, CGEvent) is **flaky in this environment**: the mouse moves to the right point
(`cliclick m:x,y p:.` confirms the coordinate) but the click frequently is **not delivered as
a touch**, so the tab/button doesn't activate. Causes seen: macOS Accessibility permission for
the controlling process, the click being consumed for window focus, the bottom tab-bar sitting
under the **Dock** or in the home-indicator gesture zone, and **two overlapping Simulator
windows** (clicks hit the front one — shut down all but the target device). Budget little time
on it; if a tap doesn't register after one focus-click + one real click, switch tactics:

- **Prefer no-tap variety.** Capture genuinely different-looking screens without any tap:
  - **Dark mode:** `xcrun simctl ui "$UDID" appearance dark`, relaunch, capture — a second,
    visually distinct screenshot of the same screen. (`appearance light` to revert.)
  - **Different default state / launch arguments** if the app exposes them.
  - The app's **launch screen** is already a distinct state for the *first* screen only.
- **If you must navigate:** shut down every other simulator first
  (`xcrun simctl shutdown <other-udid>`) so only one window exists; move the window clear of the
  Dock (`set position of window 1 to {x, 40}`); re-read geometry each time
  (`osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1'`);
  do **one focus click in empty space, then the real tap**; allow ~28 pt for the title bar on
  mid/top taps. Bottom tab taps are the least reliable. Verify every nav step by re-screenshotting.
- **Most robust of all:** drive the UI with an **XCUITest** target (`xcodebuild test`) that taps
  by accessibility id and calls `XCUIScreen.main.screenshot()` — deterministic, no mouse. Use
  this when you need many navigated screens reliably.

Only the **first 3** screenshots per set appear on the install sheet, so lead with the
main-feature screens.

## Per-project template

Fill these per app — keep credentials/URLs/contact in the project's gitignored `.env` and a
short note in the repo (signing identity + the marketing copy). Replace every `<PLACEHOLDER>`.

```
App name:        <APP_NAME>  (App Store display name, if different)
App ID (ASC):    <APP_ID>            # numeric ASC App ID
Bundle ID:       <BUNDLE_ID>         # reverse-DNS, e.g. com.yourorg.app
iCloud container: <ICLOUD_CONTAINER or "none">
Team ID:         <TEAM_ID>
Platform:        iOS, SwiftUI (universal / iPhone-only / iPad-only)
Category:        <APP_STORE_CATEGORY>
Price:           <PRICE>
Version / Build: 1.0 / 1               # bump CFBundleVersion on every upload
Backend:         <YOUR_API_BASE_URL>   # if the app talks to a backend
Marketing site:  <MARKETING_URL>   Support: <SUPPORT_URL>
Privacy:         <PRIVACY_POLICY_URL>   Delete account: <DELETE_ACCOUNT_URL>
```

> Project-specific notes (fill in for your app):
> - Build system: plain `.xcodeproj`, or **optionally** generated by XcodeGen from `project.yml`
>   (`xcodegen generate` → `<YourApp>.xcodeproj`, scheme/target `<YourApp>`). If using XcodeGen,
>   edit `project.yml`, never the `.pbxproj` directly — it is regenerated.
> - For a **universal app** (iPhone + iPad) you need iPhone screenshot sets `APP_IPHONE_67`
>   (1290×2796) and `APP_IPHONE_65` (1242×2688), plus iPad `APP_IPAD_PRO_3GEN_129`. The iPad
>   build must launch without crashing (see lessons below).
> - **CloudKit**: only relevant if your app uses CloudKit/SwiftData+CloudKit. If data is served
>   from a backend REST API, skip the "CloudKit Production schema deploy" step entirely.
> - If your app has **account creation + login**, an in-app **Delete Account** flow is
>   mandatory (see lessons).
> - Manual signing: identity **`<DISTRIBUTION_IDENTITY>`** + profile **`<PROVISIONING_PROFILE>`**.
>   ASC automation key: Key ID **`<ASC_KEY_ID>`**, Issuer **`<ASC_ISSUER_ID>`**,
>   p8 at `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`.
> - Demo/review account: **`<REVIEW_ACCOUNT_EMAIL>` / `<REVIEW_ACCOUNT_PASSWORD>`** — must exist
>   and log in on the live backend before every submission.
> - App Privacy: declare the data your app actually collects (e.g. account email/name,
>   user-generated content) and whether it is used for tracking; review against real backend behavior.

Marketing copy to paste into the version localization (subtitle ≤30 chars, keywords ≤100
chars CSV, promo text ≤170 chars, description ≤4000 chars):

```
Subtitle:    <SUBTITLE, ≤30 chars>
Keywords:    <comma,separated,keywords ≤100 chars total>
Promo text:  <PROMO TEXT, ≤170 chars>
Description: <DESCRIPTION, ≤4000 chars — explain what the app does and its main features>
```

## Lessons learned / rejection checklist (field-tested)

These items each map to a **real App Review rejection** on a shipping app. They are written
generically — they apply to any app with the matching characteristics. Run this checklist
**before every `submit`**.

### Guideline 2.3.3 — Accurate Metadata (screenshots)

A submission was rejected with "the 6.5-inch iPhone screenshots do not show the current
version of the app in use."
- [ ] Every App Store screenshot is a **real capture of the actual current app's working
      screens** (your home / list / detail / main-feature views), taken from the simulator or a device.
- [ ] **Never** reuse another store's assets (e.g. Google Play graphics), marketing mockups, or
      promotional graphics as screenshots — materials that don't reflect the real app UI are not acceptable.
- [ ] **No splash screens, no login screens, and no marketing-only graphics** in the screenshot
      set — Apple does not count these as "the app in use."
- [ ] The **majority** of screenshots show the app's **main features/functionality**.
- [ ] Re-capture for **every** display size you upload (`APP_IPHONE_67`, `APP_IPHONE_65`,
      `APP_IPAD_PRO_3GEN_129`) — don't let a stale set ship.

### Guideline 5.1.1(v) — Data Collection and Storage (account deletion)

A submission was rejected with "the app supports account creation but does not include an
option to initiate account deletion." **Any app with login/registration must ship account deletion.**
- [ ] Ship a **working in-app Delete Account flow** (e.g. Profile → confirmation → backend
      `DELETE` request → sign out) **before** submitting.
- [ ] Temporary deactivate/disable is **not** sufficient; it must actually delete the account.
- [ ] If a website is needed to finish deletion, **deep-link directly** to your
      `<DELETE_ACCOUNT_URL>` (not just the homepage). Only highly-regulated apps may require
      email/phone/customer-service to delete — most apps don't qualify.
- [ ] Attach a **screen recording of the deletion flow** in the App Review Notes.

### Guideline 2.1 — App Completeness (demo account)

An earlier submission was rejected because the demo review account **did not exist on the
live backend** / the app crashed on the reviewer's device.
- [ ] Verify **`<REVIEW_ACCOUNT_EMAIL>` / `<REVIEW_ACCOUNT_PASSWORD>`** actually logs in against
      your live backend right before submitting (don't assume).
- [ ] Confirm a **demo/TestFlight build launches without crashing on every device family you
      support** — for a universal app, reviewers test on iPad too.

## Resubmission recipe — clearing "screenshots + account-deletion" (2.3.3 + 5.1.1(v))

The full end-to-end fix, in order. Reuse this for any "screenshots + account-deletion" rejection.

**1. Real screenshots from the Simulator.**
- Build + run for the simulator: `xcodebuild ... -sdk iphonesimulator -destination
  'platform=iOS Simulator,name=<Simulator Device>'`, then `xcrun simctl install booted <App>.app`
  + `xcrun simctl launch booted <BUNDLE_ID>`.
- Capture: `xcrun simctl io booted screenshot out.png` (a 6.9" Pro Max renders 1320×2868).
- Drive between tabs/screens with **`cliclick`** using the Simulator window geometry
  (`osascript ... get {position, size} of window 1`). Map screen-fraction → window point and
  **allow ~28 pt for the title bar** (bottom-of-screen tab taps are insensitive to it; mid-screen
  taps are not). After each shell call the Simulator can lose focus — `activate` + one throwaway
  click before the real tap.
- Resize to the exact slot size with `sips -z <h> <w> in.png --out out.png`
  (e.g. 6.5" = 1284×2778).
- Upload by **deleting the old set first, then the 3-step reserve/PUT/PATCH** (see Gotchas).

**2. In-app account deletion (the 5.1.1(v) fix).**
- Backend: add an authenticated `DELETE /account` (or equivalent) that **deactivates +
  anonymizes** — set `isActive=false`, rewrite the email to a tombstone
  (`deleted+<id>@…`), and null out `passwordHash`/name/phone/avatar/OAuth ids. Keep the row
  (don't hard-delete) so legally-required transaction records stay linkable. The login route
  must already reject inactive accounts so the deleted user **cannot sign back in**.
- App: a clearly-labelled destructive **Delete Account** button on the Profile screen →
  `confirmationDialog` → call the endpoint → `signOut()`. Show progress + error states.
- **Verify the endpoint is actually LIVE before submitting**: register a throwaway account via
  the API, call the delete route with its token (expect 200), then try to log in again (expect
  401). Don't trust "deploy finished" — `curl` the real route.

**3. ⚠️ Deploying the backend can expose LATENT crashes.** Adding a new endpoint may force the
**first rebuild of the API container in months**, which compiles the *current* source and surfaces
bugs that were committed but never deployed (e.g. a stray top-level route handler registered
outside its plugin → `ReferenceError` crash-loop; or ESM `ERR_MODULE_NOT_FOUND` from extensionless
relative imports). Symptoms: container `exited:unhealthy`, "Stopped after reaching restart limit",
site 503 — while the *build* shows green "Success" (**build success ≠ runtime success**). To
diagnose, **reproduce the container's exact start command locally** (read the start command from
your Dockerfile/process config) and read the **runtime** logs, not the build log. Keep the hotfix
minimal; verify the route is live before resubmitting.

**4. The reviewer screen recording (do everything but the typing).**
- **Synthetic keystrokes do NOT enter text into SwiftUI `TextField`s** — `cliclick t:` and
  System Events `keystroke` both silently fail to focus/fill the field. Two reliable options:
  (a) **have a human type** the credentials while you drive everything else, or (b) inject a
  pre-authenticated session. Pre-create a **simple, easy-to-type throwaway account**
  (`<TEST_ACCOUNT>` / short password) so whoever types it isn't fighting a long string — and so
  the real demo account is never deleted in the recording.
- Record: `xcrun simctl io booted recordVideo --codec=h264 --force out.mp4` (runs until SIGINT;
  stop with `pkill -INT -f "simctl io booted recordVideo"` so the file finalizes).
- Trim with `ffmpeg -ss <start> -i out.mp4 -c:v libx264 -crf 23 -pix_fmt yuv420p clip.mp4`;
  sanity-check with a `tile=8x4` contact sheet (remember `tile` only covers `fps×tiles` seconds).
- Attach via the **`appStoreReviewAttachments` API** (works while `WAITING_FOR_REVIEW`).

**5. Submit + auto-publish.** Cancel the old rejected `reviewSubmission`, add the version to a
fresh one, `PATCH submitted=true`. With `releaseType=AFTER_APPROVAL`, **approval publishes it
automatically** — no further action.
