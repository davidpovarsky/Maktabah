#!/usr/bin/env python3
"""Compile actual portable sources; extract only the real width policy."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
original = (root / "Scripts/run-chavrusa-component-tests.sh").read_text(encoding="utf-8")
sources = [value for value in re.findall(r'\$\{REPO_ROOT\}/([^"\r\n]+\.swift)', original)
           if value != "tools/test_chavrusa_text_components.swift"]
sources += ["Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift"]
layout = (root / "Source/ChavrusaText/ReaderHost/ChavrusaReaderWorkspaceLayout.swift").read_text(encoding="utf-8")
policy = layout[layout.index("enum ChavrusaReaderWorkspaceWidthPolicy"):layout.index("/// The original workspace")]
with tempfile.TemporaryDirectory(prefix="strict-10601-") as directory:
    temp = Path(directory)
    width = temp / "WidthPolicy.swift"
    width.write_text("import Foundation\n" + policy, encoding="utf-8")
    tabs = temp / "TabsBarLayout.swift"
    tabs.write_text((root / "Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/TabsBarLayout.swift")
                    .read_text(encoding="utf-8").replace("import CoreGraphics", "import Foundation"), encoding="utf-8")
    executable = temp / ("strict.exe" if os.name == "nt" else "strict")
    commands = [
        ["swiftc", "-parse-as-library", *[str(root / path) for path in sources], str(width), str(tabs),
         str(root / "tools/test_strict_10601_repairs.swift"), "-o", str(executable)],
        [str(executable)],
    ]
    artifacts = root / "build/artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    for name, command in zip(["strict-10601-compile.log", "strict-10601-tests.log"], commands):
        result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (artifacts / name).write_text(result.stdout, encoding="utf-8")
        print(result.stdout, end="", flush=True)
        result.check_returncode()
