#!/usr/bin/env python3
"""Execute exact feature flag/lifecycle source against explicit effect doubles."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
LIFECYCLE = Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift")

def block(text, marker):
    start = text.index("{", text.index(marker))
    depth = 1
    end = start + 1
    while depth:
        if text[end] == "{": depth += 1
        elif text[end] == "}": depth -= 1
        end += 1
    return text[start + 1:end - 1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-ref")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    raw = (subprocess.check_output(["git", "show", args.source_ref + ":" + LIFECYCLE.as_posix()], cwd=ROOT)
           if args.source_ref else (ROOT / LIFECYCLE).read_bytes())
    text = raw.decode().replace("\r\n", "\n")
    life = "struct Exact9401WorkspaceLifecycle {" + block(text, "struct Exact9401WorkspaceLifecycle") + "}"
    flag = "enum ChavrusaTextReaderUI {" + block(text, "enum ChavrusaTextReaderUI") + "}"
    workspace = block(life, "private var workspace:")
    task = block(life, ".task(id: sceneID)")
    if "private var routingWorkspaceOwner:" in life:
        exposed = block(life, "private var routingWorkspaceOwner:")
    else:
        marker = ".environment(\\.maktabahNativeWorkspaceOwner, "
        start = life.index(marker) + len(marker)
        exposed = "return " + life[start:life.index(")\n", start)]
    background = block(life, ".background")
    condition = background[background.index("if ") + 3:background.index("{")].strip()
    tabs = block(life, ".onChange(of: manager.openTabs.map").split(" in ", 1)[1]
    template = (ROOT / "tools/test_reader_feature_off_lifecycle.swift").read_text(encoding="utf-8")
    generated = (template.replace("// FLAG_SOURCE", flag).replace("// WORKSPACE_SOURCE", workspace)
                 .replace("// OWNER_SOURCE", exposed).replace("// TASK_SOURCE", task)
                 .replace("// OBSERVER_CONDITION", "return " + condition)
                 .replace("// TABS_CALLBACK_SOURCE", tabs))
    source = args.out / "ExactFeatureOffLifecycle.swift"
    source.write_text(generated, encoding="utf-8")
    executable = args.out / ("feature-off.exe" if os.name == "nt" else "feature-off")
    swift = os.environ.get("OTZARIA_TEST_SWIFTC", "swiftc")
    command = [swift, "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
               str(source), "-o", str(executable)]
    compiled = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=120)
    (args.out / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
    report = {"source_ref": args.source_ref, "source_path": LIFECYCLE.as_posix(),
              "source_raw_sha256": hashlib.sha256(raw).hexdigest(),
              "source_lf_sha256": hashlib.sha256(text.encode()).hexdigest(),
              "fixture_sha256": hashlib.sha256(template.encode()).hexdigest(),
              "generated_sha256": hashlib.sha256(generated.encode()).hexdigest(),
              "compile_exit": compiled.returncode, "command": command,
              "native_ui_executed": 0, "apple_sdk_typecheck": "NOT_RUN",
              "boundary": "Actual Foundation/UserDefaults flag and exact original lifecycle/task/getter/callback expressions; explicit platform, manager, adapter and store effect doubles writing only an owned temporary file. No SwiftUI rendering, original workspace store, Apple SDK or Native acceptance."}
    code = compiled.returncode
    if code == 0:
        ran = subprocess.run([str(executable)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
        (args.out / "tests.log").write_text(ran.stdout + ran.stderr, encoding="utf-8")
        report["execute_exit"] = ran.returncode
        code = ran.returncode
        try:
            report["actual"] = json.loads(ran.stdout)
            if report["actual"].get("failed", 0): code = 1
        except json.JSONDecodeError: report["output"] = ran.stdout + ran.stderr
    (args.out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in report.items() if k not in ["command"]}, ensure_ascii=False))
    raise SystemExit(code)

if __name__ == "__main__":
    main()
