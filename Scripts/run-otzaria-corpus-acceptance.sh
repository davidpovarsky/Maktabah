#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 /absolute/path/to/seforim.db [expected-book-count]" >&2
  exit 64
fi

DATABASE="$1"
EXPECTED="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$DATABASE"
case "$DATABASE" in /*) ;; *) echo "database path must be absolute" >&2; exit 64 ;; esac

cd "$ROOT"
if [ "${OTZARIA_CORPUS_ACCEPTANCE_SKIP_BUILD:-0}" != "1" ]; then
  bash Vendor/OtzariaSearchEngine/build_xcframework.sh
  bash Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh
  xcodebuild build \
    -project Maktabah.xcodeproj \
    -scheme Maktabah-iOS \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath build/OtzariaCorpusAcceptance \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
fi

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
devices = simctl("list", "devices", "available")["devices"]
candidates = []
for runtime, version in runtimes.items():
    for device in devices.get(runtime, []):
        if device.get("isAvailable"):
            iphone_preference = 1 if device.get("name", "").startswith("iPhone") else 0
            candidates.append((version, iphone_preference, device["udid"]))
if not candidates:
    raise SystemExit("No compatible available iOS Simulator device")
print(max(candidates)[2])
PY
)"
echo "Using compatible iOS Simulator $UDID"
cleanup() { xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
APP="${OTZARIA_CORPUS_ACCEPTANCE_APP_PATH:-$ROOT/build/OtzariaCorpusAcceptance/Build/Products/Debug-iphonesimulator/Maktabah.app}"
test -d "$APP"
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" com.Drn.maktabah data)"
cp "$DATABASE" "$CONTAINER/Documents/otzaria-corpus.db"
RESULT="$CONTAINER/Documents/otzaria-corpus-acceptance.json"
STARTED_AT="$(date +%s)"
SAMPLER_PID=""
if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_METRICS_SAMPLES:-}" ]; then
  : > "$OTZARIA_CORPUS_ACCEPTANCE_METRICS_SAMPLES"
  (
    directory_bytes() {
      if [ -d "$1" ]; then
        du -sk "$1" | awk 'NR == 1 { printf "%.0f", $1 * 1024 }'
      else
        printf '0'
      fi
    }
    INDEX_ROOT="$CONTAINER/Library/Application Support/Otzaria/TantivySearchIndex"
    while true; do
      printf '{"epoch":%s,"databaseBytes":%s,"indexRootBytes":%s,"workspaceBytes":%s}\n' \
        "$(date +%s)" \
        "$(stat -f %z "$CONTAINER/Documents/otzaria-corpus.db")" \
        "$(directory_bytes "$INDEX_ROOT")" \
        "$(directory_bytes "$GITHUB_WORKSPACE")" \
        >> "$OTZARIA_CORPUS_ACCEPTANCE_METRICS_SAMPLES"
      sleep 30
    done
  ) &
  SAMPLER_PID="$!"
fi

SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_DATABASE="$CONTAINER/Documents/otzaria-corpus.db" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_RESULT="$RESULT" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_EXPECTED_BOOKS="$EXPECTED" \
  xcrun simctl launch "$UDID" com.Drn.maktabah

WAIT_ROUNDS="${OTZARIA_CORPUS_ACCEPTANCE_WAIT_ROUNDS:-720}"
for _ in $(seq 1 "$WAIT_ROUNDS"); do
  if [ -f "$RESULT" ]; then
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY:-}" ]; then
      cp "$RESULT" "$OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY"
    fi
    if [ -n "$SAMPLER_PID" ]; then kill "$SAMPLER_PID" >/dev/null 2>&1 || true; wait "$SAMPLER_PID" 2>/dev/null || true; fi
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_INDEX_PATH_FILE:-}" ]; then
      INDEX_ROOT="$CONTAINER/Library/Application Support/Otzaria/TantivySearchIndex"
      INDEX_PATH="$(find "$INDEX_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '*.building' ! -name '*.previous' ! -name '*.installing' | head -1)"
      test -n "$INDEX_PATH"
      printf '%s\n' "$INDEX_PATH" > "$OTZARIA_CORPUS_ACCEPTANCE_INDEX_PATH_FILE"
    fi
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_DURATION_FILE:-}" ]; then
      printf '%s\n' "$(( $(date +%s) - STARTED_AT ))" > "$OTZARIA_CORPUS_ACCEPTANCE_DURATION_FILE"
    fi
    cat "$RESULT"
    python3 -c 'import json,sys; raise SystemExit(0 if json.load(open(sys.argv[1]))["passed"] else 1)' "$RESULT"
    exit $?
  fi
  sleep 5
done

echo "acceptance timed out after $((WAIT_ROUNDS * 5 / 60)) minutes; inspect the simulator and Otzaria index log" >&2
exit 1
