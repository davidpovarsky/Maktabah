#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "usage: $0 /path/Maktabah.app /path/seforim.db /path/manifest.json /path/package-dir [release-base-url] [releases-json]" >&2
  exit 64
fi
APP="$1"
DATABASE="$2"
MANIFEST="$3"
PACKAGE="$4"
RELEASE_BASE_URL="${5:-}"
RELEASES_JSON="${6:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="${OTZARIA_MINI_PROFILE_REPORT_DIR:-${OTZARIA_PREBUILT_REPORT_DIR:-$ROOT/build/logs}}"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || echo "com.davidpovarsky.chavrusatext")"
mkdir -p "$REPORT_DIR"
test -d "$APP"; test -f "$DATABASE"; test -f "$MANIFEST"; test -d "$PACKAGE"

# Select intended stable iOS 18 iPhone simulator
UDID="$(python3 <<'PY'
import json, subprocess, sys

def simctl(*arguments):
    return json.loads(subprocess.check_output(["xcrun", "simctl", *arguments, "-j"]))

runtimes = {}
for r in simctl("list", "runtimes", "available").get("runtimes", []):
    if r.get("isAvailable") and "iOS" in r.get("identifier", ""):
        parts = [int(p) for p in r["version"].split(".") if p.isdigit()]
        runtimes[r["identifier"]] = tuple(parts)

devices_data = simctl("list", "devices", "available").get("devices", {})
candidates = []
for runtime_id, devices in devices_data.items():
    version = runtimes.get(runtime_id)
    if not version:
        continue
    # Priority for iOS 18
    is_ios18 = 1 if (len(version) > 0 and version[0] == 18) else 0
    for d in devices:
        if d.get("isAvailable") and d.get("name", "").startswith("iPhone"):
            candidates.append((is_ios18, version, d.get("name", ""), d["udid"]))

if not candidates:
    raise SystemExit("No available iPhone simulator on a compatible iOS runtime")

candidates.sort(reverse=True)
best = candidates[0]
sys.stderr.write(f"Selected simulator: {best[2]} (iOS {'.'.join(map(str, best[1]))}, UDID: {best[3]})
")
print(best[3])
PY
)"

cleanup() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
cp "$DATABASE" "$CONTAINER/Documents/otzaria-prebuilt.db"
cp "$MANIFEST" "$CONTAINER/Documents/otzaria-search-manifest.json"
if [ -n "$RELEASES_JSON" ]; then
  cp "$RELEASES_JSON" "$CONTAINER/Documents/otzaria-search-releases.json"
fi
mkdir -p "$CONTAINER/Documents/otzaria-search-parts"
if [ -n "$RELEASE_BASE_URL" ]; then
  SEED_VALUES="$(python3 - "$MANIFEST" <<'PY'
import json, sys
manifest=json.load(open(sys.argv[1]))
part=next(part for part in manifest['lexicalArtifact']['parts'] if part['packagedBytes'] > 1048576)
print(manifest['artifactIdentity'])
print(part['assetName'])
print(part['sha256'])
PY
  )"
  SEED_IDENTITY="$(printf '%s\n' "$SEED_VALUES" | sed -n '1p')"
  SEED_ASSET="$(printf '%s\n' "$SEED_VALUES" | sed -n '2p')"
  SEED_SHA="$(printf '%s\n' "$SEED_VALUES" | sed -n '3p')"
  WORKSPACE="$CONTAINER/Library/Caches/Maktabah/Otzaria/SearchDownloads/$SEED_IDENTITY"
  mkdir -p "$WORKSPACE"
  dd if="$PACKAGE/$SEED_ASSET" of="$WORKSPACE/$SEED_SHA.part" bs=1048576 count=1 2>/dev/null
else
  python3 - "$MANIFEST" "$PACKAGE" "$CONTAINER/Documents/otzaria-search-parts" <<'PY'
import json, pathlib, shutil, sys
manifest=json.load(open(sys.argv[1]))
source=pathlib.Path(sys.argv[2]); target=pathlib.Path(sys.argv[3])
for part in manifest['lexicalArtifact']['parts']:
    shutil.copyfile(source / part['assetName'], target / part['assetName'])
PY
fi

print_diagnostics() {
  local phase="$1"
  local pid="$2"
  local report="$3"

  echo "=== [DIAGNOSTICS: otzaria-prebuilt $phase phase] ===" >&2
  echo "Report path: $report" >&2
  if [ -e "$report" ]; then
    echo "Report file exists (size: $(stat -f %z "$report" 2>/dev/null || stat -c %s "$report" 2>/dev/null) bytes):" >&2
    cat "$report" >&2 || true
  else
    echo "Report file DOES NOT EXIST." >&2
  fi

  if [ -n "$pid" ]; then
    if kill -0 "$pid" 2>/dev/null; then
      echo "App process $pid is STILL RUNNING." >&2
    else
      echo "App process $pid is NOT RUNNING (exited or crashed)." >&2
    fi
  fi

  echo "Container path: $CONTAINER" >&2
  if [ -d "$CONTAINER" ]; then
    echo "--- Documents directory contents ---" >&2
    ls -la "$CONTAINER/Documents" 2>/dev/null >&2 || echo "Cannot list Documents" >&2
    echo "--- Application Support directory contents ---" >&2
    find "$CONTAINER/Library/Application Support" -maxdepth 4 -ls 2>/dev/null >&2 || echo "Cannot list Application Support" >&2
  else
    echo "Container directory DOES NOT EXIST: $CONTAINER" >&2
  fi

  echo "--- System DiagnosticReports (crashes) ---" >&2
  local crash_reports
  crash_reports="$(find ~/Library/Logs/DiagnosticReports -maxdepth 2 \( -name '*Maktabah*' -o -name '*chavrusatext*' \) 2>/dev/null || true)"
  if [ -n "$crash_reports" ]; then
    echo "Found crash reports:" >&2
    echo "$crash_reports" >&2
    echo "--- Latest crash report ---" >&2
    latest_crash="$(echo "$crash_reports" | tail -n 1)"
    cat "$latest_crash" | head -n 100 >&2 || true
  else
    echo "No crash reports found in ~/Library/Logs/DiagnosticReports." >&2
  fi

  echo "--- Recent Simulator logs for Maktabah (last 3m) ---" >&2
  xcrun simctl spawn "$UDID" log show \
    --predicate 'processImagePath contains "Maktabah" || senderImagePath contains "Maktabah" || subsystem contains "com.davidpovarsky"' \
    --last 3m --style compact 2>/dev/null | tail -n 150 >&2 || echo "Failed to fetch simctl logs" >&2

  echo "=== [END DIAGNOSTICS] ===" >&2
}

run_phase() {
  local phase="$1"
  local timeout="${2:-180}"
  local result="$CONTAINER/Documents/otzaria-prebuilt-$phase.json"
  rm -f "$result"

  echo "Launching app for prebuilt $phase phase..."
  local launch_out
  launch_out="$(SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_MANIFEST="$CONTAINER/Documents/otzaria-search-manifest.json" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_RELEASES="$CONTAINER/Documents/otzaria-search-releases.json" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_PARTS="$CONTAINER/Documents/otzaria-search-parts" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_DATABASE="$CONTAINER/Documents/otzaria-prebuilt.db" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_RESULT="$result" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_PHASE="$phase" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_RELEASE_BASE_URL="$RELEASE_BASE_URL" \
  SIMCTL_CHILD_OTZARIA_PREBUILT_ACCEPTANCE_GOLDEN_QUERY="${OTZARIA_PREBUILT_ACCEPTANCE_GOLDEN_QUERY:-}" \
    xcrun simctl launch "$UDID" "$BUNDLE_ID")"

  echo "Prebuilt $phase launch output: $launch_out"
  local pid
  pid="$(echo "$launch_out" | grep -o '[0-9]\+' | tail -1)"
  echo "Captured prebuilt $phase PID: ${pid:-unknown}"

  local waited=0
  local interval=3
  while [ "$waited" -lt "$timeout" ]; do
    if [ -s "$result" ]; then
      echo "Prebuilt $phase report ready after ${waited}s: $result"
      cp "$result" "$REPORT_DIR/otzaria-prebuilt-$phase.json"
      cat "$result"
      python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["passed"]' "$result"
      return 0
    fi

    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      echo "::error::App process $pid exited prematurely during prebuilt $phase after ${waited}s without writing $result!" >&2
      print_diagnostics "$phase" "$pid" "$result"
      return 1
    fi

    sleep "$interval"
    waited=$((waited + interval))
  done

  echo "::error::Prebuilt acceptance phase $phase timed out after ${timeout}s waiting for $result!" >&2
  print_diagnostics "$phase" "$pid" "$result"
  return 1
}

run_phase install 180
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
run_phase reopen 180
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
