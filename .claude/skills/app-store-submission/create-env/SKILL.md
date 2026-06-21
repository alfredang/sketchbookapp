---
name: create-env
description: Sub-skill of app-store-submission. Create a project's App Store Connect submission `.env` pre-filled with the Tertiary Infotech Academy standard values (ASC API key id + issuer id, web-login Apple ID, copyright, review-contact name/phone/email), leaving only the per-project values (bundle id, app id, URLs, demo account) to fill. Use when bootstrapping the `.env` for a new app so the org-wide info is always correct and consistent.
license: MIT
metadata:
  version: "1.0.0"
---

# create-env (App Store Connect `.env` bootstrapper)

A sub-skill of [app-store-submission](../SKILL.md). It drops a correct, consistent `.env`
into any project so you never re-type — or mistype — the org-wide App Store Connect values.

## ⚠️ Sensitive — never commit this sub-skill to GitHub

[env.sample](env.sample) contains the **Apple ID password** and the **ASC key/issuer ids**.
- This whole `create-env/` directory must stay **out of git**. In a project repo, add it to
  `.gitignore` (e.g. `.claude/skills/app-store-submission/create-env/`) — the project copy is
  intentionally local-only even though the rest of `.claude/skills/**` is committed.
- The generated `.env` is already gitignored in every project; keep it untracked.

## What it fills

Org constants (always the same — don't edit per project):

| Key | Value |
|---|---|
| `ASC_KEY_ID` | `YQHNLVGDWK` ("CI Upload" key, App Manager) |
| `ASC_ISSUER_ID` | `f026f849-65f1-4ca4-9d49-1b6764131f40` |
| `ASC_PRIVATE_KEY_PATH` | `~/.appstoreconnect/private_keys/AuthKey_YQHNLVGDWK.p8` |
| `ASC_LOGIN_EMAIL` | `angchewhoe@gmail.com` |
| `ASC_LOGIN_PASSWORD` | (Apple ID password) |
| `ASC_COPYRIGHT` | `YYYY Tertiary Infotech Academy Pte Ltd` |
| `ASC_CONTACT_FIRST` / `_LAST` | `Alfred` / `Ang` |
| `ASC_CONTACT_PHONE` | `+6596983731` |
| `ASC_CONTACT_EMAIL` | `angch@tertiaryinfotech.com` |

Per-project values you must fill (`<FILL_…>` placeholders): `ASC_BUNDLE_ID`, `ASC_APP_ID`,
`ASC_PRIVACY_POLICY_URL`, `ASC_SUPPORT_URL`, `ASC_MARKETING_URL`, and the demo account in
`ASC_REVIEW_NOTES`.

> The `.p8` private key itself is **not** created here — it lives once at
> `~/.appstoreconnect/private_keys/AuthKey_YQHNLVGDWK.p8` and is shared across projects.

## Use

```bash
# from the target project root
bash ~/.claude/skills/app-store-submission/create-env/create_env.sh

# or write into a specific dir / overwrite an existing .env
bash create_env.sh /path/to/project
bash create_env.sh --force .
```

It writes `<target>/.env` (chmod 600), warns if the repo doesn't gitignore `.env`, then lists
the remaining `<FILL_…>` lines. Fill those, then `set -a; source .env; set +a` and run the
[app-store-submission](../SKILL.md) scripts.

## Keeping the values current

If the org login password, ASC key, or contact details change, edit
[env.sample](env.sample) here (both the user-level and project-level copies) so future
projects pick up the corrected info.
