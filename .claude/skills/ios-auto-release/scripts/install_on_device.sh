#!/usr/bin/env bash
# Build a DEVELOPMENT copy of the app and install it on connected iPhones/iPads.
# Run from a project root. Reads ./.env (or already-exported env) for ASC_* so
# Xcode can mint a development provisioning profile non-interactively.
#
# Devices (this project):  AA = iPad (iPad Air 11" M3),  A2 = iPhone (iPhone 16).
# Env / overrides:
#   DEVICES   comma-separated device names to target (default: all connected iPad/iPhone)
#             e.g. DEVICES="AA"  (iPad only) or DEVICES="AA,A2" (both)
#   SCHEME    Xcode scheme        (default: first .xcodeproj basename)
#   PROJECT   path to .xcodeproj  (default: autodetected)
set -uo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
if [ -f project.yml ] && command -v xcodegen >/dev/null 2>&1; then xcodegen generate >/dev/null; fi

PROJECT="${PROJECT:-$(ls -d *.xcodeproj 2>/dev/null | head -1)}"
SCHEME="${SCHEME:-$(basename "${PROJECT%.xcodeproj}")}"
[ -n "$PROJECT" ] || { echo "[install] no .xcodeproj found"; exit 1; }
WANT="${DEVICES:-}"

xcrun devicectl list devices --json-output /tmp/_devs.json >/dev/null 2>&1 || true
# Emit "coredeviceID<TAB>hardwareUDID<TAB>name" per matching connected device.
MATCHES=$(python3 - "$WANT" <<'PY'
import json, sys
want = [w.strip() for w in sys.argv[1].split(',') if w.strip()]
try: d = json.load(open('/tmp/_devs.json'))
except Exception: sys.exit(0)
rows = []
for dev in d.get('result', {}).get('devices', []):
    hw = dev.get('hardwareProperties', {}); pt = hw.get('productType', '')
    if not (pt.startswith('iPad') or pt.startswith('iPhone')): continue
    name = dev.get('deviceProperties', {}).get('name', pt)
    if want and name not in want: continue
    rows.append("\t".join([dev.get('identifier',''), hw.get('udid',''), name]))
print("\n".join(rows))
PY
)
[ -n "$MATCHES" ] || { echo "[install] no matching connected device — skipping"; exit 2; }

AUTH=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  KEYPATH=$(eval echo "${ASC_PRIVATE_KEY_PATH:-~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}")
  AUTH=(-authenticationKeyPath "$KEYPATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

rc=2
while IFS=$'\t' read -r CD HW NAME; do
  [ -n "$HW" ] || continue
  echo "[install] → $NAME ($HW)"
  if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
        -destination "id=$HW" -allowProvisioningUpdates "${AUTH[@]}" \
        -derivedDataPath build/device build >/tmp/_devbuild.log 2>&1; then
    echo "[install]   build failed for $NAME:"; tail -8 /tmp/_devbuild.log; continue
  fi
  APP=$(find build/device/Build/Products/Debug-iphoneos -maxdepth 1 -name '*.app' | head -1)
  [ -n "$APP" ] || { echo "[install]   no .app produced"; continue; }
  BID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null)
  if xcrun devicectl device install app --device "$CD" "$APP" >/dev/null 2>&1; then
    xcrun devicectl device process launch --device "$CD" "$BID" >/dev/null 2>&1 || true
    echo "[install]   installed + launched on $NAME ✓"; rc=0
  else
    echo "[install]   install failed on $NAME (device asleep/unreachable?)"
  fi
done <<< "$MATCHES"
exit $rc
