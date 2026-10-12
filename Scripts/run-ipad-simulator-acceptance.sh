#!/usr/bin/env bash
#
# run-ipad-simulator-acceptance.sh
# End-to-end acceptance runner & screenshot capture for iPad Pro 13-inch
# Tests Otzaria database install/restore, Sefaria, Reader, Torah Inspector,
# Commentators, Search, and captures all UI states across Hebrew & English.
#

set -euo pipefail

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
IPAD_UDID="$UDID"
IPHONE_UDID=""
ACCEPTANCE_COMPLETE=0

cleanup() {
  local exit_code=$?
  if [ "$ACCEPTANCE_COMPLETE" -ne 1 ] && [ "$exit_code" -eq 0 ]; then
    echo "Acceptance exited before reaching the completion sentinel." >&2
    exit_code=1
  fi
  trap - EXIT
  set +e
  for device in "$IPAD_UDID" "$IPHONE_UDID"; do
    [ -n "$device" ] || continue
    echo "Terminating and cleaning up simulator $device..."
    xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl shutdown "$device" >/dev/null 2>&1 || true
    xcrun simctl delete "$device" >/dev/null 2>&1 || true
  done
  exit "$exit_code"
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
if ! /usr/libexec/PlistBuddy -c 'Set :OtzariaDefaultDataProfile miniTest10' "$APP/Info.plist" 2>/dev/null; then
  /usr/libexec/PlistBuddy -c 'Add :OtzariaDefaultDataProfile string miniTest10' "$APP/Info.plist"
fi

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
  local ready_file="${SMOKE_READY_FILE:-}"
  local settle_seconds="${SMOKE_SETTLE_SECONDS:-1}"
  shift 3

  echo "--> [SCREENSHOT] $output (lang: $lang, locale: $locale, wait: ${wait_seconds}s, args: ${*:-none})"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
  if [ -n "$ready_file" ]; then
    rm -f "$ready_file"
  fi
  SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
  SIMCTL_CHILD_MAKTABAH_SMOKE_READY_FILE="$ready_file" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 -AppleLanguages "($lang)" -AppleLocale "$locale" "$@"
  if [ "$CURRENT_ORIENTATION" != "portrait" ]; then
    rotate_simulator "$CURRENT_ORIENTATION"
  fi
  if [ -n "$ready_file" ]; then
    local waited=0
    while [ ! -s "$ready_file" ] && [ "$waited" -lt "$wait_seconds" ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ ! -s "$ready_file" ]; then
      echo "Smoke scenario did not become ready within ${wait_seconds}s: $output" >&2
      xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      return 1
    fi
    if ! grep -qx 'success' "$ready_file"; then
      echo "Smoke scenario reported failure: $output" >&2
      cat "$ready_file" >&2
      xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      return 1
    fi
    sleep "$settle_seconds"
  else
    sleep "$wait_seconds"
  fi
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$output" >/dev/null 2>&1 || echo "Warning: failed to capture $output"
  normalize_screenshot_orientation "$SCREENSHOT_DIR/$output" "$CURRENT_ORIENTATION"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
}

# Launches the real application into a deterministic data state, then drives
# production controls through the simulator accessibility system. Launch args
# may prepare data/navigation, but never press controls or persist notes.
launch_interactive_scenario() {
  local scenario="$1"
  local backend="$2"
  local lang="$3"
  local locale="$4"
  shift 4
  local ready_file="$CONTAINER/Documents/real-ui-${scenario}-${backend}.ready"
  rm -f "$ready_file"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  SIMCTL_CHILD_OTZARIA_DATA_PROFILE=miniTest10 \
  SIMCTL_CHILD_MAKTABAH_SMOKE_READY_FILE="$ready_file" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID" \
    -OtzariaDataProfile miniTest10 \
    -AppleLanguages "($lang)" \
    -AppleLocale "$locale" \
    -smokeScenario "$scenario" \
    -smokeBackend "$backend" \
    -smokeBypassBootstrap \
    "$@" >/dev/null

  local waited=0
  while [ ! -s "$ready_file" ] && [ "$waited" -lt 120 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if [ ! -s "$ready_file" ] || ! grep -qx 'success' "$ready_file"; then
    echo "Interactive scenario failed to reach prepared state: $scenario/$backend" >&2
    [ -f "$ready_file" ] && cat "$ready_file" >&2
    return 1
  fi
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
}

ui_wait_id() {
  local identifier="$1"
  local timeout="${2:-30}"
  idb ui wait "$identifier" --match-key AXUniqueId --timeout "$timeout" --json --udid "$UDID"
}

ui_wait_absent_id() {
  local identifier="$1"
  local timeout="${2:-30}"
  local waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if ! idb ui describe "$identifier" --match-key AXUniqueId --udid "$UDID" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  echo "Accessibility element remained visible after ${timeout}s: $identifier" >&2
  return 1
}

ui_tap_id() {
  local identifier="$1"
  idb ui tap "$identifier" --match-key AXUniqueId --udid "$UDID"
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
}

ui_tap_label() {
  local label="$1"
  idb ui tap "$label" --match-key AXLabel --udid "$UDID"
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
}

ui_set_value_id() {
  local identifier="$1"
  local value="$2"
  idb ui set-value "$identifier" --match-key AXUniqueId --value "$value" --udid "$UDID"
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
}

capture_current_ui() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$name" >/dev/null
  normalize_screenshot_orientation "$SCREENSHOT_DIR/$name" "$CURRENT_ORIENTATION"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key AXValue --key frame \
    --udid "$UDID" > "$REPORT_DIR/${name%.png}-accessibility.json"
}

run_real_search_preview() {
  echo "--> [REAL UI] Search result row expansion"
  launch_interactive_scenario searchPreview sefaria he he_IL
  ui_wait_id search-result-preview-toggle- 45
  idb ui describe search-result-preview-toggle- \
    --match-key AXUniqueId --key AXUniqueId --key frame --udid "$UDID" \
    > "$REPORT_DIR/search-result-row-before.json"
  ui_tap_id search-result-preview-toggle-
  ui_wait_id search-result-expanded-preview- 45
  idb ui describe search-result-expanded-preview- \
    --match-key AXUniqueId --key AXUniqueId --key frame --udid "$UDID" \
    > "$REPORT_DIR/search-result-preview-expanded.json"
  capture_current_ui fixed-real-sefaria-search-preview.png
  python3 - \
    "$REPORT_DIR/search-result-row-before.json" \
    "$REPORT_DIR/search-result-preview-expanded.json" \
    "$REPORT_DIR/fixed-real-sefaria-search-preview-accessibility.json" <<'PY'
import json, sys
def item(path):
    value = json.load(open(path))
    if isinstance(value, dict) and 'elements' in value: value = value['elements']
    if isinstance(value, list): value = value[0]
    return value
row, preview = item(sys.argv[1]), item(sys.argv[2])
rw = float(row['frame']['width'])
pw = float(preview['frame']['width'])
assert pw >= rw * 0.90, (rw, pw)
tree = json.load(open(sys.argv[3]))
tree = tree if isinstance(tree, list) else [tree]
labels = [str(x.get('AXLabel','')) for x in tree]
assert any(any('\u0590' <= c <= '\u05ff' for c in label) for label in labels), labels
assert any(sum('a' <= c.lower() <= 'z' for c in label) >= 40 for label in labels), labels
print(json.dumps({'rowWidth': rw, 'previewWidth': pw, 'ratio': pw / rw, 'bilingual': True}))
PY
}

capture_split_frames() {
  local name="$1"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key frame \
    --udid "$UDID" > "$REPORT_DIR/$name.json"
  capture_current_ui "$name.png"
}

run_split_geometry_flow() {
  echo "--> [REAL UI] Native all/double/detail split geometry"
  launch_interactive_scenario reader sefaria en en_US
  ui_wait_id library-column 45
  ui_wait_id toc-column 30
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-all-en

  launch_interactive_scenario reader sefaria he he_IL
  ui_wait_id library-column 45
  ui_wait_id toc-column 30
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-all-he

  launch_interactive_scenario readerDetail sefaria en en_US
  ui_wait_id reader-more-menu 45
  ui_tap_id reader-more-menu
  idb ui wait "Table of Contents" --match-key AXLabel --timeout 30 --json --udid "$UDID"
  ui_tap_label "Table of Contents"
  ui_wait_id toc-column 30
  capture_split_frames fixed-split-double-en
  ui_tap_id toc-close
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-detail-en

  python3 - "$REPORT_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
def elements(name):
    value = json.loads((root / f'{name}.json').read_text())
    return value if isinstance(value, list) else [value]
def frame(name, marker):
    matches = [x for x in elements(name) if marker in str(x.get('AXUniqueId', ''))]
    visible = [x['frame'] for x in matches if x.get('frame', {}).get('width', 0) > 1]
    assert len(visible) == 1, (name, marker, visible)
    return visible[0]
en = [frame('fixed-split-all-en', x) for x in ('library-column','toc-column','reader-detail-column')]
he = [frame('fixed-split-all-he', x) for x in ('library-column','toc-column','reader-detail-column')]
assert en[0]['x'] < en[1]['x'] < en[2]['x'], en
assert he[0]['x'] > he[1]['x'] > he[2]['x'], he
double = [frame('fixed-split-double-en', x) for x in ('toc-column','reader-detail-column')]
assert double[0]['x'] < double[1]['x'], double
detail = frame('fixed-split-detail-en', 'reader-detail-column')
assert detail['width'] > double[1]['width'], (detail, double[1])
print(json.dumps({'allEnglish': en, 'allHebrew': he, 'doubleEnglish': double, 'detailEnglish': detail}))
PY
}

run_panel_geometry_and_scroll_flow() {
  echo "--> [REAL UI] Study side, floating mode, and viewport anchoring"
  launch_interactive_scenario studyCommentaries sefaria he he_IL
  ui_wait_id torah-inspector-panel 45
  ui_wait_id reader-surface 30
  capture_split_frames fixed-study-side-he

  launch_interactive_scenario studyCommentaries sefaria en en_US
  ui_wait_id torah-inspector-panel 45
  ui_wait_id reader-surface 30
  capture_split_frames fixed-study-side-en

  launch_interactive_scenario inspector sefaria en en_US
  ui_wait_id torah-inspector-panel 45
  capture_split_frames fixed-study-floating-half-en

  launch_interactive_scenario readerDetail sefaria en en_US
  ui_wait_id reader-text 45
  for _ in 1 2 3 4 5 6; do
    idb ui scroll up reader-text --match-key AXUniqueId --udid "$UDID"
  done
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
  idb ui describe reader-text \
    --match-key AXUniqueId --key AXUniqueId --key help --key frame --udid "$UDID" \
    > "$REPORT_DIR/viewport-before-study-toggles.json"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    ui_tap_id reader-study-toggle
  done
  idb ui describe reader-text \
    --match-key AXUniqueId --key AXUniqueId --key help --key frame --udid "$UDID" \
    > "$REPORT_DIR/viewport-after-study-toggles.json"

  python3 - "$REPORT_DIR" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
def items(name):
    value = json.loads((root / f'{name}.json').read_text())
    return value if isinstance(value, list) else [value]
def frame(name, marker):
    values = [x['frame'] for x in items(name) if marker in str(x.get('AXUniqueId','')) and x.get('frame',{}).get('width',0)>1]
    assert len(values) == 1, (name, marker, values)
    return values[0]
he_reader, he_panel = frame('fixed-study-side-he','reader-surface'), frame('fixed-study-side-he','torah-inspector-panel')
en_reader, en_panel = frame('fixed-study-side-en','reader-surface'), frame('fixed-study-side-en','torah-inspector-panel')
assert he_panel['x'] < he_reader['x'], (he_reader, he_panel)
assert en_panel['x'] > en_reader['x'], (en_reader, en_panel)
selected = frame('fixed-study-side-en','torah-inspector-selected-segment')
tools = frame('fixed-study-side-en','torah-inspector-tools')
assert selected['y'] + selected['height'] <= tools['y'] + 2, (selected, tools)
def one(path):
    value=json.loads(path.read_text())
    if isinstance(value, dict) and 'elements' in value: value=value['elements']
    return value[0] if isinstance(value,list) else value
before, after = one(root/'viewport-before-study-toggles.json'), one(root/'viewport-after-study-toggles.json')
pattern=r'source=(\d+);offset=([-0-9.]+);object=(-?\d+)'
b, a = re.search(pattern, str(before.get('help',''))), re.search(pattern, str(after.get('help','')))
assert b and a, (before, after)
assert b.group(1) == a.group(1), (b.groups(), a.groups())
assert b.group(3) == a.group(3), (b.groups(), a.groups())
assert abs(float(b.group(2)) - float(a.group(2))) <= 4.0, (b.groups(), a.groups())
print(json.dumps({'hebrew': [he_reader,he_panel], 'english':[en_reader,en_panel], 'selectedAboveTools':[selected,tools], 'viewportBefore':b.groups(), 'viewportAfter':a.groups()}))
PY
}

run_source_gesture_flow() {
  echo "--> [REAL UI] Linked-source single tap and double tap"
  launch_interactive_scenario studyLinks sefaria en en_US
  ui_wait_id torah-inspector-source- 45
  idb ui describe torah-inspector-source- \
    --match-key AXUniqueId --key AXUniqueId --key AXLabel --key frame --udid "$UDID" \
    > "$REPORT_DIR/source-before-gestures.json"
  IFS='|' read -r source_x source_y source_work < <(python3 - "$REPORT_DIR/source-before-gestures.json" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value=value['elements']
value=value[0] if isinstance(value,list) else value
identifier=value['AXUniqueId']
work=identifier.split(':', 1)[1].split('|', 1)[0]
f=value['frame']; print(f"{round(f['x']+f['width']/2)}|{round(f['y']+f['height']/2)}|{work}")
PY
  )
  idb ui tap "$source_x" "$source_y" --udid "$UDID"
  ui_wait_id torah-inspector-source-expanded- 45
  capture_current_ui fixed-real-source-single-tap-expanded.png

  idb ui tap "$source_x" "$source_y" --udid "$UDID"
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID"
  idb ui multi-tap "$source_x" "$source_y" --count 2 --pause 0.08 --udid "$UDID"
  ui_wait_absent_id torah-inspector-panel 45
  ui_wait_id reader-header-title 45
  idb ui describe reader-header-title \
    --match-key AXUniqueId --key AXUniqueId --key AXLabel --udid "$UDID" \
    > "$REPORT_DIR/source-double-tap-reader-header.json"
  python3 - "$REPORT_DIR/source-double-tap-reader-header.json" "$source_work" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value=value['elements']
if isinstance(value, list): value=value[0]
assert str(value.get('AXLabel', '')).strip() == sys.argv[2].strip(), (value, sys.argv[2])
PY
  capture_current_ui fixed-real-source-double-tap-reader.png
}

run_real_note_flow() {
  local backend="$1"
  local note="real-ui-${backend}-note"
  local updated="${note}-updated"
  echo "--> [REAL UI] Note add/save/relaunch/edit/delete ($backend)"
  launch_interactive_scenario studyNotes "$backend" en en_US
  ui_wait_id torah-inspector-add-note 45
  ui_tap_id torah-inspector-add-note
  ui_wait_id annotation-note-text 30
  ui_set_value_id annotation-note-text "$note"
  ui_tap_id annotation-save
  idb ui wait "$note" --timeout 30 --json --udid "$UDID"
  capture_current_ui "fixed-real-${backend}-note-saved.png"

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null
  launch_interactive_scenario studyNotes "$backend" en en_US
  idb ui wait "$note" --timeout 45 --json --udid "$UDID"
  capture_current_ui "fixed-real-${backend}-note-relaunch.png"

  ui_tap_label "$note"
  ui_wait_id annotation-note-text 30
  ui_set_value_id annotation-note-text "$updated"
  ui_tap_id annotation-save
  idb ui wait "$updated" --timeout 30 --json --udid "$UDID"
  ui_tap_label "$updated"
  ui_wait_id annotation-delete 30
  ui_tap_id annotation-delete
  ui_wait_id torah-inspector-add-note 30
  if idb ui describe "$updated" --match-key AXLabel --udid "$UDID" >/dev/null 2>&1; then
    echo "Deleted note is still exposed in the inspector: $backend" >&2
    return 1
  fi
  capture_current_ui "fixed-real-${backend}-note-deleted.png"
}

run_invalid_note_save_flow() {
  local value="text-must-survive-validation-error"
  echo "--> [REAL UI] Invalid/stale note save preserves editor text"
  launch_interactive_scenario studyNotes sefaria en en_US -smokeInvalidateNoteOnSave
  ui_wait_id torah-inspector-add-note 45
  ui_tap_id torah-inspector-add-note
  ui_wait_id annotation-note-text 30
  ui_set_value_id annotation-note-text "$value"
  ui_tap_id annotation-save
  idb ui wait "Could Not Save Annotation" --timeout 30 --json --udid "$UDID"
  idb ui tap OK --udid "$UDID"
  ui_wait_id annotation-note-text 10
  idb ui describe annotation-note-text \
    --match-key AXUniqueId --key AXValue --key AXUniqueId --udid "$UDID" \
    > "$REPORT_DIR/invalid-note-preserved-text.json"
  python3 - "$REPORT_DIR/invalid-note-preserved-text.json" "$value" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value = value['elements']
if isinstance(value, list): value = value[0]
assert sys.argv[2] in str(value.get('AXValue', '')), value
PY
  capture_current_ui fixed-real-invalid-note-editor-preserved.png
  ui_tap_id annotation-cancel
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
xcrun simctl launch "$UDID" "$BUNDLE_ID" -OtzariaDataProfile miniTest10 -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap >/dev/null
rotate_simulator landscapeLeft
xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/orientation-probe-landscape.png" >/dev/null
normalize_screenshot_orientation "$SCREENSHOT_DIR/orientation-probe-landscape.png" landscapeLeft
if ! require_screenshot "orientation-probe-landscape.png" landscape; then
  echo "IDB UI orientation probe or screenshot normalization failed." >&2
  exit 1
fi
rotate_simulator portrait
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 1

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
SMOKE_READY_FILE="$CONTAINER/Documents/otzaria-search-results.ready" SMOKE_SETTLE_SECONDS=2 CAPTURE_WAIT_SECONDS=30 capture_screen "otzaria-he-search-results.png" he he_IL -smokeScenario searchResults -smokeBackend otzaria -smokeBypassBootstrap
SMOKE_READY_FILE="$CONTAINER/Documents/otzaria-search-open.ready" SMOKE_SETTLE_SECONDS=8 CAPTURE_WAIT_SECONDS=30 capture_screen "otzaria-he-search-open.png" he he_IL -smokeScenario searchOpen -smokeBackend otzaria -smokeBypassBootstrap
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
SMOKE_READY_FILE="$CONTAINER/Documents/sefaria-search-results.ready" SMOKE_SETTLE_SECONDS=2 CAPTURE_WAIT_SECONDS=120 capture_screen "sefaria-he-search-results.png" he he_IL -smokeScenario searchResults -smokeBackend sefaria -smokeBypassBootstrap
SMOKE_READY_FILE="$CONTAINER/Documents/sefaria-search-preview.ready" SMOKE_SETTLE_SECONDS=5 CAPTURE_WAIT_SECONDS=120 capture_screen "sefaria-he-search-preview.png" he he_IL -smokeScenario searchPreview -smokeBackend sefaria -smokeBypassBootstrap
SMOKE_READY_FILE="$CONTAINER/Documents/sefaria-search-open.ready" SMOKE_SETTLE_SECONDS=8 CAPTURE_WAIT_SECONDS=120 capture_screen "sefaria-he-search-open.png" he he_IL -smokeScenario searchOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-he-annotations-list.png" he he_IL -smokeScenario annotationsList -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-he-annotations-open.png" he he_IL -smokeScenario annotationsOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-to-otzaria-switch.png" he he_IL -smokeScenario engineSwitch -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-en-catalog.png" en en_US -smokeScenario catalog -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-en-reader.png" en en_US -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-en-inspector.png" en en_US -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "sefaria-search.png" he he_IL -smokeScenario search -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "workspace-reader-toc-portrait.png" he he_IL -smokeScenario readerTOC -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-commentaries-portrait.png" he he_IL -smokeScenario studyCommentaries -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-links-portrait.png" he he_IL -smokeScenario studyLinks -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-notes-portrait.png" he he_IL -smokeScenario studyNotes -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-floating-half-portrait.png" he he_IL -smokeScenario studyFloating -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-floating-full-portrait.png" he he_IL -smokeScenario studyFloatingFull -smokeBackend sefaria -smokeBypassBootstrap

# Capture the same full-height tab shell in landscape, including Reader,
# Inspector, and an open search surface. These are required acceptance assets.
set_orientation landscapeLeft
capture_screen "sefaria-he-reader-landscape.png" he he_IL -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "sefaria-he-inspector-landscape.png" he he_IL -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=10 capture_screen "sefaria-he-search-open-landscape.png" he he_IL -smokeScenario searchOpen -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "otzaria-he-reader-landscape.png" he he_IL -smokeScenario reader -smokeBackend otzaria -smokeBypassBootstrap
capture_screen "workspace-reader-toc-landscape.png" he he_IL -smokeScenario readerTOC -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-commentaries-landscape.png" he he_IL -smokeScenario studyCommentaries -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-links-landscape.png" he he_IL -smokeScenario studyLinks -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-study-notes-landscape.png" he he_IL -smokeScenario studyNotes -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-floating-half-landscape.png" he he_IL -smokeScenario studyFloating -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "workspace-floating-full-landscape.png" he he_IL -smokeScenario studyFloatingFull -smokeBackend sefaria -smokeBypassBootstrap
set_orientation portrait

# ==============================================================================
# PHASE 6A: Production UI interaction acceptance (IDB accessibility actions)
# ==============================================================================
echo ""
echo "=== [PHASE 6A: Real UI interactions and geometry] ==="
run_split_geometry_flow
run_panel_geometry_and_scroll_flow
run_source_gesture_flow
run_real_search_preview
run_real_note_flow sefaria
run_real_note_flow otzaria
run_invalid_note_save_flow

# ==============================================================================
# PHASE 6B: Compact iPhone Reader Workspace Screenshots
# ==============================================================================
echo ""
echo "=== [PHASE 6B: Compact iPhone Reader Workspace Screenshots] ==="
xcrun simctl terminate "$IPAD_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
PHONE_DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; values=json.load(sys.stdin)["devicetypes"]; preferred=[item for item in values if item["name"] == "iPhone 17 Pro"]; candidates=preferred or [item for item in values if item["name"].startswith("iPhone") and "Pro" in item["name"]]; print(candidates[0]["identifier"])')"
IPHONE_UDID="$(xcrun simctl create 'Maktabah Acceptance iPhone' "$PHONE_DEVICE_TYPE" "$RUNTIME")"
UDID="$IPHONE_UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" activeLibraryBackend.v1 sefaria
capture_screen "compact-reader.png" he he_IL -smokeScenario reader -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "compact-study-medium.png" he he_IL -smokeScenario inspector -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "compact-study-large.png" he he_IL -smokeScenario studyCompactLarge -smokeBackend sefaria -smokeBypassBootstrap
capture_screen "compact-toc.png" he he_IL -smokeScenario readerTOC -smokeBackend sefaria -smokeBypassBootstrap
CAPTURE_WAIT_SECONDS=15 capture_screen "compact-study-to-toc.png" he he_IL -smokeScenario compactStudyToTOC -smokeBackend sefaria -smokeBypassBootstrap

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
acceptance_failed="$diagnostic_failed"
if ! grep -q 'TabView(selection: \$selectedTab)' "$ROOT/Source/iOS/Views/iPadLayout.swift"; then
  echo "The iPad root must use the native TabView layout container" >&2
  acceptance_failed=1
fi
if grep -q 'MaktabahTopTabSelector\|Picker(.*segmented' "$ROOT/Source/iOS/Views/iPadLayout.swift"; then
  echo "The obsolete segmented app-tab selector is still present" >&2
  acceptance_failed=1
fi
require_screenshot "sefaria-he-reader.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-inspector.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-search-results.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-search-preview.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-search-open.png" portrait || acceptance_failed=1
require_screenshot "sefaria-he-reader-landscape.png" landscape || acceptance_failed=1
require_screenshot "sefaria-he-inspector-landscape.png" landscape || acceptance_failed=1
require_screenshot "sefaria-he-search-open-landscape.png" landscape || acceptance_failed=1
require_screenshot "otzaria-he-reader-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-reader-toc-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-study-commentaries-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-study-links-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-study-notes-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-floating-half-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-floating-full-portrait.png" portrait || acceptance_failed=1
require_screenshot "workspace-reader-toc-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-study-commentaries-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-study-links-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-study-notes-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-floating-half-landscape.png" landscape || acceptance_failed=1
require_screenshot "workspace-floating-full-landscape.png" landscape || acceptance_failed=1
require_screenshot "compact-reader.png" portrait || acceptance_failed=1
require_screenshot "compact-study-medium.png" portrait || acceptance_failed=1
require_screenshot "compact-study-large.png" portrait || acceptance_failed=1
require_screenshot "compact-toc.png" portrait || acceptance_failed=1
require_screenshot "compact-study-to-toc.png" portrait || acceptance_failed=1

if [ "$acceptance_failed" -ne 0 ]; then
  echo "iPad Simulator acceptance failed." >&2
  exit 1
fi

echo "iPad Simulator acceptance sequence completed."
ACCEPTANCE_COMPLETE=1
exit 0
