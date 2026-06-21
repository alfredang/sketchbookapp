#!/usr/bin/env bash
# create-env — write the Tertiary Infotech Academy App Store Connect .env into a project.
#
# Usage:  bash create_env.sh [target_dir]      # defaults to current dir
#         bash create_env.sh --force [dir]      # overwrite an existing .env
#
# Copies env.sample → <target>/.env (org constants pre-filled), then reminds you to
# replace the per-project <FILL_…> values. Refuses to clobber an existing .env unless
# --force. The written .env is gitignored in every project — keep it untracked.
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then FORCE=1; shift; fi
TARGET="${1:-$PWD}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sample"
DEST="$TARGET/.env"

[[ -f "$SRC" ]] || { echo "env.sample not found next to this script" >&2; exit 1; }
if [[ -e "$DEST" && $FORCE -ne 1 ]]; then
  echo "Refusing to overwrite existing $DEST (use --force)." >&2; exit 1
fi

cp "$SRC" "$DEST"
chmod 600 "$DEST"
echo "Wrote $DEST"

# Safety: make sure the project ignores .env.
if [[ -d "$TARGET/.git" ]] && ! git -C "$TARGET" check-ignore -q .env 2>/dev/null; then
  echo "⚠️  .env is NOT gitignored in this repo — add '.env' to .gitignore before committing." >&2
fi

echo "Now fill the per-project values:"
grep -n "<FILL_" "$DEST" || true
