#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 /absolute/path/to/Maktabah.app [--dictionary-only]" >&2
  exit 64
fi

APP="$1"
MODE="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="${OTZARIA_NATIVE_BOOTSTRAP_REPORT_DIR:-$ROOT/build/logs}"
BUNDLE_ID="com.Drn.maktabah"
test -d "$APP"
case "$APP" in /*) ;; *) echo "app path must be absolute" >&2; exit 64 ;; esac
mkdir -p "$REPORT_DIR"

UDID="$(python3 <<'PY'
import json
import subprocess

def simctl(*arguments):
    return json.loads(subprocess.check_output(["xcrun", "simctl", *arguments, "-j"]))

runtimes = {
    runtime["identifier"]: tuple(int(part) for part in runtime["version"].split("."))
    for runtime in simctl("list", "runtimes", "available")["runtimes"]
    if runtime.get("isAvailable") and "iOS" in runtime["identifier"]
}
candidates = []
for runtime, devices in simctl("list", "devices", "available")["devices"].items():
    version = runtimes.get(runtime)
    if version is None:
        continue
    for device in devices:
        if device.get("isAvailable"):
            candidates.append((
                version,
                1 if device.get("name", "").startswith("iPhone") else 0,
                device["udid"],
            ))
if not candidates:
    raise SystemExit("No compatible available iOS Simulator device")
print(max(candidates)[2])
PY
)"
echo "Using compatible iOS Simulator $UDID"

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

wait_for_report() {
  local report="$1"
  local timeout_seconds="$2"
  local waited=0
  while [ "$waited" -lt "$timeout_seconds" ]; do
    if [ -s "$report" ]; then
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "acceptance timed out waiting for $report after ${timeout_seconds}s" >&2
  return 1
}

validate_passed() {
  python3 - "$1" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
if not report.get("passed"):
    raise SystemExit(f"acceptance report failed: {report}")
PY
}

if [ "$MODE" = "--dictionary-only" ]; then
  RESULT="$CONTAINER/Documents/otzaria-dictionary-acceptance.json"
  rm -f "$RESULT"
  SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=dictionary \
  SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$RESULT" \
    xcrun simctl launch "$UDID" "$BUNDLE_ID"
  wait_for_report "$RESULT" 600
  cp "$RESULT" "$REPORT_DIR/otzaria-dictionary-acceptance.json"
  cat "$RESULT"
  validate_passed "$RESULT"
  exit 0
fi

AVAILABLE_KIB="$(df -Pk "$CONTAINER" | awk 'NR==2 {print $4}')"
REQUIRED_KIB=$((22 * 1024 * 1024))
if [ "$AVAILABLE_KIB" -lt "$REQUIRED_KIB" ]; then
  echo "native bootstrap requires at least 22 GiB free; only ${AVAILABLE_KIB} KiB available" >&2
  exit 1
fi

CANCEL_REPORT="$CONTAINER/Documents/otzaria-native-bootstrap-cancel.json"
INSTALL_REPORT="$CONTAINER/Documents/otzaria-native-bootstrap-install.json"
FINAL_REPORT="$CONTAINER/Documents/otzaria-native-bootstrap-acceptance.json"
rm -f "$CANCEL_REPORT" "$INSTALL_REPORT" "$FINAL_REPORT"

cancel_started="$(date +%s)"
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=cancel \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$CANCEL_REPORT" \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_CANCEL_BYTES=67108864 \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
wait_for_report "$CANCEL_REPORT" 1800
validate_passed "$CANCEL_REPORT"
cp "$CANCEL_REPORT" "$REPORT_DIR/otzaria-native-bootstrap-cancel.json"
xcrun simctl terminate "$UDID" "$BUNDLE_ID"
echo "cancel_phase_seconds=$(($(date +%s) - cancel_started))"

install_started="$(date +%s)"
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=install \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$INSTALL_REPORT" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
wait_for_report "$INSTALL_REPORT" 10800
validate_passed "$INSTALL_REPORT"
cp "$INSTALL_REPORT" "$REPORT_DIR/otzaria-native-bootstrap-install.json"
xcrun simctl terminate "$UDID" "$BUNDLE_ID"
echo "install_phase_seconds=$(($(date +%s) - install_started))"

restore_started="$(date +%s)"
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=restore \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$FINAL_REPORT" \
SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_PRIOR_REPORT="$INSTALL_REPORT" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"
wait_for_report "$FINAL_REPORT" 600
cp "$FINAL_REPORT" "$REPORT_DIR/otzaria-native-bootstrap-acceptance.json"
cat "$FINAL_REPORT"
validate_passed "$FINAL_REPORT"
echo "restore_phase_seconds=$(($(date +%s) - restore_started))"
DATABASE_PATH="$CONTAINER/Library/Application Support/Maktabah/Otzaria/seforim.db"
echo "database_path=$DATABASE_PATH"
printf 'database_path=%s\n' "$DATABASE_PATH" > "$REPORT_DIR/otzaria-native-database-path.txt"
