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

capture_screen_with_retry() {
  local output="$1"
  local attempt
  for attempt in 1 2; do
    if capture_screen "$@"; then
      return 0
    fi
    echo "Retrying transient smoke scenario ($attempt/2): $output" >&2
    sleep 5
  done
  echo "Smoke scenario failed after 2 attempts: $output" >&2
  return 1
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
  rm -f "$ready_file" "$ready_file.viewport.json"
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
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
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

ui_describe_id() {
  local identifier="$1"
  local output="$2"
  local attempt temporary
  temporary="${output}.tmp"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    rm -f "$temporary"
    if idb ui describe "$identifier" \
      --match-key AXUniqueId --key AXUniqueId --key AXLabel --key AXValue --key frame \
      --udid "$UDID" > "$temporary" 2>/dev/null \
      && [ -s "$temporary" ]; then
      :
    else
      rm -f "$temporary"
      idb ui describe-all \
        --key AXUniqueId --key AXLabel --key AXValue --key frame \
        --udid "$UDID" > "${temporary}.all" 2>/dev/null || true
      if [ -s "${temporary}.all" ]; then
        python3 - "${temporary}.all" "$identifier" > "$temporary" <<'PY' || rm -f "$temporary"
import json, sys
data = json.load(open(sys.argv[1]))
items = data.get('elements') if isinstance(data, dict) else data
matches = [x for x in (items if isinstance(items, list) else [items])
           if sys.argv[2] in str(x.get('AXUniqueId', ''))
           or sys.argv[2] in str(x.get('AXLabel', ''))]
if matches:
    print(json.dumps(matches))
PY
        rm -f "${temporary}.all"
      fi
    fi
    if [ -s "$temporary" ] \
      && python3 - "$temporary" <<'PY' 2>/dev/null
import json, sys
value=json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value=value['elements']
items=value if isinstance(value,list) else [value]
assert items and any(item.get('AXUniqueId') or item.get('AXLabel') for item in items), items
PY
    then
      mv "$temporary" "$output"
      return 0
    fi
    sleep 1
  done
  rm -f "$temporary"
  echo "Could not describe accessibility identifier after 10 attempts: $identifier" >&2
  return 1
}

ui_tap_id() {
  local identifier="$1"
  local attempt
  local label_fallback=""
  case "$identifier" in
    annotation-save) label_fallback="Save" ;;
    annotation-cancel) label_fallback="Cancel" ;;
  esac
  for attempt in 1 2 3 4 5; do
    if idb ui tap "$identifier" --match-key AXUniqueId --udid "$UDID" 2>/dev/null; then
      idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
      return 0
    fi
    if [ -n "$label_fallback" ] && idb ui tap "$label_fallback" --match-key AXLabel --udid "$UDID" 2>/dev/null; then
      idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
      return 0
    fi
    local coords
    coords="$(python3 - "$UDID" "$identifier" "$label_fallback" "$CURRENT_ORIENTATION" <<'PY' 2>/dev/null || true
import json, subprocess, sys
udid, ident, label_fallback, orientation = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
cmd = ["idb", "ui", "describe-all", "--key", "AXUniqueId", "--key", "AXLabel", "--key", "frame", "--udid", udid]
out = subprocess.check_output(cmd)
data = json.loads(out)
items = data.get('elements') if isinstance(data, dict) else data
items = items if isinstance(items, list) else [items]
matches = [x for x in items
           if (ident in str(x.get('AXUniqueId','')) or (label_fallback and label_fallback in str(x.get('AXLabel',''))))
           and x.get('frame',{}).get('width',0)>1 and x.get('frame',{}).get('height',0)>1]
if matches:
    f = matches[0]['frame']
    x = f['x'] + f['width']/2
    y = f['y'] + f['height']/2
    screen = max((item.get('frame',{}) for item in items), key=lambda c: c.get('width',0)*c.get('height',0))
    if orientation == 'landscapeLeft':
        x, y = y, screen['width'] - x
    elif orientation == 'landscapeRight':
        x, y = screen['height'] - y, x
    elif orientation == 'portraitUpsideDown':
        x, y = screen['width'] - x, screen['height'] - y
    print(f"{round(x)} {round(y)}")
PY
)"
    if [ -n "$coords" ]; then
      read -r cx cy <<< "$coords"
      if idb ui tap "$cx" "$cy" --udid "$UDID" 2>/dev/null; then
        idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
        return 0
      fi
    fi
    sleep 1
  done
  echo "Could not tap accessibility identifier after 5 attempts: $identifier" >&2
  return 1
}

ui_tap_label() {
  local label="$1"
  local attempt
  for attempt in 1 2 3 4 5; do
    if idb ui tap "$label" --match-key AXLabel --udid "$UDID" 2>/dev/null; then
      idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
      return 0
    fi
    local coords
    coords="$(python3 - "$UDID" "$label" "$CURRENT_ORIENTATION" <<'PY' 2>/dev/null || true
import json, subprocess, sys
udid, target, orientation = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = ["idb", "ui", "describe-all", "--key", "AXLabel", "--key", "frame", "--udid", udid]
out = subprocess.check_output(cmd)
data = json.loads(out)
items = data.get('elements') if isinstance(data, dict) else data
items = items if isinstance(items, list) else [items]
matches = [x for x in items if target in str(x.get('AXLabel','')) and x.get('frame',{}).get('width',0)>1 and x.get('frame',{}).get('height',0)>1]
if matches:
    f = matches[0]['frame']
    x = f['x'] + f['width']/2
    y = f['y'] + f['height']/2
    screen = max((item.get('frame',{}) for item in items), key=lambda c: c.get('width',0)*c.get('height',0))
    if orientation == 'landscapeLeft':
        x, y = y, screen['width'] - x
    elif orientation == 'landscapeRight':
        x, y = screen['height'] - y, x
    elif orientation == 'portraitUpsideDown':
        x, y = screen['width'] - x, screen['height'] - y
    print(f"{round(x)} {round(y)}")
PY
)"
    if [ -n "$coords" ]; then
      read -r cx cy <<< "$coords"
      if idb ui tap "$cx" "$cy" --udid "$UDID" 2>/dev/null; then
        idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
        return 0
      fi
    fi
    sleep 1
  done
  echo "Could not tap accessibility label after 5 attempts: $label" >&2
  return 1
}

# Menu items can be present long enough for an accessibility wait while their
# bridge object is replaced before IDB performs the write. Resolve the visible
# frame from one full-tree snapshot and deliver the touch directly instead.
ui_tap_exact_label_frame() {
  local label="$1"
  local description="$2"
  local attempt coordinates x y
  for attempt in 1 2 3 4 5; do
    if idb ui describe-all \
      --key AXLabel --key AXUniqueId --key frame --udid "$UDID" \
      > "$description"; then
      coordinates="$(python3 - "$description" "$label" "$CURRENT_ORIENTATION" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value = value['elements']
items = value if isinstance(value, list) else [value]
matches = [item for item in items
           if str(item.get('AXLabel', '')).strip() == sys.argv[2]
           and item.get('frame', {}).get('width', 0) > 1
           and item.get('frame', {}).get('height', 0) > 1]
assert matches, items
frame = min(matches, key=lambda item: item['frame']['width'] * item['frame']['height'])['frame']
x = frame['x'] + frame['width'] / 2
y = frame['y'] + frame['height'] / 2
screen = max(
    (item.get('frame', {}) for item in items),
    key=lambda candidate: candidate.get('width', 0) * candidate.get('height', 0)
)
orientation = sys.argv[3]
# Xcode 26 headless keeps HID in the native portrait coordinate space after
# rotation even though accessibility frames follow the rendered orientation.
if orientation == 'landscapeLeft':
    x, y = y, screen['width'] - x
elif orientation == 'landscapeRight':
    x, y = screen['height'] - y, x
elif orientation == 'portraitUpsideDown':
    x, y = screen['width'] - x, screen['height'] - y
print(round(x), round(y))
PY
)" || true
      if [ -n "$coordinates" ]; then
        x="${coordinates%% *}"
        y="${coordinates#* }"
        if idb ui tap "$x" "$y" --udid "$UDID"; then
          idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
          return 0
        fi
      fi
    fi
    sleep 1
  done
  echo "Could not tap exact accessibility label frame: $label" >&2
  return 1
}

ui_set_value_id() {
  local identifier="$1"
  local value="$2"
  local attempt
  for attempt in 1 2 3 4 5; do
    if idb ui set-value "$identifier" --match-key AXUniqueId --value "$value" --udid "$UDID"; then
      idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
      return 0
    fi
    sleep 1
  done
  echo "Could not set accessibility value after 5 attempts: $identifier" >&2
  return 1
}

ui_scroll_up_id() {
  local identifier="$1"
  local attempt description coordinates x_start y_start x_end y_end
  description="$REPORT_DIR/scroll-${identifier//[^[:alnum:]]/-}-layout.json"
  for attempt in 1 2 3 4 5; do
    if idb ui describe-all \
      --key AXUniqueId --key AXValue --key frame --udid "$UDID" > "$description"; then
      coordinates="$(python3 - "$description" "$identifier" "$CURRENT_ORIENTATION" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value = value['elements']
items = value if isinstance(value, list) else [value]
matches = [item for item in items
           if sys.argv[2] in str(item.get('AXUniqueId', ''))
           and item.get('frame', {}).get('width', 0) > 1
           and item.get('frame', {}).get('height', 0) > 1]
if not matches:
    matches = [item for item in items
               if len(str(item.get('AXValue') or '')) >= 40
               and item.get('frame', {}).get('width', 0) > 100]
assert matches, items
screen = max(
    (item.get('frame', {}) for item in items),
    key=lambda candidate: candidate.get('width', 0) * candidate.get('height', 0)
)
frame = max(matches, key=lambda item: item['frame']['width'] * item['frame']['height'])['frame']
x_start = x_end = min(max(frame['x'] + frame['width'] * 0.55, 80), screen['width'] - 80)
y_start = screen['height'] * 0.65
y_end = screen['height'] * 0.45
orientation = sys.argv[3]
def hid(x, y):
    if orientation == 'landscapeLeft':
        return y, screen['width'] - x
    if orientation == 'landscapeRight':
        return screen['height'] - y, x
    if orientation == 'portraitUpsideDown':
        return screen['width'] - x, screen['height'] - y
    return x, y
x_start, y_start = hid(x_start, y_start)
x_end, y_end = hid(x_end, y_end)
print(round(x_start), round(y_start), round(x_end), round(y_end))
PY
)" || true
      if [ -n "$coordinates" ]; then
        read -r x_start y_start x_end y_end <<EOF
$coordinates
EOF
        if idb ui swipe "$x_start" "$y_start" "$x_end" "$y_end" \
          --duration 0.45 --udid "$UDID"; then
          sleep 0.5
          return 0
        fi
      fi
    fi
    sleep 1
  done
  echo "Could not scroll accessibility identifier after 5 attempts: $identifier" >&2
  return 1
}

capture_current_ui() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$name" >/dev/null
  normalize_screenshot_orientation "$SCREENSHOT_DIR/$name" "$CURRENT_ORIENTATION"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key AXValue --key help --key frame \
    --udid "$UDID" > "$REPORT_DIR/${name%.png}-accessibility.json"
}

run_real_search_preview() {
  echo "--> [REAL UI] Search result row expansion"
  launch_interactive_scenario searchPreview sefaria en en_US
  ui_wait_id search-result-preview-toggle- 45
  ui_describe_id \
    search-result-preview-toggle- \
    "$REPORT_DIR/search-result-row-before.json"
  ui_tap_id search-result-preview-toggle-
  ui_wait_id search-result-expanded-preview- 45
  ui_describe_id \
    search-result-expanded-preview- \
    "$REPORT_DIR/search-result-preview-expanded.json"

  local waited=0
  while [ "$waited" -lt 30 ]; do
    capture_current_ui fixed-real-sefaria-search-preview.png
    if python3 - "$REPORT_DIR/fixed-real-sefaria-search-preview-accessibility.json" <<'PY' >/dev/null 2>&1
import json, sys
data = json.load(open(sys.argv[1]))
items = data.get('elements') if isinstance(data, dict) else data
items = items if isinstance(items, list) else [items]
labels = [str(x.get('AXLabel', '')) + str(x.get('AXValue', '')) for x in items]
has_he = any(any('\u0590' <= c <= '\u05ff' for c in l) for l in labels)
has_en = any(sum('a' <= c.lower() <= 'z' for c in l) >= 40 for l in labels)
assert has_he and has_en
PY
    then
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

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
assert pw >= rw * 0.70 and pw >= 600, (rw, pw)
data = json.load(open(sys.argv[3]))
items = data.get('elements') if isinstance(data, dict) else data
tree = items if isinstance(items, list) else [items]
labels = [str(x.get('AXLabel','')) for x in tree]
assert any(any('\u0590' <= c <= '\u05ff' for c in label) for label in labels), labels
assert any(sum('a' <= c.lower() <= 'z' for c in label) >= 40 for label in labels), labels
print(json.dumps({'rowWidth': rw, 'previewWidth': pw, 'ratio': pw / rw, 'bilingual': True}))
PY
}

capture_split_frames() {
  local name="$1"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key AXValue --key help --key frame \
    --udid "$UDID" > "$REPORT_DIR/$name.json"
  capture_current_ui "$name.png"
}

open_toc_from_detail() {
  launch_interactive_scenario readerDetail sefaria en en_US
  ui_wait_id reader-more-menu 45
  ui_tap_id reader-more-menu
  idb ui wait "Table of Contents" --match-key AXLabel --timeout 30 --json --udid "$UDID"
  ui_tap_label "Table of Contents"
  ui_wait_id toc-column 30
  ui_wait_id toc-row- 30
}

run_split_geometry_flow() {
  echo "--> [REAL UI] Native all/double/detail split geometry"
  launch_interactive_scenario reader sefaria en en_US
  ui_wait_id library-column 45
  ui_wait_id toc-column 30
  ui_wait_id toc-row- 30
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-all-en

  launch_interactive_scenario reader sefaria he he_IL
  ui_wait_id library-column 45
  ui_wait_id toc-column 30
  ui_wait_id toc-row- 30
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-all-he

  open_toc_from_detail
  capture_split_frames fixed-split-double-en

  # Exercise the same real reader action used to open the supplementary
  # column. When the TOC is visible it is exposed as an unambiguous close
  # action, avoiding reliance on transient SwiftUI toolbar geometry.
  open_toc_from_detail
  ui_wait_id reader-more-menu 30
  ui_tap_id reader-more-menu
  idb ui wait "Close Table of Contents" --match-key AXLabel --timeout 30 --json --udid "$UDID"
  ui_tap_exact_label_frame \
    "Close Table of Contents" \
    "$REPORT_DIR/toc-close-menu-layout.json"
  ui_wait_absent_id toc-column 30
  ui_wait_id reader-detail-column 30
  capture_split_frames fixed-split-detail-en

  python3 - "$REPORT_DIR" <<'PY'
import json, pathlib, sys
from collections import Counter
root = pathlib.Path(sys.argv[1])
def elements(name):
    value = json.loads((root / f'{name}.json').read_text())
    if isinstance(value, dict) and 'elements' in value: value = value['elements']
    return value if isinstance(value, list) else [value]
def library_landmark(name):
    candidates = [item['frame'] for item in elements(name)
                  if 140 <= item.get('frame', {}).get('width', 0) <= 152
                  and 20 <= item.get('frame', {}).get('height', 0) <= 28
                  and 240 <= item.get('frame', {}).get('y', 0) <= 930]
    assert len(candidates) >= 8, (name, candidates)
    x = Counter(round(frame['x'], 1) for frame in candidates).most_common(1)[0][0]
    return next(frame for frame in candidates if round(frame['x'], 1) == x)
def toc_landmark(name):
    rows = [item['frame'] for item in elements(name)
            if str(item.get('AXUniqueId', '')).startswith('toc-row-')
            and item.get('frame', {}).get('width', 0) > 1]
    assert rows, name
    return min(rows, key=lambda frame: frame['y'])
def reader_header(name):
    headers = [item['frame'] for item in elements(name)
               if abs(item.get('frame', {}).get('y', -100) - 86) <= 2
               and abs(item.get('frame', {}).get('height', 0) - 54) <= 2
               and item.get('frame', {}).get('width', 0) > 300]
    assert headers, name
    return max(headers, key=lambda frame: frame['width'])
def center(frame): return frame['x'] + frame['width'] / 2
en = [library_landmark('fixed-split-all-en'), toc_landmark('fixed-split-all-en'), reader_header('fixed-split-all-en')]
he = [library_landmark('fixed-split-all-he'), toc_landmark('fixed-split-all-he'), reader_header('fixed-split-all-he')]
assert center(en[0]) < center(en[1]) < center(en[2]), en
assert center(he[0]) > center(he[1]) > center(he[2]), he
double = [toc_landmark('fixed-split-double-en'), reader_header('fixed-split-double-en')]
assert center(double[0]) < center(double[1]), double
detail = reader_header('fixed-split-detail-en')
assert detail['width'] > double[1]['width'], (detail, double[1])
print(json.dumps({'allEnglish': en, 'allHebrew': he, 'doubleEnglish': double, 'detailEnglish': detail}))
PY
}

run_panel_geometry_and_scroll_flow() {
  echo "--> [REAL UI] Study side, floating mode, and viewport anchoring"
  launch_interactive_scenario studyCommentaries sefaria he he_IL
  ui_wait_id torah-inspector-panel 45
  ui_wait_id reader-text 30
  ui_wait_id torah-inspector-selected-segment 30
  capture_split_frames fixed-study-side-he

  launch_interactive_scenario studyCommentaries sefaria en en_US
  ui_wait_id torah-inspector-panel 45
  ui_wait_id reader-text 30
  ui_wait_id torah-inspector-selected-segment 30
  ui_wait_id torah-inspector-tools 30
  capture_split_frames fixed-study-side-en

  launch_interactive_scenario inspector sefaria en en_US
  ui_wait_id torah-inspector-panel 45
  capture_split_frames fixed-study-floating-half-en

  launch_interactive_scenario readerDetail sefaria en en_US
  ui_wait_id reader-text 45
  for _ in 1 2; do
    ui_scroll_up_id reader-text
  done
  sleep 1
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
  viewport_report="$CONTAINER/Documents/real-ui-readerDetail-sefaria.ready.viewport.json"
  waited=0
  while [ ! -s "$viewport_report" ] && [ "$waited" -lt 30 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  [ -s "$viewport_report" ] || { echo "Viewport metadata report was not written" >&2; return 1; }
  cp "$viewport_report" "$REPORT_DIR/viewport-before-study-toggles.json"
  before_viewport_payload="$(cat "$viewport_report")"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key AXValue --key frame --udid "$UDID" \
    > "$REPORT_DIR/viewport-before-visible.json"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    ui_tap_id reader-study-toggle
  done
  waited=0
  while [ "$(cat "$viewport_report" 2>/dev/null || true)" = "$before_viewport_payload" ] && [ "$waited" -lt 30 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  [ "$(cat "$viewport_report" 2>/dev/null || true)" != "$before_viewport_payload" ] || {
    echo "Viewport metadata did not update after Study toggles" >&2
    return 1
  }
  cp "$viewport_report" "$REPORT_DIR/viewport-after-study-toggles.json"
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key AXValue --key frame --udid "$UDID" \
    > "$REPORT_DIR/viewport-after-visible.json"

  python3 - "$REPORT_DIR" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
def items(name):
    value = json.loads((root / f'{name}.json').read_text())
    if isinstance(value, dict) and 'elements' in value: value = value['elements']
    return value if isinstance(value, list) else [value]
def frame(name, marker):
    values = [x['frame'] for x in items(name) if marker in str(x.get('AXUniqueId','')) and x.get('frame',{}).get('width',0)>1]
    assert values, (name, marker, values)
    return values[0]
def selected_segment(name):
    values = [x['frame'] for x in items(name)
              if (str(x.get('AXUniqueId','')).startswith('torah-inspector-selected-segment')
                  or str(x.get('AXLabel','')).strip() in ('Selected Segment', '\u05e7\u05d8\u05e2 \u05e0\u05d1\u05d7\u05e8'))
              and x.get('frame',{}).get('width',0)>1]
    assert values, (name, 'selected segment', values)
    return values[0]
def reader_content(name):
    values = [x['frame'] for x in items(name)
              if len(str(x.get('AXValue') or '')) >= 40
              and x.get('frame',{}).get('width',0) > 100]
    assert values, name
    return values[0]
he_reader, he_panel = reader_content('fixed-study-side-he'), selected_segment('fixed-study-side-he')
en_reader, en_panel = reader_content('fixed-study-side-en'), selected_segment('fixed-study-side-en')
assert he_panel['x'] < he_reader['x'], (he_reader, he_panel)
assert en_panel['x'] > en_reader['x'], (en_reader, en_panel)
selected = selected_segment('fixed-study-side-en')
tools = frame('fixed-study-side-en','torah-inspector-tools')
assert selected['y'] + selected['height'] <= tools['y'] + 2, (selected, tools)
def one(path):
    value=json.loads(path.read_text())
    if isinstance(value, dict) and 'elements' in value: value=value['elements']
    return value if isinstance(value,list) else [value]
before = json.loads((root/'viewport-before-study-toggles.json').read_text())
after = json.loads((root/'viewport-after-study-toggles.json').read_text())
before_items, after_items = one(root/'viewport-before-visible.json'), one(root/'viewport-after-visible.json')
def visible_text(values):
    matches=[item for item in values if len(str(item.get('AXValue') or '')) >= 40
             and -10 <= item.get('frame',{}).get('y',-1000) <= 958]
    assert matches, values
    return min(matches, key=lambda item:item['frame']['y']).get('AXValue')
assert before['source'] == after['source'], (before, after)
assert before['object'] == after['object'], (before, after)
assert abs(float(before['offset']) - float(after['offset'])) <= 32.0, (before, after)
assert float(after['capturedAt']) > float(before['capturedAt']), (before, after)
assert visible_text(before_items) == visible_text(after_items), (visible_text(before_items), visible_text(after_items))
print(json.dumps({'hebrew': [he_reader,he_panel], 'english':[en_reader,en_panel], 'selectedAboveTools':[selected,tools], 'viewportBefore':before, 'viewportAfter':after, 'visibleTextStable': True}))
PY
}

run_source_gesture_flow() {
  echo "--> [REAL UI] Linked-source single tap and double tap"
  launch_interactive_scenario studyLinks sefaria en en_US
  ui_wait_id torah-inspector-source- 45
  idb ui describe-all \
    --key AXUniqueId --key AXLabel --key frame --udid "$UDID" \
    > "$REPORT_DIR/source-before-gestures.json"
  IFS='|' read -r source_x source_y source_work < <(python3 - \
    "$REPORT_DIR/source-before-gestures.json" "$CURRENT_ORIENTATION" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value=value['elements']
items=value if isinstance(value,list) else [value]
matches=[item for item in items
         if str(item.get('AXUniqueId','')).startswith('torah-inspector-source-')
         and item.get('frame',{}).get('width',0)>1
         and item.get('frame',{}).get('height',0)>1]
assert matches, items
value=min(matches, key=lambda item:item['frame']['y'])
identifier=value['AXUniqueId']
work=identifier.split(':', 1)[1].split('|', 1)[0]
f=value['frame']
x=f['x']+f['width']/2; y=f['y']+f['height']/2
screen=max((item.get('frame',{}) for item in items),
           key=lambda candidate:candidate.get('width',0)*candidate.get('height',0))
orientation=sys.argv[2]
if orientation == 'landscapeLeft':
    x,y=y,screen['width']-x
elif orientation == 'landscapeRight':
    x,y=screen['height']-y,x
elif orientation == 'portraitUpsideDown':
    x,y=screen['width']-x,screen['height']-y
print(f"{round(x)}|{round(y)}|{work}")
PY
  )
  idb ui tap "$source_x" "$source_y" --udid "$UDID"
  ui_wait_id torah-inspector-source-expanded- 45
  capture_current_ui fixed-real-source-single-tap-expanded.png

  idb ui tap "$source_x" "$source_y" --udid "$UDID"
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
  idb ui multi-tap "$source_x" "$source_y" --count 2 --pause 0.08 --udid "$UDID"
  ui_wait_absent_id torah-inspector-panel 45
  ui_wait_id reader-header-title 45
  ui_describe_id \
    reader-header-title \
    "$REPORT_DIR/source-double-tap-reader-header.json"
  python3 - "$REPORT_DIR/source-double-tap-reader-header.json" "$source_work" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
if isinstance(value, dict) and 'elements' in value: value=value['elements']
if isinstance(value, list): value=value[0]
assert str(value.get('AXUniqueId','')).startswith('reader-header-title'), value
assert str(value.get('AXLabel','')).strip() == sys.argv[2].strip() or sys.argv[2].strip() in str(value.get('AXLabel','')).strip(), (value, sys.argv[2])
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
  idb ui quiet 30 --bundle-id "$BUNDLE_ID" --udid "$UDID" || true
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
  ui_tap_label "OK"
  ui_wait_id annotation-note-text 10
  ui_describe_id \
    annotation-note-text \
    "$REPORT_DIR/invalid-note-preserved-text.json"
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

  echo ""
  echo "=== [PHASE 4A: UIKit Library Snapshot Regressions] ==="
  SMOKE_READY_FILE="$CONTAINER/Documents/library-snapshot-regression.ready" \
    CAPTURE_WAIT_SECONDS=30 capture_screen "library-snapshot-regression.png" he he_IL \
      -smokeScenario librarySnapshotRegression -smokeBackend sefaria -smokeBypassBootstrap
  SMOKE_READY_FILE="$CONTAINER/Documents/backend-switch-regression.ready" \
    CAPTURE_WAIT_SECONDS=120 capture_screen "backend-switch-regression.png" he he_IL \
      -smokeScenario backendSwitchRegression -smokeBackend otzaria -smokeBypassBootstrap
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
SMOKE_READY_FILE="$CONTAINER/Documents/sefaria-search-results.ready" SMOKE_SETTLE_SECONDS=2 CAPTURE_WAIT_SECONDS=120 capture_screen_with_retry "sefaria-he-search-results.png" he he_IL -smokeScenario searchResults -smokeBackend sefaria -smokeBypassBootstrap
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
set_orientation portrait
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
