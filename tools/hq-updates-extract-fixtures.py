"""Extract real catalog code for portable regression tests, without altering source."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
output = Path(sys.argv[1]).resolve()
allowed = (repo / "Tests/HQ/updates/.build").resolve()
if output.parent != allowed:
    raise SystemExit("Generated fixture source must remain inside the leased test build directory")
source = (repo / "Source/Features/Library/Database/Updater/BookUpdateMgr+Fetch.swift").read_text(encoding="utf-8")
models = (repo / "Source/Features/Library/Models/BookUpdateModels.swift").read_text(encoding="utf-8")
vm = (repo / "Source/Features/Library/ViewModel/BookUpdateVM.swift").read_text(encoding="utf-8")

def function(name):
    start = source.index("    func " + name + "(")
    end = source.index("\n    }", start) + len("\n    }")
    return source[start:end]

model_start = models.index("struct BookIndexEntry:")
model_end = models.index("\n}", model_start) + 2
drive = next(line.strip() for line in vm.splitlines() if "static let driveLink =" in line)
parts = ["import Foundation", models[model_start:model_end], "enum BookUpdateViewModel { " + drive + " }",
         "struct BookUpdateManager {", function("parseIndexCSV"), function("trimHeaderIfNeeded"), "}",
         source[source.index("private enum CSVParser"):]]
output.write_text("\n\n".join(parts), encoding="utf-8")
print("Extracted production catalog parser into disposable compiler input")
