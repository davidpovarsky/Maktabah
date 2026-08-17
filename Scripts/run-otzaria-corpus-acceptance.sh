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

RUNTIME="$(xcrun simctl list runtimes available -j | python3 -c 'import json,sys; r=[x["identifier"] for x in json.load(sys.stdin)["runtimes"] if "iOS" in x["identifier"] and x["isAvailable"]]; print(r[-1])')"
DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; d=[x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if "iPad Pro" in x["name"]]; print(d[-1])')"
UDID="$(xcrun simctl create Maktabah-Otzaria-Corpus-Acceptance "$DEVICE_TYPE" "$RUNTIME")"
cleanup() { xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
APP="${OTZARIA_CORPUS_ACCEPTANCE_APP_PATH:-$ROOT/build/OtzariaCorpusAcceptance/Build/Products/Debug-iphonesimulator/Maktabah.app}"
test -d "$APP"
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" com.Drn.maktabah data)"
cp "$DATABASE" "$CONTAINER/Documents/otzaria-corpus.db"
RESULT="$CONTAINER/Documents/otzaria-corpus-acceptance.json"

SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_DATABASE="$CONTAINER/Documents/otzaria-corpus.db" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_RESULT="$RESULT" \
SIMCTL_CHILD_OTZARIA_CORPUS_ACCEPTANCE_EXPECTED_BOOKS="$EXPECTED" \
  xcrun simctl launch "$UDID" com.Drn.maktabah

for _ in $(seq 1 720); do
  if [ -f "$RESULT" ]; then
    if [ -n "${OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY:-}" ]; then
      cp "$RESULT" "$OTZARIA_CORPUS_ACCEPTANCE_REPORT_COPY"
    fi
    cat "$RESULT"
    python3 -c 'import json,sys; raise SystemExit(0 if json.load(open(sys.argv[1]))["passed"] else 1)' "$RESULT"
    exit $?
  fi
  sleep 5
done

echo "acceptance timed out after 60 minutes; inspect the simulator and Otzaria index log" >&2
exit 1
