#!/usr/bin/env python3
"""Replay only the new consumer checks against an already compiled shared bridge."""
from pathlib import Path
import argparse
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bridge-products", required=True, type=Path)
parser.add_argument("--swiftc", default="swiftc")
parser.add_argument("--sqlite-header", type=Path, default=Path("/usr/include/sqlite3.h"))
args = parser.parse_args()
if sys.platform != "linux":
    parser.error("This portable receipt lane runs on Linux; use native acceptance for Apple UI.")
root = Path(__file__).resolve().parents[3]
products = args.bridge_products.resolve()
bridge_object = products / "HanlinMiniAppsBridge.o"
if not bridge_object.is_file() or not (products / "HanlinMiniAppsBridge.swiftmodule").exists():
    parser.error("Supply the products directory of the already built HanlinMiniAppsBridge package.")
checks = root / "Tests/HQ/miniapps"
with tempfile.TemporaryDirectory(prefix="otzaria-miniapps-checks-") as temporary:
    temp = Path(temporary)
    module = temp / "sqlite-module"
    module.mkdir()
    (module / "module.modulemap").write_text(
        'module SQLite3 [system] { header "' + str(args.sqlite_header.resolve()) + '" link "sqlite3" export * }\n'
    )
    cases = [
        ("document", [root / "Source/ChavrusaText/MiniApps/OtzariaMiniAppsDocument.swift", checks / "OtzariaMiniAppsDocumentChecks.swift"]),
        ("receipt", [root / "Source/Core/Database/SQLiteDatabase.swift", root / "Source/ChavrusaText/MiniApps/OtzariaMiniAppsReceiptJournal.swift", checks / "OtzariaMiniAppsReceiptChecks.swift", checks / "SQLiteTextOnlyTestSupport.swift"]),
    ]
    for name, sources in cases:
        output = temp / name
        subprocess.run([args.swiftc, "-swift-version", "6", "-I", str(products), "-I", str(module), *map(str, sources), str(bridge_object), "-o", str(output)], cwd=root, check=True)
        subprocess.run([str(output)], cwd=root, check=True)
