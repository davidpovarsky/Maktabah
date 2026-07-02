#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_DIR="$ROOT/upstream/otzaria_search_engine"
BRIDGE_DIR="$ROOT/ios_bridge"
BUILD_DIR="$ROOT/build"
OUT="$ROOT/OtzariaSearchEngine.xcframework"
HEADER_DIR="$ROOT/include"
LIB_NAME="libotzaria_search_engine_ios.a"

if ! command -v cargo >/dev/null 2>&1; then
  echo "Rust/cargo is required. Install rustup first." >&2
  exit 1
fi

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  mkdir -p "$ROOT/upstream"
  git clone --depth 1 --branch refactor https://github.com/Otzaria/otzaria_search_engine.git "$UPSTREAM_DIR"
else
  git -C "$UPSTREAM_DIR" fetch --depth 1 origin refactor
  git -C "$UPSTREAM_DIR" checkout refactor
  git -C "$UPSTREAM_DIR" pull --ff-only origin refactor
fi

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

rm -rf "$BUILD_DIR" "$OUT"
mkdir -p "$BUILD_DIR/ios-arm64" "$BUILD_DIR/ios-sim"

pushd "$BRIDGE_DIR" >/dev/null
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios
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

echo "Created $OUT"
