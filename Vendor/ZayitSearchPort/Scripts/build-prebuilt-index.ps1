param(
    [Parameter(Mandatory=$true)][string]$SeforimDb,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $root 'Rust/Cargo.toml'

if (-not (Test-Path -LiteralPath $SeforimDb -PathType Leaf)) {
    throw "seforim.db not found: $SeforimDb"
}

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust/Cargo is not installed. Install Rust from https://rustup.rs and reopen PowerShell.'
}

cargo run --release --manifest-path $manifest --bin zayit-index-builder -- $SeforimDb $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'Index builder failed.' }

Write-Host "Prebuilt index created at: $OutputDirectory"
