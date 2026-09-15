#!/usr/bin/env bash
#
# run-ipad-simulator-acceptance.sh
# End-to-end acceptance runner & screenshot capture for iPad Pro 13-inch
# Tests Otzaria database install/restore, Sefaria, Reader, Torah Inspector,
# Commentators, Search, and captures all UI states across Hebrew & English.
#

if [ "$#" -lt 1 ]; then
  echo "usage: $0 /absolute/path/to/Maktabah.app" >&2
  exit 64
fi

APP="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="$ROOT/build/ipad-acceptance-screenshots"
LOG_DIR="$ROOT/build/logs"
REPORT_DIR="$ROOT/build/logs/reports"
CRASH_DIR="$ROOT/build/logs/crashes"

mkdir -p "$SCREENSHOT_DIR" "$LOG_DIR" "$REPORT_DIR" "$CRASH_DIR"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || echo "com.davidpovarsky.chavrusatext")"
echo "Target app: $APP (bundle: $BUNDLE_ID)"

# 1. Discover iPad Pro 13-inch simulator device type and latest iOS runtime
DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; values=json.load(sys.stdin)["devicetypes"]; print(next(item["identifier"] for item in values if "iPad Pro" in item["name"] and "13-inch" in item["name"]))')"
RUNTIME="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; values=[item for item in json.load(sys.stdin)["runtimes"] if item.get("isAvailable") and item["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]; print(values[-1]["identifier"])')"

echo "Creating iPad Pro 13-inch simulator (Device: $DEVICE_TYPE, Runtime: $RUNTIME)..."
UDID="$(xcrun simctl create 'Maktabah Acceptance iPad' "$DEVICE_TYPE" "$RUNTIME")"

cleanup() {
  echo "Terminating and cleaning up simulator $UDID..."
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Booting simulator $UDID..."
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

echo "Configuring OtzariaDefaultDataProfile in $APP/Info.plist..."
/usr/libexec/PlistBuddy -c 'Set :OtzariaDefaultDataProfile miniTest10' "$APP/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c 'Add :OtzariaDefaultDataProfile string miniTest10' "$APP/Info.plist" 2>/dev/null || true

export SIMCTL_CHILD_OTZARIA_DATA_PROFILE="miniTest10"

echo "Installing $APP on simulator..."
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null || echo "")"
echo "Simulator container data path: $CONTAINER"

capture_screen() {
  local output="$1"
  local lang="$2"
  local locale="$3"
  local wait_seconds="${CAPTURE_WAIT_SECONDS:-10}"
  shift 3
  local extra_args=("$@")

  echo "--> [SCREENSHOT] $output (lang: $lang, locale: $locale, wait: ${wait_seconds}s, args: ${extra_args[*]:-none})"
  SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 -AppleLanguages "($lang)" -AppleLocale "$locale" "${extra_args[@]}" >/dev/null 2>&1 || true
  sleep "$wait_seconds"
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$output" >/dev/null 2>&1 || echo "Warning: failed to capture $output"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
}

# ==============================================================================
# PHASE 1: Bootstrap UI Screenshots (First launch / Setup)
# ==============================================================================
echo ""
echo "=== [PHASE 1: Bootstrap UI Screenshots] ==="
capture_screen "bootstrap-source-en.png" en en_US
capture_screen "bootstrap-source-he.png" he he_IL
capture_screen "bootstrap-error-en.png" en en_US -bootstrapInsufficientSpacePreview
capture_screen "bootstrap-error-he.png" he he_IL -bootstrapInsufficientSpacePreview

# ==============================================================================
# PHASE 2: Otzaria miniTest10 Native Database Bootstrap (Install)
# ==============================================================================
echo ""
echo "=== [PHASE 2: Otzaria miniTest10 Install] ==="
if [ -n "$CONTAINER" ]; then
  INSTALL="$CONTAINER/Documents/miniTest10-install.json"
  RESTORE="$CONTAINER/Documents/miniTest10-restore.json"
  mkdir -p "$CONTAINER/Documents"
  rm -f "$INSTALL" "$RESTORE"

  LAUNCH_INSTALL="$(SIMCTL_CHILD_GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
    SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=install \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_REQUIRE_RESUME=0 \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$INSTALL" \
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 2>&1 || true)"
  echo "Install launched: $LAUNCH_INSTALL"
  INSTALL_PID="$(echo "$LAUNCH_INSTALL" | grep -o '[0-9]\+' | tail -1)"

  waited=0
  while [ "$waited" -lt 180 ]; do
    if [ -s "$INSTALL" ]; then
      echo "Otzaria install report written after ${waited}s"
      cp "$INSTALL" "$REPORT_DIR/miniTest10-bootstrap-install.json"
      cat "$INSTALL"
      break
    fi
    sleep 3
    waited=$((waited + 3))
  done
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  # ==============================================================================
  # PHASE 3: Otzaria miniTest10 Database Restore (Persistence Check)
  # ==============================================================================
  echo ""
  echo "=== [PHASE 3: Otzaria miniTest10 Restore] ==="
  LAUNCH_RESTORE="$(SIMCTL_CHILD_GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" \
    SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE=restore \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH=1 \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RESULT="$RESTORE" \
    SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_PRIOR_REPORT="$INSTALL" \
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 2>&1 || true)"
  echo "Restore launched: $LAUNCH_RESTORE"

  waited=0
  while [ "$waited" -lt 180 ]; do
    if [ -s "$RESTORE" ]; then
      echo "Otzaria restore report written after ${waited}s"
      cp "$RESTORE" "$REPORT_DIR/miniTest10-bootstrap-restore.json"
      cat "$RESTORE"
      break
    fi
    sleep 3
    waited=$((waited + 3))
  done
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  # ==============================================================================
  # PHASE 4: Headless Shared Torah Data Diagnostic Matrix (2x2 + cross return)
  # ==============================================================================
  echo ""
  echo "=== [PHASE 4: Shared Torah Data Diagnostic Runner] ==="
  run_torah_diag() {
    local backend="$1"
    local lang="$2"
    local locale="$3"
    local phase="${4:-}"
    local suffix="${5:-}"
    local report="$CONTAINER/Documents/shared-torah-${backend}-${lang}${suffix}.json"
    rm -f "$report"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

    echo "Running diagnostic: backend=$backend lang=$lang locale=$locale phase=${phase:-none}"
    SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
    SIMCTL_CHILD_SHARED_TORAH_DIAGNOSTIC="$backend" \
    SIMCTL_CHILD_SHARED_TORAH_DIAGNOSTIC_LOCALE="$lang" \
    SIMCTL_CHILD_SHARED_TORAH_DIAGNOSTIC_RESULT="$report" \
    SIMCTL_CHILD_SHARED_TORAH_DIAGNOSTIC_ANNOTATION_PHASE="$phase" \
      xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null 2>&1 || true

    local waited=0
    while [ "$waited" -lt 120 ]; do
      if [ -s "$report" ]; then
        echo "Report ready: $(basename "$report")"
        cp "$report" "$REPORT_DIR/shared-torah-${backend}-${lang}${suffix}.json"
        break
      fi
      sleep 2
      waited=$((waited + 2))
    done
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  }

  run_torah_diag otzaria he he_IL seed-otzaria
  run_torah_diag otzaria en en_US
  run_torah_diag sefaria he he_IL verify-otzaria-seed-sefaria
  run_torah_diag sefaria en en_US
  run_torah_diag otzaria he he_IL verify-sefaria-seed-cleanup -cross-return
fi

# ==============================================================================
# PHASE 5: Otzaria Interactive iPad Pro Screenshots
# ==============================================================================
echo ""
echo "=== [PHASE 5: Otzaria iPad Interactive Screenshots] ==="
xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" activeLibraryBackend.v1 otzaria

capture_screen "otzaria-he-catalog.png" he he_IL -smokeScenario catalog -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-he-reader.png" he he_IL -smokeScenario reader -smokeBackend otzaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "otzaria-he-inspector.png" he he_IL -smokeScenario inspector -smokeBackend otzaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "otzaria-he-commentator.png" he he_IL -smokeScenario commentator -smokeBackend otzaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "otzaria-he-search-results.png" he he_IL -smokeScenario searchResults -smokeBackend otzaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "otzaria-he-search-open.png" he he_IL -smokeScenario searchOpen -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-he-annotations-list.png" he he_IL -smokeScenario annotationsList -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-he-annotations-search.png" he he_IL -smokeScenario annotationsSearch -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-he-annotations-open.png" he he_IL -smokeScenario annotationsOpen -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-he-settings.png" he he_IL -smokeScenario settings -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-to-sefaria-switch.png" he he_IL -smokeScenario engineSwitch -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-en-catalog.png" en en_US -smokeScenario catalog -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-en-reader.png" en en_US -smokeScenario reader -smokeBackend otzaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "otzaria-en-inspector.png" en en_US -smokeScenario inspector -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "otzaria-search.png" he he_IL -smokeScenario search -smokeBackend otzaria -smokeBypassBootstrap

# ==============================================================================
# PHASE 6: Sefaria Interactive iPad Pro Screenshots
# ==============================================================================
echo ""
echo "=== [PHASE 6: Sefaria iPad Interactive Screenshots] ==="
xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" activeLibraryBackend.v1 sefaria

capture_screen "sefaria-he-catalog.png" he he_IL -smokeScenario catalog -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-he-reader.png" he he_IL -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-he-inspector.png" he he_IL -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-he-commentator.png" he he_IL -smokeScenario commentator -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "sefaria-he-search-results.png" he he_IL -smokeScenario searchResults -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "sefaria-he-search-open.png" he he_IL -smokeScenario searchOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-he-annotations-list.png" he he_IL -smokeScenario annotationsList -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-he-annotations-open.png" he he_IL -smokeScenario annotationsOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-to-otzaria-switch.png" he he_IL -smokeScenario engineSwitch -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-en-catalog.png" en en_US -smokeScenario catalog -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-en-reader.png" en en_US -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-en-inspector.png" en en_US -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-search.png" he he_IL -smokeScenario search -smokeBackend sefaria -smokeBypassBootstrap

# ==============================================================================
# PHASE 7: Crash Log Collection & Diagnostic Matrix Output
# ==============================================================================
echo ""
echo "=== [PHASE 7: Diagnostic Collection & Summary] ==="
cp -R ~/Library/Logs/DiagnosticReports/* "$CRASH_DIR/" 2>/dev/null || true

python3 - "$REPORT_DIR" <<'PY'
import json, pathlib, sys

root = pathlib.Path(sys.argv[1])
reports = sorted(root.glob("shared-torah-*.json"))
if not reports:
    print("Notice: No shared-torah diagnostic reports found in", root)
else:
    print("\n" + "="*84)
    print("             SHARED TORAH DATA DIAGNOSTIC MATRIX SUMMARY")
    print("="*84)
    print(f"{'Backend':<9} | {'Locale':<6} | {'Component':<28} | {'Status':<6} | Details")
    print("-" * 84)
    total = 0
    passed_count = 0
    for path in reports:
        try:
            data = json.loads(path.read_text())
            for row in data.get("rows", []):
                total += 1
                p = row.get("passed", False)
                if p:
                    passed_count += 1
                status = "PASS" if p else "FAIL"
                comp = row.get("component", "")[:28]
                err = row.get("error") or row.get("actual", "")
                print(f"{row.get('backend',''):<9} | {row.get('locale',''):<6} | {comp:<28} | {status:<6} | {err[:35]}")
        except Exception as ex:
            print(f"Error reading {path.name}: {ex}")
    print("="*84)
    print(f"Diagnostic Matrix Total: {passed_count}/{total} passed")
    print("="*84 + "\n")
PY

echo ""
echo "=== [CAPTURED SCREENSHOTS] ==="
ls -lh "$SCREENSHOT_DIR"
echo "Total screenshots captured: $(find "$SCREENSHOT_DIR" -name '*.png' -size +10k | wc -l | tr -d ' ')"

echo "iPad Simulator acceptance sequence completed."
exit 0
