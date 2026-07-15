#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRATE="$ROOT/Rust"
TARGET_DIR="$CRATE/target"
OUT="$ROOT/build"
rm -rf "$OUT"
mkdir -p "$OUT/sim"

rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cargo build --manifest-path "$CRATE/Cargo.toml" --lib --release --target aarch64-apple-ios
cargo build --manifest-path "$CRATE/Cargo.toml" --lib --release --target aarch64-apple-ios-sim
cargo build --manifest-path "$CRATE/Cargo.toml" --lib --release --target x86_64-apple-ios

lipo -create \
  "$TARGET_DIR/aarch64-apple-ios-sim/release/libmaktabah_zayit_search.a" \
  "$TARGET_DIR/x86_64-apple-ios/release/libmaktabah_zayit_search.a" \
  -output "$OUT/sim/libmaktabah_zayit_search.a"

xcodebuild -create-xcframework \
  -library "$TARGET_DIR/aarch64-apple-ios/release/libmaktabah_zayit_search.a" \
  -headers "$CRATE/include" \
  -library "$OUT/sim/libmaktabah_zayit_search.a" \
  -headers "$CRATE/include" \
  -output "$OUT/MaktabahZayitSearch.xcframework"

echo "$OUT/MaktabahZayitSearch.xcframework"
