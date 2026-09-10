#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 /absolute/path/to/Maktabah.app [lexical.db]" >&2
  exit 64
fi

APP="$1"
LEXICAL_DB="${2:-${OTZARIA_LEXICAL_DATABASE_PATH:-}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="${OTZARIA_MINI_PROFILE_REPORT_DIR:-$ROOT/build/logs}"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || echo "com.davidpovarsky.chavrusatext")"
mkdir -p "$REPORT_DIR"

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
sys.stderr.write(f"Selected simulator: {best[2]} (iOS {'.'.join(map(str, best[1]))}, UDID: {best[3]})\n")
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

if [ -n "$LEXICAL_DB" ] && [ -f "$LEXICAL_DB" ]; then
  echo "Seeding verified lexical.db from $LEXICAL_DB into container..."
  python3 - "$LEXICAL_DB" "$CONTAINER" <<'PY'
import datetime, hashlib, json, pathlib, sys
src = pathlib.Path(sys.argv[1])
container = pathlib.Path(sys.argv[2])
dest_dir = container / "Library" / "Application Support" / "Otzaria" / "SearchResources"
dest_dir.mkdir(parents=True, exist_ok=True)
dest_file = dest_dir / "lexical.db"
dest_file.write_bytes(src.read_bytes())
now_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
sha = hashlib.sha256(dest_file.read_bytes()).hexdigest()
marker = {
    "tagName": "v0.3.0",
    "assetID": 458055169,
    "assetURL": "https://github.com/Otzaria/SeforimMagicIndexer/releases/download/v0.3.0/lexical.db",
    "size": dest_file.stat().st_size,
    "sha256": sha,
    "installedAt": now_str,
    "checkedAt": now_str,
}
(dest_dir / "lexical.db.release.json").write_text(json.dumps(marker, indent=2))
print(f"Successfully seeded lexical.db ({dest_file.stat().st_size} bytes, sha256={sha})")
PY
fi

print_diagnostics() {
  local phase="$1"
  local pid="$2"
  local report="$3"

  echo "=== [DIAGNOSTICS: miniTest10 $phase phase] ===" >&2
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
  xcrun simctl spawn "$UDID" log show     --predicate 'processImagePath contains "Maktabah" || senderImagePath contains "Maktabah" || subsystem contains "com.davidpovarsky"'     --last 3m --style compact 2>/dev/null | tail -n 150 >&2 || echo "Failed to fetch simctl logs" >&2

  echo "=== [END DIAGNOSTICS] ===" >&2
}

wait_report() {
  local report="$1"
  local pid="$2"
  local phase="$3"
  local timeout="${4:-180}"
  local waited=0
  local interval=3

  echo "Waiting for $phase report (pid=$pid, timeout=${timeout}s)..."

  while [ "$waited" -lt "$timeout" ]; do
    if [ -s "$report" ]; then
      echo "$phase report ready after ${waited}s: $report"
      return 0
    fi

    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      echo "::error::App process $pid exited prematurely during $phase after ${waited}s without writing $report!" >&2
      print_diagnostics "$phase" "$pid" "$report"
      return 1
    fi

    sleep "$interval"
    waited=$((waited + interval))
  done

  echo "::error::Timed out after ${timeout}s waiting for $phase report at $report!" >&2
  print_diagnostics "$phase" "$pid" "$report"
  return 1
}

INSTALL="$CONTAINER/Documents/miniTest10-install.json"
RESTORE="$CONTAINER/Documents/miniTest10-restore.json"
rm -f "$INSTALL" "$RESTORE"
mkdir -p "$CONTAINER/Documents"

echo "Launching app for install phase..."
LAUNCH_INSTALL="$(SIMCTL_CHILD_GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=install SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_REQUIRE_RESUME=0 SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$INSTALL"   xcrun simctl launch "$UDID" "$BUNDLE_ID")"

echo "Install launch output: $LAUNCH_INSTALL"
INSTALL_PID="$(echo "$LAUNCH_INSTALL" | grep -o '[0-9]\+' | tail -1)"
echo "Captured install PID: ${INSTALL_PID:-unknown}"

wait_report "$INSTALL" "$INSTALL_PID" "install" 180
cp "$INSTALL" "$REPORT_DIR/miniTest10-bootstrap-install.json"
python3 - "$INSTALL" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); assert r['passed'], r
assert r['bookCount']==10 and r['lineCount']==18195, r
assert r['profileID']=='miniTest10' and r['profileVersion']==3, r
assert r['lexicalReady'] and r['otzariaIndexDocuments']==18195, r
assert r['otzariaSearchResults']>0 and r['zayitSearchResults']>0, r
assert r['zayitArtifactIdentity'], r
assert '/Otzaria/Profiles/miniTest10/database/' in r['finalPath'], r
PY
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

echo "Launching app for restore phase..."
LAUNCH_RESTORE="$(SIMCTL_CHILD_GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=restore SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$RESTORE" SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_PRIOR_REPORT="$INSTALL"   xcrun simctl launch "$UDID" "$BUNDLE_ID")"

echo "Restore launch output: $LAUNCH_RESTORE"
RESTORE_PID="$(echo "$LAUNCH_RESTORE" | grep -o '[0-9]\+' | tail -1)"
echo "Captured restore PID: ${RESTORE_PID:-unknown}"

wait_report "$RESTORE" "$RESTORE_PID" "restore" 180
cp "$RESTORE" "$REPORT_DIR/miniTest10-bootstrap-restore.json"
python3 - "$RESTORE" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); assert r['passed'] and r['restoreAfterRelaunch'], r
assert r['profileID']=='miniTest10' and r['profileVersion']==3, r
assert r['otzariaIndexDocuments']==18195 and r['otzariaSearchResults']>0, r
assert r['zayitArtifactIdentity'] and r['zayitSearchResults']>0, r
PY
cat "$RESTORE"
