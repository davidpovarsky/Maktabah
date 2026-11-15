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
author_start = models.index("struct AuthIndexEntry:")
author_end = models.index("\n}", author_start) + 2
drive = next(line.strip() for line in vm.splitlines() if "static let driveLink =" in line)
parts = ["import Foundation", models[model_start:model_end], models[author_start:author_end], "enum BookUpdateViewModel { " + drive + " }",
         "struct BookUpdateManager {", function("parseIndexCSV"), function("parseAuthIndexCSV"), function("trimHeaderIfNeeded"), "}",
         source[source.index("private enum CSVParser"):]]
output.write_text("\n\n".join(parts), encoding="utf-8")
print("Extracted production catalog parser into disposable compiler input")

manager = (repo / "Source/Features/Library/Database/Updater/BookUpdateManager.swift").read_text(encoding="utf-8")
def manager_function(name):
    start = manager.index("    func " + name + "(")
    end = manager.index("\n    }", start) + len("\n    }")
    return manager[start:end]

fetch_start = source.index("    private func fetchCSVString(")
fetch_end = source.index("\n    }", fetch_start) + len("\n    }")
entries = ["import Foundation", "#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif",
           "extension BookUpdateManager {", manager_function("downloadFile"), manager_function("cleanupWorkingDirectory"),
           manager_function("makeWorkingDirectory"), source[fetch_start:fetch_end].replace("private func", "func", 1), "}"]
(allowed / "ProductionEntryPoints.swift").write_text("\n\n".join(entries), encoding="utf-8")
print("Extracted production network/staging/cleanup entries (only fetch access widened for tests)")
backend = (repo / "Source/LibraryBackend/LibraryBackendModels.swift").read_text(encoding="utf-8")
backend_start = backend.index("enum BackendID:")
backend_end = backend.index("\n}", backend_start) + 2
(allowed / "ProductionBackendID.swift").write_text("import Foundation\n" + backend[backend_start:backend_end], encoding="utf-8")
print("Extracted actual product BackendID for exhaustive availability checks")
