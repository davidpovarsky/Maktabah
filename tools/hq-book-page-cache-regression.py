#!/usr/bin/env python3
"""Compile and execute the original cache and real models against the same fixture."""
import argparse, hashlib, json, os, platform, shutil, subprocess
from pathlib import Path
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
parser.add_argument("--source-ref", default=None)
parser.add_argument("--out", "--artifacts-dir", dest="out", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = (root / args.out).resolve()
out.mkdir(parents=True, exist_ok=False)
inputs = {}
def read(path):
    data = subprocess.check_output(["git", "show", args.source_ref + ":" + path], cwd=root) if args.source_ref else (root / path).read_bytes()
    inputs[path] = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
    return data.decode("utf-8").replace("\r\n", "\n")

def declaration(text, marker):
    start = text.index(marker)
    brace = text.index("{", start)
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{": depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0: return text[start:index+1]
    raise RuntimeError("Unbalanced source declaration " + marker)

cache = read("Source/Features/Reader/Cache/BookPageCache.swift")
models = read("Source/LibraryBackend/LibraryBackendModels.swift")
renderer = read("Source/Core/TextProcessing/ArabicTextRenderer.swift")
combined = ["import Foundation", "import Synchronization"]
for marker in ["enum BackendID:", "enum TextPosition:", "struct TextLocator:", "public struct TextDeltaEvent:"]:
    combined.append(declaration(models, marker))
combined.append(declaration(renderer, "struct HonorificReplacementEvent"))
for path in ["Source/Features/Reader/Models/BookContent.swift", "Source/Features/Reader/Models/CleanedTextKey.swift", "Source/Features/Reader/Models/ProcessedArabicContent.swift"]:
    combined.append(read(path))
if platform.system() == "Windows":
    cache = cache.replace("import OSLog\n", "")
    combined.append("struct Logger: Sendable { static let reader = Logger(); func debug(_ message: String) {} }")
else:
    combined.append("import OSLog\nextension Logger { static let reader = Logger(subsystem: \"cache-acceptance\", category: \"reader\") }")
combined.append(cache)
fixture = root / "Tests/HQ/cache/BookPageCacheAcceptance.swift"
inputs[str(fixture.relative_to(root))] = {"sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(), "bytes": fixture.stat().st_size}
combined.append(fixture.read_text(encoding="utf-8"))
source = out / "ActualCacheAcceptance.swift"
source.write_text("\n\n".join(combined), encoding="utf-8", newline="\n")
swift = shutil.which("swiftc")
if not swift: raise RuntimeError("swiftc unavailable")
binary = out / ("cache-acceptance.exe" if os.name == "nt" else "cache-acceptance")
command = [swift, "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library", str(source), "-o", str(binary)]
report = {"observed_at": datetime.now(timezone.utc).isoformat(), "source_ref": args.source_ref,
    "source_commit": subprocess.check_output(["git","rev-parse","HEAD"], cwd=root, text=True).strip(),
    "platform": platform.platform(), "inputs": inputs, "command": command,
    "generated_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "native_ui_executed": 0, "physical_device_executed": 0}
compiled = subprocess.run(command, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
(out / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
report["compile_exit"] = compiled.returncode
if compiled.returncode == 0:
    run = subprocess.run([str(binary)], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    (out / "tests.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    report["test_exit"] = run.returncode
    report["passed"] = [line[6:] for line in run.stdout.splitlines() if line.startswith("PASS: ")]
    report["failed"] = [line[6:] for line in run.stdout.splitlines() if line.startswith("FAIL: ")]
else:
    report["compile_error_tail"] = (compiled.stdout + compiled.stderr)[-7000:]
report["status"] = "PASS" if report.get("test_exit") == 0 and report["passed"] and not report["failed"] else "FAILED"
(out / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(0 if report["status"] == "PASS" else 1)
