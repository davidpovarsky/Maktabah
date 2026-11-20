#!/usr/bin/env python3
"""Execute original normal-iOS Bash capture helpers with explicit OS tool doubles.

This proves shell control flow and byte preservation only. simctl, IDB, sips and
BSD stat are boundary doubles; no Apple SDK, simulator or UI is executed here.
The real acceptance script must keep its original Native gates on Apple.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time
import unittest
import zlib

BOUNDARY = r'''
import json, os, pathlib, shutil, struct, sys, zlib
tool, args = sys.argv[1], sys.argv[2:]
with open(os.environ["CAPTURE_TEST_CALLS"], "a", encoding="utf-8") as f:
 f.write(json.dumps({"tool":tool,"args":args})+"\n")
def png(w,h):
 def chunk(kind,payload):
  return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
 data=(b"\0"+b"\x32\x64\x96\xff"*w)*h
 return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(data,0))+chunk(b"IEND",b"")
if tool=="xcrun":
 if args[:2]==["simctl","io"] and len(args)==5 and args[3]=="screenshot":
  if os.environ.get("CAPTURE_TEST_FAIL_CAPTURE")=="1": sys.exit(37)
  shutil.copyfile(os.environ["CAPTURE_TEST_RAW"],args[4])
 elif args[:2]==["simctl","launch"]:
  print("fixture.application: 1234")
 elif args[:2]!=["simctl","terminate"]:
  raise RuntimeError("unexpected simctl boundary")
elif tool=="idb":
 if args[:2]==["ui","rotate"]:
  if os.environ.get("CAPTURE_TEST_FAIL_ROTATE")=="1": sys.exit(38)
 elif args[:2]==["ui","describe-all"]:
  print("[]")
 else: raise RuntimeError("unexpected IDB boundary")
elif tool=="stat":
 assert args[:2]==["-f","%z"]
 print(pathlib.Path(args[2]).stat().st_size)
elif tool=="sips":
 if args[0]=="-g":
  data=pathlib.Path(args[2]).read_bytes()
  if data[:8]!=b"\x89PNG\r\n\x1a\n" or len(data)<24: sys.exit(39)
  w,h=struct.unpack(">II",data[16:24])
  assert args[1] in ("pixelWidth","pixelHeight")
  print(args[1]+": "+str(w if args[1]=="pixelWidth" else h))
 elif args[0]=="-r":
  # Explicit geometry-only model of the historical external rotation command.
  # This is not macOS sips and is never used on an authentic captured image.
  assert args[3]=="--out"
  data=pathlib.Path(args[2]).read_bytes()
  w,h=struct.unpack(">II",data[16:24])
  degrees=int(args[1])
  assert degrees in (90,-90,180)
  if abs(degrees)==90: w,h=h,w
  pathlib.Path(args[4]).write_bytes(png(w,h))
 else: raise RuntimeError("unexpected sips boundary")
else: raise RuntimeError("unknown external boundary")
'''

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def png(width: int, height: int) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))
    pixels = (b"\0" + b"\x32\x64\x96\xff" * width) * height
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels, 0)) + chunk(b"IEND", b""))

def function(source: str, name: str, required: bool = True) -> str:
    found = re.search(r"^" + re.escape(name) + r"\(\) \{\n.*?^\}\n",
                      source, re.MULTILINE | re.DOTALL)
    if found is None:
        if required:
            raise AssertionError("missing original helper " + name)
        return ""
    return found.group(0)

def quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"

class CaptureTests(unittest.TestCase):
    source: str
    source_path: Path
    evidence: Path
    bash: str
    records: list[dict] = []

    def setUp(self):
        self.case = self.evidence / self._testMethodName
        self.case.mkdir()
        self.raw = png(150, 100)
        self.calls_path = self.case / "calls.jsonl"

    def run_shell(self, body: str, raw: bytes | None = None,
                  environment: dict[str, str] | None = None,
                  existing: bytes | None = None):
        raw = self.raw if raw is None else raw
        raw_path = self.case / "simulator-boundary-original.png"
        raw_path.write_bytes(raw)
        output = self.case / "capture.png"
        if existing is not None:
            output.write_bytes(existing)
        boundary = self.case / "boundary.py"
        boundary.write_text(BOUNDARY, encoding="utf-8", newline="\n")
        extracted = "\n".join(function(self.source, n, n != "normalize_screenshot_orientation")
                              for n in ("capture_current_ui", "capture_screen",
                                        "rotate_simulator", "normalize_screenshot_orientation",
                                        "require_screenshot"))
        shell = "set -euo pipefail\n" + r'''
xcrun() { "$CAPTURE_TEST_PYTHON" "$CAPTURE_TEST_BOUNDARY" xcrun "$@"; }
idb() { "$CAPTURE_TEST_PYTHON" "$CAPTURE_TEST_BOUNDARY" idb "$@"; }
sips() { "$CAPTURE_TEST_PYTHON" "$CAPTURE_TEST_BOUNDARY" sips "$@"; }
stat() { "$CAPTURE_TEST_PYTHON" "$CAPTURE_TEST_BOUNDARY" stat "$@"; }
sleep() { :; }
''' + "\n".join([
            "UDID=fixture-simulator",
            "BUNDLE_ID=fixture.application",
            "SCREENSHOT_DIR=" + quote(self.case.as_posix()),
            "REPORT_DIR=" + quote(self.case.as_posix()),
            "CURRENT_ORIENTATION=landscapeLeft",
        ]) + "\n" + extracted + "\n" + body + "\n"
        shell_path = self.case / "original-helpers.sh"
        shell_path.write_text(shell, encoding="utf-8", newline="\n")
        env = dict(os.environ)
        env.update({
            "CAPTURE_TEST_PYTHON": Path(sys.executable).as_posix(),
            "CAPTURE_TEST_BOUNDARY": boundary.as_posix(),
            "CAPTURE_TEST_CALLS": self.calls_path.as_posix(),
            "CAPTURE_TEST_RAW": raw_path.as_posix(),
        })
        env.update(environment or {})
        start = time.monotonic()
        result = subprocess.run([self.bash, shell_path.as_posix()], env=env,
                                capture_output=True, timeout=15)
        (self.case / "stdout.log").write_bytes(result.stdout)
        (self.case / "stderr.log").write_bytes(result.stderr)
        calls = ([json.loads(line) for line in self.calls_path.read_text().splitlines()]
                 if self.calls_path.exists() else [])
        observed = {
            "case": self._testMethodName, "returnCode": result.returncode,
            "elapsedSeconds": time.monotonic() - start,
            "originalSourceSHA256": digest(self.source_path.read_bytes()),
            "extractedHelpersSHA256": digest(extracted.encode()),
            "rawInputSHA256": digest(raw),
            "rawInputUnchanged": raw_path.read_bytes() == raw,
            "capturedSHA256": digest(output.read_bytes()) if output.exists() else None,
            "calls": calls,
        }
        (self.case / "OBSERVED.json").write_text(json.dumps(observed, indent=2) + "\n")
        self.assertTrue(observed["rawInputUnchanged"])
        return result, output, calls

    def phase_zero(self) -> str:
        start = self.source.index('echo "=== [PHASE 0: Interface Orientation Probe] ==="')
        end = self.source.index("# PHASE 1:", start)
        # Keep the complete original phase, stopping before the next phase comment.
        return self.source[start:end].rsplit("# ==============================================================================", 1)[0]

    def test_phase_zero_accepts_unmodified_landscape(self):
        result, _, _ = self.run_shell(self.phase_zero())
        self.assertEqual(result.returncode, 0)

    def test_phase_zero_rejects_original_portrait(self):
        result, _, _ = self.run_shell(self.phase_zero(), raw=png(100, 150))
        self.assertNotEqual(result.returncode, 0)

    def test_phase_zero_preserves_exact_capture_bytes(self):
        _, _, _ = self.run_shell(self.phase_zero())
        observed = self.case / "orientation-probe-landscape.png"
        self.assertEqual(observed.read_bytes(), self.raw)

    def test_phase_zero_propagates_capture_failure(self):
        result, _, calls = self.run_shell(
            self.phase_zero(), environment={"CAPTURE_TEST_FAIL_CAPTURE": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.case / "orientation-probe-landscape.png").exists())
        self.assertFalse(any(c["tool"] == "sips" for c in calls))

    def test_phase_zero_propagates_rotation_failure(self):
        result, _, calls = self.run_shell(
            self.phase_zero(), environment={"CAPTURE_TEST_FAIL_ROTATE": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c["tool"] == "xcrun" and "screenshot" in c["args"]
                             for c in calls))

    def test_current_capture_preserves_landscape_and_ax_collection(self):
        result, output, calls = self.run_shell("capture_current_ui capture.png")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(output.read_bytes(), self.raw)
        self.assertTrue(any(c["tool"] == "idb" and c["args"][:2] == ["ui", "describe-all"]
                            for c in calls))

    def test_current_capture_preserves_portrait(self):
        raw = png(100, 150)
        result, output, _ = self.run_shell(
            "CURRENT_ORIENTATION=portrait\ncapture_current_ui capture.png", raw=raw)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(output.read_bytes(), raw)

    def test_bootstrap_capture_preserves_landscape(self):
        result, output, _ = self.run_shell("capture_screen capture.png en en_US")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(output.read_bytes(), self.raw)

    def test_required_landscape_accepts_landscape(self):
        result, _, _ = self.run_shell("require_screenshot capture.png landscape", existing=self.raw)
        self.assertEqual(result.returncode, 0)

    def test_required_portrait_accepts_portrait(self):
        result, _, _ = self.run_shell(
            "require_screenshot capture.png portrait", existing=png(100, 150))
        self.assertEqual(result.returncode, 0)

    def test_required_landscape_rejects_portrait(self):
        result, _, _ = self.run_shell(
            "require_screenshot capture.png landscape", existing=png(100, 150))
        self.assertNotEqual(result.returncode, 0)

    def test_required_portrait_rejects_landscape(self):
        result, _, _ = self.run_shell("require_screenshot capture.png portrait", existing=self.raw)
        self.assertNotEqual(result.returncode, 0)

    def test_required_landscape_rejects_square(self):
        result, _, _ = self.run_shell(
            "require_screenshot capture.png landscape", existing=png(120, 120))
        self.assertNotEqual(result.returncode, 0)

    def test_required_portrait_rejects_square(self):
        result, _, _ = self.run_shell(
            "require_screenshot capture.png portrait", existing=png(120, 120))
        self.assertNotEqual(result.returncode, 0)

    def test_required_missing_capture_rejected(self):
        result, _, _ = self.run_shell("require_screenshot capture.png landscape")
        self.assertNotEqual(result.returncode, 0)

    def test_required_small_capture_rejected(self):
        result, _, _ = self.run_shell("require_screenshot capture.png landscape", existing=b"x")
        self.assertNotEqual(result.returncode, 0)

    def test_required_malformed_capture_rejected(self):
        result, _, _ = self.run_shell(
            "require_screenshot capture.png landscape", existing=b"x" * 12000)
        self.assertNotEqual(result.returncode, 0)

    def check_rotation(self, orientation: str, expected: str):
        result, _, calls = self.run_shell("rotate_simulator " + orientation)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [{
            "tool": "idb", "args": ["ui", "rotate", expected, "--udid", "fixture-simulator"]
        }])

    def test_actual_idb_landscape_left_command_preserved(self):
        self.check_rotation("landscapeLeft", "LANDSCAPE_LEFT")

    def test_actual_idb_landscape_right_command_preserved(self):
        self.check_rotation("landscapeRight", "LANDSCAPE_RIGHT")

    def test_actual_idb_portrait_command_preserved(self):
        self.check_rotation("portrait", "PORTRAIT")

    def test_actual_idb_upside_down_command_preserved(self):
        self.check_rotation("portraitUpsideDown", "PORTRAIT_UPSIDE_DOWN")

    def test_unsupported_rotation_fails_before_idb(self):
        result, _, calls = self.run_shell("rotate_simulator unsupported")
        self.assertEqual(result.returncode, 64)
        self.assertEqual(calls, [])

    def test_source_has_no_pixel_orientation_rewrite(self):
        self.assertFalse(re.search(r"\bsips\s+-r\b", self.source), "source still rotates captured pixels")
        self.assertFalse("normalize_screenshot_orientation" in self.source, "source still normalizes captured orientation")

class RecordingResult(unittest.TextTestResult):
    outcomes: list[dict]
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.outcomes = []
    def addSuccess(self, test):
        self.outcomes.append({"case": test._testMethodName, "result": "PASS"})
        super().addSuccess(test)
    def addFailure(self, test, err):
        self.outcomes.append({"case": test._testMethodName, "result": "FAIL"})
        super().addFailure(test, err)
    def addError(self, test, err):
        self.outcomes.append({"case": test._testMethodName, "result": "ERROR"})
        super().addError(test, err)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] /
                        "run-ipad-simulator-acceptance.sh")
    parser.add_argument("--evidence-dir", type=Path, required=True)
    args = parser.parse_args()
    args.evidence_dir.mkdir(parents=True, exist_ok=False)
    bash = (r"C:\Program Files\Git\bin\bash.exe" if os.name == "nt"
            else shutil.which("bash"))
    if not bash or not Path(bash).exists():
        raise RuntimeError("Bash is required; no declaration-only fallback")
    CaptureTests.source_path = args.source.resolve()
    CaptureTests.source = args.source.read_text(encoding="utf-8")
    CaptureTests.evidence = args.evidence_dir.resolve()
    CaptureTests.bash = bash
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CaptureTests)
    expected = suite.countTestCases()
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(suite)
    report = {
        "status": "PASS_PORTABLE_SHELL_ONLY" if result.wasSuccessful() else "FAIL",
        "sourcePath": str(CaptureTests.source_path),
        "sourceSHA256": digest(CaptureTests.source_path.read_bytes()),
        "testDriverSHA256": digest(Path(__file__).read_bytes()),
        "expected": expected, "executed": result.testsRun,
        "passed": len([c for c in result.outcomes if c["result"] == "PASS"]),
        "failed": len(result.failures), "errors": len(result.errors),
        "skipped": len(result.skipped), "cases": result.outcomes,
        "boundary": "Original extracted Bash functions and PHASE0; explicit simctl/IDB/sips/BSD-stat doubles. No Apple SDK, Native UI or actual sips execution.",
        "nativeUIExecuted": 0, "appleSDKExecuted": 0,
    }
    (args.evidence_dir / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n",
                                                  encoding="utf-8")
    print(json.dumps(report))
    return 0 if result.wasSuccessful() and result.testsRun == expected else 1

if __name__ == "__main__":
    raise SystemExit(main())
