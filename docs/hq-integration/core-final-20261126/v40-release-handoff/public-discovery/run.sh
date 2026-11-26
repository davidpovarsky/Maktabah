#!/bin/bash
set -Eeuo pipefail
root="$HOME/builds/otzaria-core-20261126"
probe="$root/production-release-client-smoke"
cd "$probe"
trap 'echo $? > exit' EXIT
/opt/homebrew/bin/python3.12 - <<'PYTHON'
from pathlib import Path
source=Path('Source/ZayitSearch/ZayitSearchDistribution.swift').read_bytes()
boundary=b'@MainActor\nfinal class ZayitSearchDataController'
assert source.count(boundary)==1
original=source.split(boundary,1)[0]
assert b'https://api.github.com/repos/' in original
assert b'127.0.0.1' not in original
probe=Path('ZayitDistributionCore.swift')
probe.write_bytes(original+Path('ZayitObservationExtension.swift').read_bytes())
assert probe.read_bytes().startswith(original)
PYTHON
p=Source/Otzaria
b="$p/Bootstrap"
s="$p/Search"
sources=(Source/Core/Database/{SQLiteDatabase,ZstdShim}.swift "$b"/Otzaria{DatabaseDownloader,DatabaseDownloadModels,DownloadPolicy,LibraryReleaseClient,ZstdStreamExtractor,DatabaseInstaller}.swift "$p"/DataProfiles/*.swift "$p"/Storage/*.swift "$p"/Core/*.swift "$s"/{OtzariaSearchMode,OtzariaSearchModels,OtzariaIndexFileLogger}.swift "$s"/Distribution/OtzariaSearchArtifact{Manifest,Policy,ReleaseClient}.swift Tests/HQ/sqlite/UnusedZstdBoundary.swift ComponentBoundary.swift Source/ZayitSearch/ZayitInstallCapacityPolicy.swift)
shasum -a 256 "${sources[@]}" Source/ZayitSearch/ZayitSearchDistribution.swift ZayitDistributionCore.swift ProductionDiscovery.swift ZayitObservationExtension.swift > INPUTS.sha256
test "$(uname -m)" = arm64
xcodebuild -version
xcrun swiftc -O -swift-version 5 -parse-as-library -module-cache-path "$probe/modules" -L /opt/homebrew/lib -lzstd "${sources[@]}" ZayitDistributionCore.swift ProductionDiscovery.swift -o Smoke > compile.log 2>&1 || { tail -40 compile.log; exit 1; }
OTZARIA_DATA_PROFILE=production ./Smoke "$probe" "$root/bootstrap-promotion/full-v40-upgrade-retry/state"
