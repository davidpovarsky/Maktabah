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
command -v idb >/dev/null 2>&1 || {
  echo "IDB is required to rotate the iPad Simulator during acceptance." >&2
  exit 69
}

echo "Configuring OtzariaDefaultDataProfile in $APP/Info.plist..."
/usr/libexec/PlistBuddy -c 'Set :OtzariaDefaultDataProfile miniTest10' "$APP/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c 'Add :OtzariaDefaultDataProfile string miniTest10' "$APP/Info.plist" 2>/dev/null || true

export SIMCTL_CHILD_OTZARIA_DATA_PROFILE="miniTest10"
CURRENT_ORIENTATION="portrait"

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
  if [ "$CURRENT_ORIENTATION" != "portrait" ]; then
    rotate_simulator "$CURRENT_ORIENTATION"
  fi
  sleep "$wait_seconds"
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$output" >/dev/null 2>&1 || echo "Warning: failed to capture $output"
  normalize_screenshot_orientation "$SCREENSHOT_DIR/$output" "$CURRENT_ORIENTATION"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
}

rotate_simulator() {
  local orientation="$1"
  local idb_orientation
  case "$orientation" in
    portrait) idb_orientation="PORTRAIT" ;;
    portraitUpsideDown) idb_orientation="PORTRAIT_UPSIDE_DOWN" ;;
    landscapeLeft) idb_orientation="LANDSCAPE_LEFT" ;;
    landscapeRight) idb_orientation="LANDSCAPE_RIGHT" ;;
    *) echo "Unsupported simulator orientation: $orientation" >&2; return 64 ;;
  esac
  echo "Setting simulator orientation to $orientation"
  idb ui rotate "$idb_orientation" --udid "$UDID" || {
    echo "IDB failed to rotate simulator $UDID to $idb_orientation." >&2
    exit 1
  }
  sleep 2
}

normalize_screenshot_orientation() {
  local path="$1"
  local orientation="$2"
  local degrees
  case "$orientation" in
    portrait) return 0 ;;
    portraitUpsideDown) degrees=180 ;;
    landscapeLeft) degrees=90 ;;
    landscapeRight) degrees=-90 ;;
    *) echo "Unsupported screenshot orientation: $orientation" >&2; return 64 ;;
  esac

  # Xcode 26's headless simctl capture keeps the native portrait framebuffer
  # dimensions after an HID rotation. Rotate the encoded PNG so the artifact
  # matches the interface orientation the app actually rendered.
  local oriented_path="${path%.png}.oriented.png"
  if ! sips -r "$degrees" "$path" --out "$oriented_path" >/dev/null; then
    echo "Failed to normalize screenshot orientation: $path" >&2
    return 1
  fi
  mv "$oriented_path" "$path"
}

set_orientation() {
  CURRENT_ORIENTATION="$1"
  echo "Next captures will use simulator orientation $CURRENT_ORIENTATION"
}

require_screenshot() {
  local name="$1"
  local expected_orientation="$2"
  local path="$SCREENSHOT_DIR/$name"
  if [ ! -s "$path" ] || [ "$(stat -f '%z' "$path")" -le 10000 ]; then
    echo "Missing or empty required screenshot: $name" >&2
    return 1
  fi
  local width height
  width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
  if [ "$expected_orientation" = landscape ] && [ "$width" -le "$height" ]; then
    echo "Expected landscape screenshot but got ${width}x${height}: $name" >&2
    return 1
  fi
  if [ "$expected_orientation" = portrait ] && [ "$height" -le "$width" ]; then
    echo "Expected portrait screenshot but got ${width}x${height}: $name" >&2
    return 1
  fi
  echo "Verified $name (${width}x${height})"
}

echo ""
echo "=== [PHASE 0: Interface Orientation Probe] ==="
SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap >/dev/null 2>&1 || true
rotate_simulator landscapeLeft
xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/orientation-probe-landscape.png" >/dev/null 2>&1 || true
normalize_screenshot_orientation "$SCREENSHOT_DIR/orientation-probe-landscape.png" landscapeLeft
if ! require_screenshot "orientation-probe-landscape.png" landscape; then
  echo "IDB UI orientation probe or screenshot normalization failed." >&2
  exit 1
fi
rotate_simulator portrait
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

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

# Capture the same full-height tab shell in landscape, including Reader,
# Inspector, and an open search surface. These are required acceptance assets.
set_orientation landscapeLeft
capture_screen "sefaria-he-reader-landscape.png" he he_IL -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-he-inspector-landscape.png" he he_IL -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "sefaria-he-search-open-landscape.png" he he_IL -smokeScenario searchOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "otzaria-he-reader-landscape.png" he he_IL -smokeScenario reader -smokeBackend otzaria -smokeBypassBootstrap
set_orientation portrait

# ==============================================================================
# PHASE 7: Crash Log Collection & Diagnostic Matrix Output
# ==============================================================================
echo ""
echo "=== [PHASE 7: Diagnostic Collection & Summary] ==="
cp -R ~/Library/Logs/DiagnosticReports/* "$CRASH_DIR/" 2>/dev/null || true

diagnostic_failed=0
python3 - "$REPORT_DIR" <<'PY' || diagnostic_failed=1
import json, pathlib, sys

root = pathlib.Path(sys.argv[1])
reports = sorted(root.glob("shared-torah-*.json"))
if not reports:
    print("No shared-torah diagnostic reports found in", root, file=sys.stderr)
    raise SystemExit(1)
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
    if passed_count != total:
        raise SystemExit(1)
PY

echo ""
echo "=== [CAPTURED SCREENSHOTS] ==="
ls -lh "$SCREENSHOT_DIR"
echo "Total screenshots captured: $(find "$SCREENSHOT_DIR" -name '*.png' -size +10k | wc -l | tr -d ' ')"

echo ""
echo "=== [IPAD LAYOUT ACCEPTANCE] ==="
if grep -q 'TabView(selection: \$selectedTab)' "$ROOT/Source/iOS/Views/iPadLayout.swift"; then
  echo "The iPad root still uses TabView as its layout container" >&2
  exit 1
fi
acceptance_failed="$diagnostic_failed"
if ! grep -q 'accessibilityIdentifier("MaktabahTopTabSelector")' "$ROOT/Source/iOS/Views/iPadLayout.swift"; then
  echo "Missing the compact iPad top tab selector accessibility identifier" >&2
  acceptance_failed=1
fi
require_screenshot "sefaria-he-reader.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-inspector.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-search-open.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-reader-landscape.png" landscape || acceptance_failed=1
require_screenshot "sefaria-he-inspector-landscape.png" landscape || acceptance_failed=1
require_screenshot "sefaria-he-search-open-landscape.png" landscape || acceptance_failed=1
require_screenshot "otzaria-he-reader-landscape.png" landscape || acceptance_failed=1

if [ "$acceptance_failed" -ne 0 ]; then
  echo "iPad Simulator acceptance failed." >&2
  exit 1
fi

echo "iPad Simulator acceptance sequence completed."
exit 0
