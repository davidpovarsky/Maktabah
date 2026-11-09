#!/usr/bin/env python3
"""Cache the exact locked Sharp native archives via their original release API.

Sharp0.32.6's install/libvips.js and lib/libvips.js define this archive,
SHA512 check and npm _libvips cache path. Its normal installer still runs and
independently verifies/extracts the archive. No dependency or vendor edit.
https://github.com/lovell/sharp/tree/v0.32.6
prebuild-install7.1.3 util.js defines the Node addon cache key below.
https://github.com/prebuild/prebuild-install/blob/v7.1.3/util.js
"""
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile

SHARP_VERSION = "0.32.6"
NPM_INTEGRITY = "sha512-KyLTWwgcR9Oe4d9HwCwNM2l7+J0dUQwn/yf7S0EnTtb0eVS4RxO0eUSvxPtzT4F3SY+C4K6fqdv/DO27sJ/v/w=="
LIBVIPS_VERSION = "8.14.5"
PREBUILD_VERSION = "7.1.3"
PREBUILD_NPM_INTEGRITY = "sha512-8Mf2cbV7x1cXPUILADGI3wuhfqWvtiLA1iclTDbFRZkgRQS0NqsPZphna9V+HyTEadheuPmjaJMsbzKQFOzLug=="
PLATFORMS = {
    "darwin-arm64": ("darwin-arm64v8", "sha512-1QZzICfCJd4wAO0P6qmYI5e5VFMt9iCE4QgefI8VMMbdSzjIXA9L/ARN6pkMQPZ3h20Y9RtJ2W1skgCsvCIccw=="),
    "darwin-x64": ("darwin-x64", "sha512-sMIKMYXsdU9FlIfztj6Kt/SfHlhlDpP0Ups7ftVFqwjaszmYmpI9y/d/q3mLb4jrzuSiSUEislSWCwBnW7MPTw=="),
}
# Observed/pinned SHA256 of the exact original GitHub release assets. These
# older addons have no publisher/GitHub digest; this does not claim one.
NODE_PREBUILDS = {
    "darwin-arm64": (126626443, "8004e60c1161f65977dd45455a8fa22687c0c387e1b57ef64b44bce2baf0085a"),
    "darwin-x64": (126626446, "31b557ba2d3a2a5893d03837d83a6cb8476118fb3a84b7b2d5176fb6999b76cb"),
}


def archive_integrity(path):
    with path.open("rb") as archive:
        digest = hashlib.file_digest(archive, "sha512").digest()
    return "sha512-" + base64.b64encode(digest).decode("ascii")


def archive_sha256(path):
    with path.open("rb") as archive:
        return hashlib.file_digest(archive, "sha256").hexdigest()


def node_archive(node_platform):
    name = f"sharp-v{SHARP_VERSION}-napi-v7-{node_platform}.tar.gz"
    url = f"https://github.com/lovell/sharp/releases/download/v{SHARP_VERSION}/{name}"
    key = hashlib.sha512(url.encode("utf-8")).hexdigest()[:6] + "-" + re.sub(r"[^a-zA-Z0-9.]+", "-", name)
    return name, key


def main():
    root = Path(__file__).resolve().parents[2]
    vendor = root / "Vendor/SefariaMobile/Upstream"
    lock = json.loads((vendor / "package-lock.json").read_text(encoding="utf-8"))
    sharp = lock["packages"]["node_modules/sharp"]
    if sharp["version"] != SHARP_VERSION or sharp["integrity"] != NPM_INTEGRITY:
        raise SystemExit("Sharp lock changed; review the original archive/checksum before updating this cache adapter")
    prebuild = lock["packages"]["node_modules/prebuild-install"]
    if prebuild["version"] != PREBUILD_VERSION or prebuild["integrity"] != PREBUILD_NPM_INTEGRITY:
        raise SystemExit("prebuild-install lock changed; review its original cache contract before updating this adapter")
    node_platform = subprocess.check_output(
        ["node", "-p", "process.platform + '-' + process.arch"], cwd=vendor, text=True).strip()
    if node_platform not in PLATFORMS:
        raise SystemExit(f"This build-cache adapter supports the existing macOS runners, got {node_platform}")
    platform, expected = PLATFORMS[node_platform]
    cache_root = Path(subprocess.check_output(["npm", "config", "get", "cache"], cwd=vendor, text=True).strip()).resolve()
    cache = cache_root / "_libvips"
    cache.mkdir(parents=True, exist_ok=True)
    name = f"libvips-{LIBVIPS_VERSION}-{platform}.tar.br"
    target = cache / name
    reused = target.is_file() and archive_integrity(target) == expected
    if not reused:
        with tempfile.TemporaryDirectory(prefix="pinned-sharp-", dir=cache) as temporary:
            subprocess.run(["gh", "release", "download", f"v{LIBVIPS_VERSION}",
                            "--repo", "lovell/sharp-libvips", "--pattern", name,
                            "--dir", temporary], check=True, timeout=180)
            downloaded = Path(temporary) / name
            if archive_integrity(downloaded) != expected:
                raise SystemExit("The original libvips archive failed Sharp's original SHA512 check")
            os.replace(downloaded, target)
    print(json.dumps({"sharpVersion": SHARP_VERSION, "archive": name,
                      "sourceRepository": "lovell/sharp-libvips", "releaseTag": f"v{LIBVIPS_VERSION}",
                      "transport": "original GitHub release API", "originalSHA512Matched": True,
                      "sha512": expected, "reusedVerifiedCache": reused,
                      "normalNpmInstallAndIntegrityCheckUnchanged": True}, indent=2))
    name, key = node_archive(node_platform)
    asset_id, expected_sha256 = NODE_PREBUILDS[node_platform]
    cache = cache_root / "_prebuilds"
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / key
    reused = target.is_file() and archive_sha256(target) == expected_sha256
    if not reused:
        with tempfile.TemporaryDirectory(prefix="pinned-sharp-addon-", dir=cache) as temporary:
            subprocess.run(["gh", "release", "download", f"v{SHARP_VERSION}",
                            "--repo", "lovell/sharp", "--pattern", name,
                            "--dir", temporary], check=True, timeout=180)
            downloaded = Path(temporary) / name
            if archive_sha256(downloaded) != expected_sha256:
                raise SystemExit("The original Sharp Node addon differs from its pinned release archive")
            os.replace(downloaded, target)
    print(json.dumps({"sharpVersion": SHARP_VERSION, "prebuildInstallVersion": PREBUILD_VERSION,
                      "archive": name, "sourceRepository": "lovell/sharp", "releaseTag": f"v{SHARP_VERSION}",
                      "provenanceAssetID": asset_id, "transport": "original GitHub release API",
                      "pinnedArchiveSHA256Matched": True, "sha256": expected_sha256,
                      "digestProvenance": "observed from the original API asset; not a publisher-provided digest",
                      "reusedVerifiedCache": reused, "normalPrebuildInstallUnchanged": True}, indent=2))


if __name__ == "__main__":
    main()
