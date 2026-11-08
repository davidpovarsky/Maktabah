#!/usr/bin/env bash
# Keep the lockfile and lifecycle scripts; retry only transient download failures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$ROOT/build/logs"
LOGS="$(mktemp -d "$ROOT/build/logs/embedded-npm.XXXXXX")"
cd "$ROOT/Vendor/SefariaMobile/Upstream"
# Sharp 0.32.6's installers use short-lived requests to GitHub. A 504 can
# unnecessarily fall through into node-gyp. Supply its documented local-prebuild
# inputs using curl's bounded transient retries, without changing any package.
# Sources: lovell/sharp v0.32.6 install/libvips.js and prebuild-install util.js.
if [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ]; then
  node -e 'if(require("./package-lock.json").packages["node_modules/sharp"].version !== "0.32.6") throw Error("Review the pinned Sharp artifacts before changing its version")'
  PREBUILDS="$LOGS/native-prebuilds"
  mkdir -p "$PREBUILDS/v8.14.5"
  export npm_config_sharp_local_prebuilds="$PREBUILDS"
  export npm_config_sharp_libvips_local_prebuilds="$PREBUILDS"
  download_verified() {
    local url="$1" destination="$2" algorithm="$3" expected="$4"
    curl --fail --location --retry 4 --retry-delay 5 --retry-connrefused \
      --connect-timeout 20 --max-time 120 --output "$destination.partial" "$url"
    node -e 'const fs=require("fs"),c=require("crypto");const [p,a,e]=process.argv.slice(1);if(c.createHash(a).update(fs.readFileSync(p)).digest("hex")!==e)throw Error("Pinned native dependency integrity mismatch")' "$destination.partial" "$algorithm" "$expected"
    mv "$destination.partial" "$destination"
    echo "Verified pinned native dependency: $(basename "$destination")"
  }
  # SHA256 of the exact official release asset (92,687 bytes), fetched and
  # independently recorded during diagnosis; not a package version update.
  download_verified \
    https://github.com/lovell/sharp/releases/download/v0.32.6/sharp-v0.32.6-napi-v7-darwin-arm64.tar.gz \
    "$PREBUILDS/sharp-v0.32.6-napi-v7-darwin-arm64.tar.gz" sha256 \
    8004e60c1161f65977dd45455a8fa22687c0c387e1b57ef64b44bce2baf0085a
  # This SHA512 is the unchanged integrity value in Sharp 0.32.6 package.json.
  VIPS_SHA512="$(node -e 'process.stdout.write(Buffer.from("1QZzICfCJd4wAO0P6qmYI5e5VFMt9iCE4QgefI8VMMbdSzjIXA9L/ARN6pkMQPZ3h20Y9RtJ2W1skgCsvCIccw==","base64").toString("hex"))')"
  download_verified \
    https://github.com/lovell/sharp-libvips/releases/download/v8.14.5/libvips-8.14.5-darwin-arm64v8.tar.br \
    "$PREBUILDS/v8.14.5/libvips-8.14.5-darwin-arm64v8.tar.br" sha512 "$VIPS_SHA512"
fi
for attempt in 1 2 3; do
  if npm ci --legacy-peer-deps > "$LOGS/attempt-$attempt.log" 2>&1; then
    cat "$LOGS/attempt-$attempt.log"
    exit 0
  else
    result=$?
  fi
  cat "$LOGS/attempt-$attempt.log"
  if [ "$attempt" = 3 ] || ! grep -Eiq 'Request timed out|ETIMEDOUT|ECONNRESET|EAI_AGAIN|ENETUNREACH|HTTP[^0-9]*(429|500|502|503|504)|status (code )?(429|500|502|503|504)' "$LOGS/attempt-$attempt.log"; then
    exit "$result"
  fi
  echo "Transient dependency download failure; retrying the same lockfile ($attempt/3)."
  sleep "$((attempt * 5))"
done
