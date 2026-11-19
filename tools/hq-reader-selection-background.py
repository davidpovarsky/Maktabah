#!/usr/bin/env python3
"""Exercise actual selection-layer logic with Foundation color/key fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--artifacts-dir", type=Path, required=True)
p.add_argument("--before-ref")
args = p.parse_args()
out = args.artifacts_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
require_files = ["logic.swift", "selection-tests.exe", "result.json", "compile.log", "tests.log"]
if any((out / name).exists() for name in require_files):
    raise SystemExit("Do not overwrite retained test evidence")
fixture = ROOT / "Tests/HQ/reader/SelectionBackgroundTests.swift"
if args.before_ref:
    if not re.fullmatch(r"[a-f0-9]{40}", args.before_ref):
        raise SystemExit("An immutable source SHA is required")
    name = "Source/UI/iOS/Wrappers/iOSIbarotTextView.swift"
    raw = subprocess.check_output(["git", "show", args.before_ref + ":" + name], cwd=ROOT)
    text = raw.decode("utf-8")
    start = text.index("                attributedString.addAttribute(", text.index("        if let selectedSegmentRange {", text.index("    private func renderAttributedContent(")))
    end = text.index("\n                )", start) + len("\n                )")
    fragment = text[start:end]
    assert ".backgroundColor" in fragment and "UIColor.systemBlue.withAlphaComponent(0.14)" in fragment and "range: displayedSelected" in fragment
    body = fragment.replace(".backgroundColor", "attribute").replace("UIColor.systemBlue.withAlphaComponent(0.14)", "color").replace("range: displayedSelected", "range: range")
    logic = "import Foundation\nenum ReaderSelectionBackground {\nstatic func apply(to attributedString: NSMutableAttributedString, range: NSRange, attribute: NSAttributedString.Key, color: Any) {\n" + body + "\n}\n}\n"
    source = {"path": name, "sha": args.before_ref, "sha256": hashlib.sha256(raw).hexdigest(),
              "fragment_sha256": hashlib.sha256(fragment.encode()).hexdigest(),
              "boundary_aliases": ["UIKit background key -> supplied Foundation key", "UIKit selection color -> supplied color fixture", "already validated displayedSelected -> supplied valid NSRange"]}
else:
    name = "Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift"
    raw = (ROOT / name).read_bytes()
    text = raw.decode("utf-8")
    marker = "enum ReaderSelectionBackground {"
    assert text.count(marker) == 1
    logic = "import Foundation\n" + text[text.index(marker):]
    source = {"path": name, "sha256": hashlib.sha256(raw).hexdigest(), "extraction": "Exact complete production enum, no changes"}
(out / "logic.swift").write_bytes(logic.encode())
command = ["swiftc", "-parse-as-library", str(out / "logic.swift"), str(fixture), "-o", str(out / "selection-tests.exe")]
compiler = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=180)
(out / "compile.log").write_bytes((compiler.stdout + compiler.stderr).encode())
report = {"source": source, "fixture_sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
          "compiled_logic_sha256": hashlib.sha256(logic.encode()).hexdigest(), "compile_exit": compiler.returncode,
          "native_passes": 0}
if compiler.returncode == 0:
    actual = subprocess.run([str(out / "selection-tests.exe")], capture_output=True, text=True, encoding="utf-8", timeout=30)
    (out / "tests.log").write_bytes((actual.stdout + actual.stderr).encode())
    report.update(test_exit=actual.returncode, actual=json.loads(actual.stdout))
(out / "result.json").write_bytes((json.dumps(report, indent=2, ensure_ascii=False) + "\n").encode())
print(json.dumps(report, ensure_ascii=True))
raise SystemExit(report.get("test_exit", 1))
