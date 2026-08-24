#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 /path/Maktabah.app /path/seforim.db /path/manifest.json /path/package-dir" >&2
  exit 64
fi
APP="$1"
DATABASE="$2"
MANIFEST="$3"
PACKAGE="$4"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -d "$APP"; test -f "$DATABASE"; test -f "$MANIFEST"; test -d "$PACKAGE"

UDID="$(python3 <<'PY'
import json, subprocess
data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))
candidates=[]
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime: continue
    for device in devices:
        if device.get('isAvailable'): candidates.append((runtime, device['udid']))
print(sorted(candidates)[-1][1])
PY
)"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" com.Drn.maktabah >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" com.Drn.maktabah data)"
cp "$DATABASE" "$CONTAINER/Documents/otzaria-prebuilt.db"
cp "$MANIFEST" "$CONTAINER/Documents/otzaria-search-manifest.json"
mkdir -p "$CONTAINER/Documents/otzaria-search-parts"
python3 - "$MANIFEST" "$PACKAGE" "$CONTAINER/Documents/otzaria-search-parts" <<'PY'
import json, pathlib, shutil, sys
manifest=json.load(open(sys.argv[1]))
source=pathlib.Path(sys.argv[2]); target=pathlib.Path(sys.argv[3])
for part in manifest['lexicalArtifact']['parts']:
    shutil.copyfile(source / part['assetName'], target / part['assetName'])
PY

run_phase() {
  local phase="$1"
  local result="$CONTAINER/Documents/otzaria-prebuilt-$phase.json"
  rm -f "$result"
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_MANIFEST="$CONTAINER/Documents/otzaria-search-manifest.json" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_PARTS="$CONTAINER/Documents/otzaria-search-parts" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_DATABASE="$CONTAINER/Documents/otzaria-prebuilt.db" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_RESULT="$result" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_PHASE="$phase" \
    xcrun simctl launch "$UDID" com.Drn.maktabah >/dev/null
  for _ in $(seq 1 720); do
    if [ -f "$result" ]; then
      cp "$result" "$ROOT/build/logs/otzaria-prebuilt-$phase.json"
      cat "$result"
      python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["passed"]' "$result"
      return
    fi
    sleep 5
  done
  echo "prebuilt acceptance phase $phase timed out" >&2
  exit 1
}

mkdir -p "$ROOT/build/logs"
run_phase install
xcrun simctl terminate "$UDID" com.Drn.maktabah >/dev/null 2>&1 || true
run_phase reopen
xcrun simctl terminate "$UDID" com.Drn.maktabah >/dev/null 2>&1 || true
