#!/usr/bin/env bash
# Artifact acceptance uses the same real embedded runtime as the shipping app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
test -s Vendor/SefariaMobile/Upstream/package-lock.json || {
  echo "The pinned Sefaria submodule is not initialized; recursive checkout is required." >&2
  exit 1
}
(cd Vendor/SefariaMobile/Upstream && npm ci --legacy-peer-deps)
for name in node_modules package.json app.json metro.config.js babel.config.js; do
  ln -sfn "$ROOT/Vendor/SefariaMobile/Upstream/$name" "$ROOT/$name"
done
ln -sfn "$ROOT/Vendor/SefariaMobile/Upstream/node_modules" "$ROOT/../node_modules"
export PROJECT_ROOT="$ROOT/Vendor/SefariaMobile/Upstream"
export NODE_PATH="$PROJECT_ROOT/node_modules"
export RCT_NO_LAUNCH_PACKAGER=1 SKIP_BUNDLING=1
export GOOGLE_SERVICES_FILE="$ROOT/Source/GoogleService-Info.plist"
cp "$GOOGLE_SERVICES_FILE" "$ROOT/GoogleService-Info.plist"
cp "$GOOGLE_SERVICES_FILE" "$PROJECT_ROOT/ios/GoogleService-Info.plist"
chmod -R +x "$NODE_PATH/.bin" "$NODE_PATH/expo/bin"
pod install
chmod -R +x "$ROOT/Pods/Target Support Files"
mkdir -p build/jsbundle
(
  cd "$PROJECT_ROOT"
  npx react-native bundle --config ../Integration/metro.config.embedded.js \
    --platform ios --dev false --entry-file ../Integration/index.embedded.js \
    --bundle-output ../../../build/jsbundle/main.jsbundle --assets-dest ../../../build/jsbundle
)
test -s build/jsbundle/main.jsbundle
if [ -n "${GITHUB_ENV:-}" ]; then
  for name in PROJECT_ROOT NODE_PATH RCT_NO_LAUNCH_PACKAGER SKIP_BUNDLING GOOGLE_SERVICES_FILE; do
    printf '%s=%s\n' "$name" "${!name}" >> "$GITHUB_ENV"
  done
fi
