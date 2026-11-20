#!/usr/bin/env python3
"""Exact note-owner/callback lifecycle tests with explicit UIKit/SwiftUI doubles.

This is source-bound portable regression evidence, never native sheet evidence.
--source-ref runs the same behavioral controls on the preserved original source.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BINDINGS = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
SESSION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift"
WORKSPACE = "Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift"
FIXTURE = "Tests/HQ/navigation/NativeNoteEditorOwnerFixtures.swift"
parser = argparse.ArgumentParser()
parser.add_argument("--source-ref")
parser.add_argument("--artifacts-dir", type=Path, required=True)
args = parser.parse_args()
output = args.artifacts_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    raise SystemExit("Retain prior evidence; use an empty artifacts directory")

def read_source(path):
    return (subprocess.check_output(["git", "show", args.source_ref + ":" + path], cwd=ROOT)
            if args.source_ref else (ROOT / path).read_bytes())

def method(text, signature):
    start = text.index(signature)
    opening = text.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        if text[end] == "{": depth += 1
        elif text[end] == "}": depth -= 1
        end += 1
    return text[start:end]

raw = {path: read_source(path) for path in (BINDINGS, SESSION, WORKSPACE)}
source = {path: value.decode("utf-8") for path, value in raw.items()}
owner_start = source[BINDINGS].index("@MainActor final class MaktabahNativeNoteEditorOwner {")
owner_end = source[BINDINGS].index("\n/// Retain a proven original", owner_start)
owner = source[BINDINGS][owner_start:owner_end]
callback = method(source[SESSION], "    func noteEditorTextViewChanged(")
bound = "presentationID: UUID" in callback
if bound:
    setter = method(source[WORKSPACE], "    private func setEditingAnnotation(")
    # Access is widened only in the explicit workspace double so the test can
    # drive the same original setter; its entire implementation stays exact.
    setter = setter.replace("    private func ", "    func ", 1)
else:
    setter = "    func setEditingAnnotation(_ value: Annotation?) { editingAnnotation = value }"

fixture = (ROOT / FIXTURE).read_text(encoding="utf-8")
unit_text = fixture
for marker, actual in (("// ACTUAL_NOTE_OWNER", owner), ("// ACTUAL_SCENE_CALLBACK", callback),
                      ("// ACTUAL_WORKSPACE_SETTER", setter)):
    assert unit_text.count(marker) == 1
    unit_text = unit_text.replace(marker, actual)
unit = output / "ExactNoteEditorOwner.swift"
unit.write_bytes(unit_text.encode("utf-8"))
exe = output / ("note-editor-owner.exe" if os.name == "nt" else "note-editor-owner")
compiler = shutil.which("swiftc")
if not compiler: raise SystemExit("swiftc is required")
command = [compiler, "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library"]
if bound: command += ["-D", "BOUND_PRESENTATION"]
command += [str(unit), "-o", str(exe)]
build = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=120)
(output / "compile.log").write_bytes((build.stdout + build.stderr).encode("utf-8"))
run = None
if build.returncode == 0:
    run = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", timeout=30)
    (output / "tests.log").write_bytes((run.stdout + run.stderr).encode("utf-8"))
passed = re.findall(r"^PASS (.+)$", run.stdout, re.M) if run else []
failed = re.findall(r"^FAIL (.+)$", run.stdout, re.M) if run else []
integration_checks = {
    "presentation_argument_is_bound": bound,
    "workspace_has_one_original_annotation_assignment": len(re.findall(r"\beditingAnnotation\s*=(?!=)", source[WORKSPACE])) == 1,
    "callback_captures_presentation_before_async_creation":
        "let presentationID = nativeNoteEditorPresentationID" in source[WORKSPACE]
        and "presentationID: presentationID, textView: textView" in source[WORKSPACE],
    "owner_reads_live_presentation_id": "presentationID: { nativeNoteEditorPresentationID }" in source[WORKSPACE],
    "original_binding_uses_actual_setter": "set: { setEditingAnnotation($0) }" in source[WORKSPACE],
}
code = build.returncode or (run.returncode if run else 1)
if len(passed) != 13 or failed or (bound and not all(integration_checks.values())): code = 1
report = {
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source_ref": args.source_ref or "WORKTREE",
    "source_commit": subprocess.check_output(["git", "rev-parse", args.source_ref or "HEAD"], cwd=ROOT, text=True).strip(),
    "source_files": {path: hashlib.sha256(value).hexdigest() for path, value in raw.items()},
    "extracted_owner_sha256": hashlib.sha256(owner.encode()).hexdigest(),
    "extracted_callback_sha256": hashlib.sha256(callback.encode()).hexdigest(),
    "compiled_setter_sha256": hashlib.sha256(setter.encode()).hexdigest(),
    "fixture_sha256": hashlib.sha256(fixture.encode()).hexdigest(),
    "driver_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "generated_unit_sha256": hashlib.sha256(unit.read_bytes()).hexdigest(),
    "command": command, "compiler": subprocess.check_output([compiler, "--version"], text=True).strip(),
    "compile_exit": build.returncode, "warnings": build.stderr.count("warning:"),
    "test_exit": run.returncode if run else None, "passed": passed, "failed": failed,
    "integration_source_checks": integration_checks,
    "status": "PASS" if code == 0 else "FAIL", "native_passes": 0,
    "boundary": "Exact original app owner and callback, plus candidate workspace setter (private widened only in the fixture). Real Swift 6/MainActor execution; explicit UIKit, SwiftUI Binding, Reader, Annotation and scene revision doubles. Historical API adapter passes no presentation identity to original source. No native UIKit lifecycle scheduling, presentation, visibility, persistence, Core or device acceptance.",
}
(output / "RESULT.json").write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(code)
