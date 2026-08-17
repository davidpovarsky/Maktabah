#!/usr/bin/env bash
set -euo pipefail

# Materialize and validate the pinned Otzaria search upstream checkout.
#
# CI caches build products (XCFramework, Cargo target dirs), not the upstream
# source tree. Every job that reads the Cargo graph - cargo check/metadata/tree,
# or the XCFramework build - needs the pinned checkout present, because
# ios_bridge/Cargo.toml carries path dependencies into
# Checkout/otzaria_search_engine/rust. On a framework cache hit the build script
# is skipped, so the checkout has to be recreated here from the pin.
#
# Usage:
#   ensure-otzaria-upstream-checkout.sh                # materialize, then verify
#   ensure-otzaria-upstream-checkout.sh --verify-only   # verify only, never fetch

MODE=materialize
while [ "$#" -gt 0 ]; do
  case "$1" in
    --verify-only) MODE=verify ;;
    -h|--help) sed -n '3,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENDOR="$ROOT/Vendor/OtzariaSearchEngine"
CHECKOUT="$VENDOR/Checkout/otzaria_search_engine"
PIN_FILE="$VENDOR/Upstream/UPSTREAM_COMMIT"
REPOSITORY="https://github.com/Otzaria/otzaria_search_engine.git"
BRANCH="refactor"

# Paths the Cargo graph resolves through; a checkout missing any of them cannot
# satisfy the bridge manifest even when git metadata looks correct.
REQUIRED_PATHS="rust/Cargo.toml rust/Cargo.lock rust/src/api/search_engine.rs rust/vendor/tantivy-fst/Cargo.toml"

fail() {
  echo "::error::otzaria upstream checkout: $1" >&2
  exit 1
}

test -f "$PIN_FILE" || fail "missing pin file $PIN_FILE"
PIN="$(tr -d '[:space:]' < "$PIN_FILE")"
case "$PIN" in
  *[!0-9a-f]*|'') fail "UPSTREAM_COMMIT is not a full lowercase SHA" ;;
esac
test "${#PIN}" -eq 40 || fail "UPSTREAM_COMMIT must contain 40 hexadecimal characters"

git_checkout() {
  git -C "$CHECKOUT" "$@"
}

head_commit() {
  git_checkout rev-parse HEAD 2>/dev/null || true
}

# Reads porcelain status into STATUS_OUTPUT. Assigning in the caller's shell
# rather than a command substitution is deliberate: `test -z "$(git -C missing
# status)"` succeeds on a missing or broken checkout because git reports the
# failure on stderr and prints nothing on stdout.
STATUS_OUTPUT=""
read_worktree_status() {
  if ! STATUS_OUTPUT="$(git_checkout status --porcelain)"; then
    fail "git status failed in $CHECKOUT"
  fi
}

required_paths_present() {
  local relative
  for relative in $REQUIRED_PATHS; do
    test -f "$CHECKOUT/$relative" || return 1
  done
  return 0
}

if [ "$MODE" = materialize ]; then
  if [ ! -d "$CHECKOUT/.git" ]; then
    mkdir -p "$(dirname "$CHECKOUT")"
    git init --quiet "$CHECKOUT"
    git_checkout remote add origin "$REPOSITORY"
  elif ! git_checkout remote get-url origin >/dev/null 2>&1; then
    git_checkout remote add origin "$REPOSITORY"
  fi

  # A dirty tree is never repaired automatically: it would silently discard
  # whatever produced the drift.
  read_worktree_status
  if [ -n "$STATUS_OUTPUT" ]; then
    fail "refusing to touch a dirty upstream checkout: $CHECKOUT"
  fi

  if [ "$(head_commit)" != "$PIN" ] || ! required_paths_present; then
    if ! git_checkout cat-file -e "$PIN^{commit}" 2>/dev/null; then
      git_checkout fetch --depth 1 origin "$PIN" \
        || git_checkout fetch --prune origin "$BRANCH" \
        || fail "unable to fetch $PIN from $REPOSITORY"
    fi
    git_checkout checkout --detach --quiet "$PIN"
  fi
fi

test -d "$CHECKOUT" || fail "checkout directory is missing: $CHECKOUT"
test -d "$CHECKOUT/.git" || fail "checkout is not a git repository: $CHECKOUT"

ACTUAL="$(git_checkout rev-parse HEAD)" || fail "unable to read HEAD in $CHECKOUT"
test "$ACTUAL" = "$PIN" || fail "pin drift: checkout is at $ACTUAL, expected $PIN"

for relative in $REQUIRED_PATHS; do
  test -f "$CHECKOUT/$relative" || fail "pinned checkout is missing $relative"
done

read_worktree_status
test -z "$STATUS_OUTPUT" || fail "upstream checkout is dirty: $CHECKOUT
$STATUS_OUTPUT"

echo "otzaria upstream checkout verified at $PIN ($MODE)"
