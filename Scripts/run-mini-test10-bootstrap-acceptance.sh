#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /absolute/path/to/Maktabah.app" >&2
  exit 64
fi

APP="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="${OTZARIA_MINI_PROFILE_REPORT_DIR:-$ROOT/build/logs}"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || echo "com.davidpovarsky.chavrusatext")"
mkdir -p "$REPORT_DIR"

UDID="$(python3 <<'PY'
import json, subprocess
data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))['devices']
items=[d['udid'] for devices in data.values() for d in devices if d.get('isAvailable') and d.get('name','').startswith('iPhone')]
if not items: raise SystemExit('No available iPhone simulator')
print(items[-1])
PY
)"
cleanup() { xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true; xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; }
trap cleanup EXIT
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"

wait_report() {
  local report="$1" waited=0
  while [ "$waited" -lt 1800 ]; do
    test -s "$report" && return 0
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

INSTALL="$CONTAINER/Documents/miniTest10-install.json"
RESTORE="$CONTAINER/Documents/miniTest10-restore.json"
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=install \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_REQUIRE_RESUME=0 \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$INSTALL" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
wait_report "$INSTALL"
cp "$INSTALL" "$REPORT_DIR/miniTest10-bootstrap-install.json"
python3 - "$INSTALL" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); assert r['passed'], r
assert r['bookCount']==10 and r['lineCount']==18195, r
assert r['profileID']=='miniTest10' and r['profileVersion']==2, r
assert r['lexicalReady'] and r['otzariaIndexDocuments']==18195, r
assert r['otzariaSearchResults']>0 and r['zayitSearchResults']>0, r
assert r['zayitArtifactIdentity'], r
assert '/Otzaria/Profiles/miniTest10/database/' in r['finalPath'], r
PY
xcrun simctl terminate "$UDID" "$BUNDLE_ID"

SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=restore \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$RESTORE" \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_PRIOR_REPORT="$INSTALL" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
wait_report "$RESTORE"
cp "$RESTORE" "$REPORT_DIR/miniTest10-bootstrap-restore.json"
python3 - "$RESTORE" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); assert r['passed'] and r['restoreAfterRelaunch'], r
assert r['profileID']=='miniTest10' and r['profileVersion']==2, r
assert r['otzariaIndexDocuments']==18195 and r['otzariaSearchResults']>0, r
assert r['zayitArtifactIdentity'] and r['zayitSearchResults']>0, r
PY
cat "$RESTORE"
