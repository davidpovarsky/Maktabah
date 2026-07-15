#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /path/to/seforim.db /path/to/zayit-search-index" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cargo run --release --manifest-path "$ROOT/Rust/Cargo.toml" --bin zayit-index-builder -- "$1" "$2"
