---
name: ios-app-update
description: Ship a NEW version of an already-live iOS/iPadOS app to App Store Connect from the command line (local, controllable — not CI). Use when an app already exists on the App Store and you want to submit the next version (e.g. 1.4 → 1.5): bump the version, archive + sign + upload the build, create the new App Store version, set "What's New", attach the build, and submit for review. Covers the literal-Info.plist version bump, screenshot inheritance, the [skip ci] interaction with an auto-release workflow, and AFTER_APPROVAL auto-publish.
license: MIT
metadata:
  version: "1.0.0"
---

# Update an existing App Store app to a new version (local pipeline)

Submit the **next version** of an app that is **already live** on the App Store, driven
locally from the command line so each step is observable and reversible-until-submit. This
is the "1.4 → 1.5" path. It complements:

- **app-store-submission** — the first-ever submission + the API gotchas reference.
- **ios-auto-release** — the GitHub Actions CI that does this automatically on push to main.

Use this skill when you want to ship a version **now, by hand** (the most common real case:
you just finished features, tested on device, and want to push the update without waiting on
or fighting CI).

## Prerequisites (all already set up for a previously-shipped app)

- **ASC API key** in a gitignored `.env` at the repo root: `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_PRIVATE_KEY_PATH` (the `.p8` lives under `~/.appstoreconnect/private_keys/`), plus
  `ASC_BUNDLE_ID` and `ASC_APP_ID`. Load with `set -a; source .env; set +a`.
- **Apple Distribution identity** in the login keychain
  (`security find-identity -v -p codesigning` shows `Apple Distribution: <Name> (<TEAMID>)`).
- The **App Store provisioning profile** installed (matches `ExportOptions.plist`'s
  `provisioningProfiles` entry for the bundle id).
- **`ExportOptions.plist`** at the repo root with `method = app-store-connect`,
  `signingStyle = manual`, the team id, the distribution cert, and the profile name.
- A **`scripts/ci_submit.py`**-style helper (the ios-auto-release skill installs one): it
  mints the ASC JWT and exposes `next-version`, `wait-build`, and `submit`. The functions
  inside it (`token`, `app_id`, `versions`, `ensure_version`, `attach_build`,
  `submit_for_review`, `set_whats_new`, `changelog_notes`) are reused directly below.

## The version-number rule (the easy mistake)

If the project is **XcodeGen** and `GENERATE_INFOPLIST_FILE = NO` with a hand-written
`Info.plist`, the `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` **build settings do NOT
override literal `Info.plist` values** — only `$(VAR)` placeholders get substituted. So if
`Info.plist` has literal `<string>1.4</string>` / `<string>15</string>`, you must bump
**both** places:

1. `project.yml` → `MARKETING_VERSION: "1.5"` (this is what `ci_submit.py next-version`
   reads — the source of truth for the ASC version string).
2. `App/Info.plist` → `CFBundleShortVersionString = 1.5` **and** `CFBundleVersion = 16`
   (the build number, an integer that must be **greater than the last uploaded build**).

> If `Info.plist` instead uses `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`, bump
> only `project.yml` and pass the build number on the `xcodebuild` line. Check which style
> your plist uses before bumping.

## Pipeline (verified, in order)

```bash
cd <repo-root>
set -a; source .env; set +a

# 1. Bump versions (see the rule above) + add a CHANGELOG section:
#    ## [1.5]
#    - User-facing bullet 1
#    - User-facing bullet 2
#    ci_submit reads the [x.y] block (falling back to [Unreleased]) for "What's New".

# 2. Regenerate the Xcode project (XcodeGen projects only).
xcodegen generate

# 3. Archive (Release, manual signing).
xcodebuild -project <App>.xcodeproj -scheme <App> -configuration Release \
  -archivePath /tmp/<App>.xcarchive \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Apple Distribution: <Name>" \
  "PROVISIONING_PROFILE_SPECIFIER=<Profile Name>" \
  DEVELOPMENT_TEAM=<TEAMID> \
  clean archive

# 4. Sanity-check the embedded version/build/icon BEFORE upload.
APPPL=/tmp/<App>.xcarchive/Products/Applications/<App>.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APPPL"   # 1.5
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APPPL"              # 16
/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons' "$APPPL"               # has CFBundlePrimaryIcon

# 5. Export the IPA.
xcodebuild -exportArchive -archivePath /tmp/<App>.xcarchive \
  -exportPath /tmp/export -exportOptionsPlist ExportOptions.plist

# 6. Validate + upload (altool reads the .p8 from ~/.appstoreconnect/private_keys/).
xcrun altool --validate-app -f /tmp/export/<App>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app   -f /tmp/export/<App>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

# 7. Wait for ASC to process the build to VALID (~5–15 min).
python3 scripts/ci_submit.py wait-build --build 16

# 8. Create the new version + attach build + submit.
python3 scripts/ci_submit.py submit --version 1.5 --build 16
```

### Step 8 caveat — the placeholder screenshots dir

`ci_submit.py submit` defaults `--screenshots-dir ci/screenshots/APP_IPHONE_67` and, **when
it creates a brand-new version**, uploads every file in that dir. If that dir holds only a
`README.md` (common), it will try to upload the README as a screenshot. Two safe outcomes:

- **Screenshots auto-inherit.** Creating a new `appStoreVersion` via the API **carries the
  previous version's screenshots forward automatically** (verified: a fresh 1.5 already had
  the 1.4 iPad + iPhone sets). So you usually need **no** screenshot upload at all.
- To avoid the README-as-screenshot upload, either point `--screenshots-dir` at a dir with
  real, correctly-sized PNGs, or run the create/submit steps from a small script that calls
  `ensure_version(tok, aid, target, None)` (pass `None` so nothing is uploaded), then
  `attach_build` + `submit_for_review`. If you ever DO need to re-populate screenshots,
  download them from the previous version's `appScreenshots` (`imageAsset.templateUrl` with
  `{w}/{h}/{f}` filled in) and re-upload via the 3-step reserve → PUT → PATCH dance.

### Step 9 — verify

```bash
python3 - <<'PY'
import importlib.util
cs=importlib.util.module_from_spec(importlib.util.spec_from_file_location("cs","scripts/ci_submit.py"))
importlib.util.spec_from_file_location("cs","scripts/ci_submit.py").loader.exec_module(cs)
tok=cs.token(); aid=cs.app_id(tok)
for v in cs.versions(tok, aid):
    a=v["attributes"]
    if a["versionString"]=="1.5":
        print(a["appStoreState"], a.get("releaseType"))
PY
```

Expect `WAITING_FOR_REVIEW` and `AFTER_APPROVAL` (approval auto-publishes — no manual
"Release" click).

## Gotchas specific to shipping an update

- **`[skip ci]` if an auto-release workflow exists.** If the repo has `ios-release.yml`
  (the ios-auto-release pipeline), pushing your version-bump commit to `main` will trigger
  it and try to build + submit **again** (with a different, date-based build number) — a
  duplicate/confusing run. After a manual submit, put **`[skip ci]`** in the commit message
  so the workflow is skipped. (This is why prior release commits carry `[skip ci]`.)
- **Build number must strictly increase.** ASC rejects a `CFBundleVersion` ≤ an existing
  build in the same version train. Bump it every upload.
- **No App Availability worry on an update.** Availability/pricing carry over from the live
  version; you only set availability on a brand-new app (see app-store-submission step 2b).
- **CloudKit Production schema** only needs a re-deploy if this release **added/changed
  `@Model` types or properties**. Pure UI/logic updates need nothing. If you added a model,
  exercise it once in a Debug build, then CloudKit Console → Deploy Schema Changes.
- **What's New only shows for updates.** On an app whose previous version is live, the
  `[x.y]` changelog becomes the visible "What's New". (It's ignored on a first release.)
- **Resubmitting after rejection:** cancel the held `reviewSubmission`
  (`PATCH .../reviewSubmissions/{id}` `{"canceled": true}`), then re-run `submit`.
  `ci_submit.py`'s `submit` already cancels active reviews and retries the 409 races.
- **App Privacy / age rating** are set once in the ASC web UI and persist across versions —
  no per-update action unless your data collection changed.

## Quick reference (one-liner once versions are bumped + CHANGELOG written)

```bash
set -a; source .env; set +a
xcodegen generate
xcodebuild -project <App>.xcodeproj -scheme <App> -configuration Release \
  -archivePath /tmp/<App>.xcarchive CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Apple Distribution: <Name>" \
  "PROVISIONING_PROFILE_SPECIFIER=<Profile>" DEVELOPMENT_TEAM=<TEAMID> clean archive
xcodebuild -exportArchive -archivePath /tmp/<App>.xcarchive \
  -exportPath /tmp/export -exportOptionsPlist ExportOptions.plist
xcrun altool --upload-app -f /tmp/export/<App>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
python3 scripts/ci_submit.py wait-build --build <N>
python3 scripts/ci_submit.py submit --version <X.Y> --build <N>
```
