# App Store Submission Skill

API-first workflow for shipping a native iOS/iPadOS app to the App Store with the App Store
Connect API + Xcode CLI. Captures the full sequence and the non-obvious blockers. Per-project
values (App ID, bundle id, Team ID, signing identity, URLs, demo account) live in a gitignored
`.env` — see `.env.example`.

**Read the "Lessons learned / rejection checklist" section in `SKILL.md` before every submit** —
real-app screenshots (2.3.3), in-app Delete Account for any app with login (5.1.1(v)), and a
working demo account on the live backend (2.1) have each caused a real rejection.

**Reference**: [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)

## Flow

| Step | Tool | Notes |
|------|------|-------|
| 0 | repo | icon 1024 (no alpha), version/build, privacy manifest, entitlements, device family |
| 1 | `xcodebuild archive` + `altool` | archive → export (app-store) → validate → upload; bump build each time |
| 2 | `scripts/asc_submit.py` | metadata, review contact, attach build, screenshots |
| 3 | `scripts/asc_submit.py submit` | create reviewSubmission + submit → `WAITING_FOR_REVIEW` |
| 4 | CloudKit Console (UI) | Deploy schema Development → Production (only if app uses CloudKit) |

## Must be done in the web UI (no public API)
- **Generate the ASC API key once** (Users and Access → Integrations → App Store Connect
  API → Team Keys → +; download the `.p8`, copy Key ID + Issuer ID). Bootstrap only — after
  this the skill drives everything. See SKILL.md prerequisites for the exact clicks.
- **App Privacy** nutrition label → publish (e.g. "Data Not Collected", or fill labels).
- Age rating / content rights declarations.

## Top gotchas
- iPad-only apps still get a spurious `APP_IPHONE_65` screenshot demand from the API
  validator → upload framed 1242×2688 images (`scripts/make_iphone_screenshot.swift`).
- Expire stale universal builds so the app isn't treated as iPhone-capable.
- Screenshot upload = reserve → PUT → commit(MD5); poll for `COMPLETE`.
- CloudKit record types only exist after being created once in Development; Production
  can't auto-create them — exercise every model in a Debug build, then re-deploy.

## Files
- `SKILL.md` — full procedure, blocker cheat-sheet, prerequisites, per-project template, lessons.
- `scripts/asc_jwt.swift` — ES256 JWT from env (`.p8` stays outside the repo).
- `scripts/asc_submit.py` — `status | set-metadata | review-contact | attach-build | screenshots | submit`.
- `scripts/make_iphone_screenshot.swift`, `scripts/make_app_icon.swift` — asset generators (customize colors/branding).

Credentials come from a gitignored `.env` (see `.env.example`); the `.p8` private key
lives at `~/.appstoreconnect/private_keys/` and is never committed.
