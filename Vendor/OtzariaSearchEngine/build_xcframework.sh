#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_DIR="$ROOT/Checkout/otzaria_search_engine"
BRIDGE_DIR="$ROOT/ios_bridge"
BUILD_DIR="$ROOT/build"
OUT="$ROOT/OtzariaSearchEngine.xcframework"
HEADER_DIR="$ROOT/include"
PIN_FILE="$ROOT/Upstream/UPSTREAM_COMMIT"
LIB_NAME="libotzaria_search_engine_ios.a"
REPOSITORY="https://github.com/Otzaria/otzaria_search_engine.git"

for tool in cargo rustup git lipo xcodebuild; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

PIN="$(tr -d '[:space:]' < "$PIN_FILE")"
case "$PIN" in
  (*[!0-9a-f]*|'') echo "UPSTREAM_COMMIT is not a full lowercase SHA" >&2; exit 1 ;;
esac
if [ "${#PIN}" -ne 40 ]; then
  echo "UPSTREAM_COMMIT must contain 40 hexadecimal characters" >&2
  exit 1
fi

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  mkdir -p "$(dirname "$UPSTREAM_DIR")"
  git clone "$REPOSITORY" "$UPSTREAM_DIR"
fi
if [ -n "$(git -C "$UPSTREAM_DIR" status --porcelain)" ]; then
  echo "Refusing to build from a dirty upstream checkout" >&2
  exit 1
fi
git -C "$UPSTREAM_DIR" fetch origin "$PIN"
git -C "$UPSTREAM_DIR" checkout --detach "$PIN"
test "$(git -C "$UPSTREAM_DIR" rev-parse HEAD)" = "$PIN"
test -z "$(git -C "$UPSTREAM_DIR" status --porcelain)"

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# These are fixed, resolved targets under this vendor directory.
rm -rf "$BUILD_DIR" "$OUT"
mkdir -p "$BUILD_DIR/ios-arm64" "$BUILD_DIR/ios-sim"
export IPHONEOS_DEPLOYMENT_TARGET=18.6

pushd "$BRIDGE_DIR" >/dev/null
cargo build --locked --release --target aarch64-apple-ios
cargo build --locked --release --target aarch64-apple-ios-sim
cargo build --locked --release --target x86_64-apple-ios
popd >/dev/null

cp "$BRIDGE_DIR/target/aarch64-apple-ios/release/$LIB_NAME" "$BUILD_DIR/ios-arm64/$LIB_NAME"
lipo -create \
  "$BRIDGE_DIR/target/aarch64-apple-ios-sim/release/$LIB_NAME" \
  "$BRIDGE_DIR/target/x86_64-apple-ios/release/$LIB_NAME" \
  -output "$BUILD_DIR/ios-sim/$LIB_NAME"

xcodebuild -create-xcframework \
  -library "$BUILD_DIR/ios-arm64/$LIB_NAME" -headers "$HEADER_DIR" \
  -library "$BUILD_DIR/ios-sim/$LIB_NAME" -headers "$HEADER_DIR" \
  -output "$OUT"

test -z "$(git -C "$UPSTREAM_DIR" status --porcelain)"
echo "Created $OUT from $PIN; upstream checkout remains pristine"
