$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $repo 'Tests/HQ/updates'
$buildRoot = Join-Path $fixtureRoot '.build'
$moduleRoot = Join-Path $buildRoot 'SQLite3'
New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
$sdk = Get-ChildItem 'C:/Program Files (x86)/Windows Kits/10/Include' -Directory |
    Sort-Object Name -Descending | Where-Object { Test-Path (Join-Path $_.FullName 'um/winsqlite/winsqlite3.h') } | Select-Object -First 1
if (!$sdk) { throw 'Installed Windows SDK SQLite header required; no download or dependency mutation is performed.' }
$header = (Join-Path $sdk.FullName 'um/winsqlite/winsqlite3.h').Replace('\','/')
$lib = Join-Path (Split-Path (Split-Path $sdk.FullName -Parent) -Parent) "Lib/$($sdk.Name)/um/x64"
Set-Content -LiteralPath (Join-Path $moduleRoot 'module.modulemap') -Encoding utf8 -Value "module SQLite3 [system] { header `"$header`" link `"winsqlite3`" export * }"
$exe = Join-Path $buildRoot 'hq-updates-tests.exe'
$service = Join-Path $repo 'Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift'
$parser = Join-Path $buildRoot 'ProductionCatalog.swift'
& py -3.12 -B (Join-Path $repo 'tools/hq-updates-extract-fixtures.py') $parser
if ($LASTEXITCODE -ne 0) { throw 'Catalog fixture extraction failed.' }
& swiftc -typecheck -swift-version 6 -I $buildRoot $service (Join-Path $fixtureRoot 'ProductionShims.swift')
if ($LASTEXITCODE -ne 0) { throw 'Portable production adapter typecheck failed (compiler doubles, not Apple validation).' }
& swiftc -D HQ_UPDATES_FIXTURE -I $buildRoot -L $lib $service $parser (Join-Path $fixtureRoot 'main.swift') -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Focused portable safety fixture compilation failed.' }
& $exe $buildRoot
if ($LASTEXITCODE -ne 0) { throw 'Safety fixtures failed.' }
$adapterExe = Join-Path $buildRoot 'hq-updates-adapter-tests.exe'
& swiftc -parse-as-library -swift-version 6 -I $buildRoot -L $lib $service (Join-Path $fixtureRoot 'ProductionShims.swift') (Join-Path $fixtureRoot 'AdapterMain.swift') -o $adapterExe
if ($LASTEXITCODE -ne 0) { throw 'Focused adapter fixture compilation failed.' }
& $adapterExe
if ($LASTEXITCODE -ne 0) { throw 'Adapter fixtures failed.' }
