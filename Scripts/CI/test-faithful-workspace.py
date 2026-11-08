#!/usr/bin/env python3
"""Compile the actual shared state sources and run persistence contracts."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
original = (root / "Scripts/run-chavrusa-component-tests.sh").read_text(encoding="utf-8")
sources = [value for value in re.findall(r'\$\{REPO_ROOT\}/([^"\r\n]+\.swift)', original)
           if value != "tools/test_chavrusa_text_components.swift"]
sources += ["Source/ChavrusaText/ReaderHost/ReaderNavigationChromeState.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceLegacyImport.swift",
            "Source/ChavrusaText/Navigation/ReaderNavigationDisplayPolicy.swift",
            "tools/test_faithful_study_workspace.swift"]
artifacts = root / "build/artifacts"
artifacts.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="faithful-workspace-tests-") as directory:
    executable = Path(directory) / ("workspace-tests.exe" if os.name == "nt" else "workspace-tests")
    for name, command in [
        ("workspace-compile.log", ["swiftc", "-whole-module-optimization", "-parse-as-library", *[str(root / path) for path in sources], "-o", str(executable)]),
        ("workspace-test-results.log", [str(executable)]),
    ]:
        result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        (artifacts / name).write_text(result.stdout, encoding="utf-8")
        print(result.stdout, end="", flush=True)
        result.check_returncode()
