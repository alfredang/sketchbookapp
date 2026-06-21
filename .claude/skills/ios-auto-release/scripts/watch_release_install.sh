#!/usr/bin/env bash
# Local release watcher: when the tracked branch advances on the remote (a new
# release in the auto-release CI model), build that exact commit in a throwaway
# git worktree and install it on the connected iPhone/iPad. Your working tree is
# never touched (no pull/reset). Cloud CI cannot reach a physical device — this is
# the local companion that does the on-device install.
#
# Run from the project root:  bash scripts/watch_release_install.sh
# Env:  BRANCH (default main)   INTERVAL secs (default 180)
set -uo pipefail

BRANCH="${BRANCH:-main}"
INTERVAL="${INTERVAL:-180}"
ROOT="$(pwd)"
STATE="$ROOT/.git/.last_installed_release"
WORKTREE="${TMPDIR:-/tmp}/$(basename "$ROOT")-release"

echo "[release-watch] watching origin/$BRANCH every ${INTERVAL}s — installs on device on new release"
while true; do
  git -C "$ROOT" fetch origin "$BRANCH" -q 2>/dev/null || { sleep "$INTERVAL"; continue; }
  REMOTE=$(git -C "$ROOT" rev-parse "origin/$BRANCH" 2>/dev/null || echo "")
  LAST=$(cat "$STATE" 2>/dev/null || echo "")
  if [ -n "$REMOTE" ] && [ "$REMOTE" != "$LAST" ]; then
    echo "[release-watch] new release ${REMOTE:0:8} → building + installing"
    git -C "$ROOT" worktree remove --force "$WORKTREE" 2>/dev/null || true
    if git -C "$ROOT" worktree add --detach "$WORKTREE" "$REMOTE" -q; then
      # carry the gitignored .env (ASC keys) into the build worktree
      [ -f "$ROOT/.env" ] && cp "$ROOT/.env" "$WORKTREE/.env"
      if ( cd "$WORKTREE" && bash scripts/install_on_device.sh ); then
        echo "$REMOTE" > "$STATE"
        echo "[release-watch] release ${REMOTE:0:8} installed ✓"
      else
        echo "[release-watch] install failed — will retry next cycle"
      fi
      git -C "$ROOT" worktree remove --force "$WORKTREE" 2>/dev/null || true
    fi
  fi
  sleep "$INTERVAL"
done
