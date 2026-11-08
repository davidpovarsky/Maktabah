#!/usr/bin/env bash
# Keep the lockfile and lifecycle scripts; retry only transient download failures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$ROOT/build/logs"
LOGS="$(mktemp -d "$ROOT/build/logs/embedded-npm.XXXXXX")"
cd "$ROOT/Vendor/SefariaMobile/Upstream"
for attempt in 1 2 3; do
  if npm ci --legacy-peer-deps > "$LOGS/attempt-$attempt.log" 2>&1; then
    cat "$LOGS/attempt-$attempt.log"
    exit 0
  else
    result=$?
  fi
  cat "$LOGS/attempt-$attempt.log"
  if [ "$attempt" = 3 ] || ! grep -Eiq 'Request timed out|ETIMEDOUT|ECONNRESET|EAI_AGAIN|ENETUNREACH|HTTP[^0-9]*(429|500|502|503|504)|status code (429|500|502|503|504)' "$LOGS/attempt-$attempt.log"; then
    exit "$result"
  fi
  echo "Transient dependency download failure; retrying the same lockfile ($attempt/3)."
  sleep "$((attempt * 5))"
done
