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

SIM_RECEIPT="$ROOT/build/artifacts/corpus-simulator-isolation.json"
python3 "$ROOT/Scripts/CI/isolated-ipad-simulator.py" --major 0 --receipt "$SIM_RECEIPT" --out "$ROOT/build/artifacts/corpus-sim-udid.txt"
UDID="$(cat "$ROOT/build/artifacts/corpus-sim-udid.txt")"
cleanup() { python3 "$ROOT/Scripts/CI/isolated-ipad-simulator.py" --cleanup --receipt "$SIM_RECEIPT"; }
trap cleanup EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
APP="${OTZARIA_CORPUS_ACCEPTANCE_APP_PATH:-$ROOT/build/OtzariaCorpusAcceptance/Build/Products/Debug-iphonesimulator/Maktabah.app}"
test -d "$APP"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || echo "com.davidpovarsky.chavrusatext")"
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
SHARED_CONTAINER="$(xcrun simctl get_app_container "$UDID" "group.com.davidpovarsky.itorah" groups 2>/dev/null || true)"
EMBEDDED_PROFILE_ID="$(/usr/libexec/PlistBuddy -c 'Print :OtzariaDefaultDataProfile' "$APP/Info.plist" 2>/dev/null || true)"
case "$EMBEDDED_PROFILE_ID" in
  ""|production|'$('*)
    INDEX_SUBPATH="Otzaria/TantivySearchIndex"
    ;;
  *)
    if [[ ! "$EMBEDDED_PROFILE_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "invalid embedded Otzaria data profile ID: $EMBEDDED_PROFILE_ID" >&2
      exit 1
    fi
    INDEX_SUBPATH="Otzaria/Profiles/$EMBEDDED_PROFILE_ID/otzariaSearch"
    ;;
esac
INDEX_ROOT="$CONTAINER/Library/Application Support/$INDEX_SUBPATH"
SHARED_INDEX_ROOT=""
if [ -n "$SHARED_CONTAINER" ] && [ -d "$SHARED_CONTAINER" ]; then
  SHARED_INDEX_ROOT="$SHARED_CONTAINER/$INDEX_SUBPATH"
fi
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
    while true; do
      SAMPLE_TARGET="$INDEX_ROOT"
      if [ ! -d "$SAMPLE_TARGET" ] && [ -n "$SHARED_INDEX_ROOT" ] && [ -d "$SHARED_INDEX_ROOT" ]; then
        SAMPLE_TARGET="$SHARED_INDEX_ROOT"
      fi
      DATABASE_BYTES="$(stat -f %z "$CONTAINER/Documents/otzaria-corpus.db")"
      INDEX_BYTES="$(directory_bytes "$SAMPLE_TARGET")"
      printf '{"epoch":%s,"databaseBytes":%s,"indexRootBytes":%s,"workspaceBytes":%s}\n' \
        "$(date +%s)" \
        "$DATABASE_BYTES" \
        "$INDEX_BYTES" \
        "$((DATABASE_BYTES + INDEX_BYTES))" \
        >> "$OTZARIA_CORPUS_ACCEPTANCE_METRICS_SAMPLES"
      sleep 30
    done
  ) &
  SAMPLER_PID="$!"
fi

SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_DATABASE="$CONTAINER/Documents/otzaria-corpus.db" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_RESULT="$RESULT" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_EXPECTED_BOOKS="$EXPECTED" \
SIMCTL_CHILD_OTZARIA_SHARED_ROOT_OVERRIDE="$CONTAINER/Library/Application Support" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID"

WAIT_ROUNDS="${OTZARIA_CORPUS_ACCEPTANCE_WAIT_ROUNDS:-720}"
for _ in $(seq 1 "$WAIT_ROUNDS"); do
  if [ -f "$RESULT" ]; then
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["passed"]' "$RESULT"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY:-}" ]; then
      cp "$RESULT" "$OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY"
    fi
    if [ -n "$SAMPLER_PID" ]; then kill "$SAMPLER_PID" >/dev/null 2>&1 || true; wait "$SAMPLER_PID" 2>/dev/null || true; fi
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_INDEX_PATH_FILE:-}" ]; then
      if [ ! -d "$INDEX_ROOT" ] && [ -n "$SHARED_INDEX_ROOT" ] && [ -d "$SHARED_INDEX_ROOT" ]; then
        INDEX_ROOT="$SHARED_INDEX_ROOT"
      fi
      INDEX_PATH="$(find "$INDEX_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '*.building' ! -name '*.previous' ! -name '*.installing' | head -1)"
      test -n "$INDEX_PATH"
      # Packaging runs after this script exits and its owned simulator is deleted.
      # Export closed index files outside the simulator before cleanup.
      EXPORTED_INDEX="$(mktemp -d "$ROOT/build/artifacts/otzaria-corpus-index.XXXXXX")"
      cp -R "$INDEX_PATH/." "$EXPORTED_INDEX/"
      find "$EXPORTED_INDEX" -name ".managed.json" -delete
      printf '%s\n' "$EXPORTED_INDEX" > "$OTZARIA_CORPUS_ACCEPTANCE_INDEX_PATH_FILE"
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
