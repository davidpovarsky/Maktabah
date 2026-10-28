#!/usr/bin/env bash
set -euo pipefail

# Scripts/sync-sefaria-upstream.sh
# Synchronizes the pinned upstream Sefaria-Mobile repository to the verified SHA.

PINNED_SHA="${1:-2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c}"
TARGET_DIR="Vendor/SefariaMobile/Upstream"
REPO_URL="https://github.com/Sefaria/Sefaria-Mobile.git"

echo "=== Syncing Sefaria-Mobile Upstream Dependency ==="
echo "Target Directory: $TARGET_DIR"
echo "Pinned SHA: $PINNED_SHA"

if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "Cloning repository..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"
echo "Fetching origin..."
git fetch origin

echo "Checking out $PINNED_SHA..."
git checkout "$PINNED_SHA"

CURRENT_SHA=$(git rev-parse HEAD)
echo "Verified current SHA: $CURRENT_SHA"

if [ "$CURRENT_SHA" != "$PINNED_SHA" ]; then
    echo "ERROR: Checked out SHA ($CURRENT_SHA) does not match pinned SHA ($PINNED_SHA)" >&2
    exit 1
fi

echo "=== Sefaria-Mobile sync complete ==="
