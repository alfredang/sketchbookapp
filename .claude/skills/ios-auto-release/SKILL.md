---
name: ios-auto-release
description: Set up CI/CD that auto-builds, signs, uploads, and submits a native iOS/iPadOS app to App Store Connect on every push to main (GitHub Actions on macOS). Use when a user wants automated App Store releases / "auto submit a build on push" / a release pipeline for an Xcode app. Reuses the App Store Connect API key as the upload+submit token; handles signing assets as GitHub secrets, the iOS-26-SDK requirement, and the review-submission race.
license: MIT
metadata:
  version: "1.0.0"
---

# iOS auto-release CI/CD (GitHub Actions)

Make every push to `main` build, sign, upload, and **submit for review** automatically.
The runner is **macOS** (Xcode is required to archive iOS apps). Auth for upload + submit is
the existing **App Store Connect API key** — no new token is needed (though a dedicated CI key
is good hygiene: *Users and Access → Integrations → App Store Connect API → +*).

> The app record must already exist on App Store Connect (the API cannot create apps). Use the
> `app-store-submission` skill for the first manual submission; this skill automates the rest.

## What it does each push

1. Selects **Xcode 26+** (App Store now rejects builds made with an older SDK).
2. Imports the **distribution certificate** (`.p12`) + **App Store provisioning profile** from secrets.
3. Computes the version + a unique build number, archives, exports (manual signing), uploads via `altool`.
4. Waits for processing, then submits for review, **reusing the in-review version or creating the next one**
   (carrying metadata + screenshots) — see `ci_submit.py`.

## Files to drop into the target repo

- `.github/workflows/ios-release.yml`  ← from `templates/ios-release.yml` (edit the `env:` block)
- `scripts/ci_submit.py`               ← from `scripts/ci_submit.py` (generic; no edits needed)
- `ci/screenshots/APP_IPHONE_67/*.png` ← 1–3 real 6.9" screenshots, used when a *new* version is created

Edit the workflow's `env:` to your app: `ASC_BUNDLE_ID`, `TEAM_ID`, and (in the archive step)
the scheme, `PROVISIONING_PROFILE_SPECIFIER`, and `CODE_SIGN_IDENTITY` (usually `Apple Distribution`).

## Gather the secrets (one-time)

```bash
REPO=<owner>/<repo>
KEYID=<ASC_KEY_ID>; ISSUER=<ASC_ISSUER_ID>           # App Store Connect API key
P8=~/.appstoreconnect/private_keys/AuthKey_$KEYID.p8

# 1) ASC API key (upload + submit token)
gh secret set ASC_KEY_ID    --repo $REPO --body "$KEYID"
gh secret set ASC_ISSUER_ID --repo $REPO --body "$ISSUER"
gh secret set ASC_API_PRIVATE_KEY --repo $REPO < "$P8"

# 2) Distribution certificate (cert + private key) as a password-protected .p12
#    (exports the identities from your login keychain non-interactively)
security export -k ~/Library/Keychains/login.keychain-db -t identities \
  -f pkcs12 -P "ci-temp-pass" -o /tmp/dist.p12
gh secret set DIST_CERT_PASSWORD --repo $REPO --body "ci-temp-pass"
base64 -i /tmp/dist.p12 | gh secret set DIST_CERT_P12_BASE64 --repo $REPO

# 3) App Store provisioning profile (download via ASC API or Xcode; install path below)
PROF="$HOME/Library/MobileDevice/Provisioning Profiles/<YourApp>_App_Store.mobileprovision"
base64 -i "$PROF" | gh secret set PROVISIONING_PROFILE_BASE64 --repo $REPO
```

Then `gh secret list --repo $REPO` should show all six. Trigger with a push or
`gh workflow run ios-release.yml --repo $REPO`.

## Hard-won gotchas (already handled in the templates)

- **iOS 26 SDK required.** App Store Connect rejects uploads built with an older SDK
  (409 "must be built with the iOS 26 SDK or later"). The workflow runs `maxim-lobanov/setup-xcode`
  with `latest-stable`; ensure the runner image actually has Xcode 26 (`macos-15`/`macos-26`).
- **Externally-managed Python on macOS runners.** `pip3 install` fails with PEP 668; use
  `actions/setup-python` (the template does) and `pip install`.
- **Release archive defaults to automatic signing** and fails for iCloud/other entitlements with the
  team wildcard profile. The template forces `CODE_SIGN_STYLE=Manual` + an explicit profile.
- **Build number must be unique & increasing.** The template uses a UTC timestamp `date -u +%y%m%d%H%M`.
- **Marketing version must match the App Store version string** for the build to attach — `ci_submit.py`
  sets both (reuse the editable version, or bump the last component when the latest is released).
- **Review-submission race.** Cancelling the current review is async and keeps "holding" the version,
  so adding it to a new submission 409s. `ci_submit.py` retries, reusing an empty `READY_FOR_REVIEW`
  draft instead of creating duplicates.
- **New versions need metadata + screenshots.** When `ci_submit.py` creates the next version it copies
  the previous version's localization and uploads `ci/screenshots/APP_IPHONE_67/*` (commit real ones).
- **Release notes from `CHANGELOG.md`.** `ci_submit.py` reads the section matching the version being
  submitted (falling back to `[Unreleased]`) and sets the version's **What's New**. It must run while the
  version is editable, so the script cancels the active review first, then sets it, then resubmits. This is a
  no-op on a first release (App Store allows "What's New" only on updates of an already-released app).
- **App Privacy + age rating** are app-level and carry across versions — set once in the UI
  (see the `app-store-submission` skill); CI does not touch them.

## Auto-install on your iPad on each release (local runner)

Cloud CI (GitHub Actions) **cannot reach a physical iPad** — it has no USB/network path to
your device. So on-device install of each release runs **locally on your Mac** (iPad connected,
Developer Mode on, device paired & trusted — see the `ios-install-device` skill).

Two pieces (in `scripts/`):

- **`install_on_device.sh`** — builds a *development* copy of the current checkout and installs +
  launches it on **all connected** iPhones/iPads (matches by `productType`, not the device's name).
  Regenerates the XcodeGen project and uses the `.env` ASC key for `-allowProvisioningUpdates`.
  Restrict to specific devices by **name** with `DEVICES`, e.g. `DEVICES="AA" bash …` (iPad only).
  Run any time: `bash .claude/skills/ios-auto-release/scripts/install_on_device.sh`.

  > **This project's devices:** `AA` = iPad (iPad Air 11" M3), `A2` = iPhone (iPhone 16). By default
  > a release installs on **both**; set `DEVICES="AA,A2"` (or a subset) to be explicit.
- **`watch_release_install.sh`** — polls `origin/<branch>`; when it advances (a new release in this
  CI's push-to-`main` model) it checks that commit out in a **throwaway `git worktree`** and runs the
  installer. **Your working tree is never touched** (no pull/reset/checkout in place); the gitignored
  `.env` is copied into the worktree so signing works.

Run it as a **LaunchAgent** so each release auto-installs at login:

```bash
PLIST=~/Library/LaunchAgents/com.tertiaryinfotech.sketchbook.deviceinstall.plist
sed -e "s#__PROJECT_DIR__#$(pwd)#g" -e "s#__USER__#$USER#g" \
  .claude/skills/ios-auto-release/templates/device-install.plist > "$PLIST"
launchctl load "$PLIST"        # starts now + at every login; logs to /tmp/sketchbook-deviceinstall*.log
launchctl unload "$PLIST"      # stop watching
```

Notes:
- It installs a **development** build (not the App Store binary — those are distribution-signed and
  can't sideload). It tracks the **same source** the release was cut from, so the device matches the release.
- Prefer tag-based releases? Set `BRANCH` to a tag ref or adapt the watcher to `git fetch --tags`.
- The Mac must be awake with the iPad reachable; if the device is offline a cycle is skipped and retried.

## Caution

Auto-submitting **every** push to App Store review is aggressive (Apple dislikes churn). Prefer
gating on a tag or a manual `workflow_dispatch` if the user wants controlled releases — change the
`on:` trigger accordingly. The template submits on push to `main` (with doc/CI paths ignored).
