"""Focused portable Swift fixtures; never install dependencies or read user data."""
from pathlib import Path
import os
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def run(args, cwd):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="", flush=True)
    if result.stderr:
        print(result.stderr, end="", flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)


with tempfile.TemporaryDirectory(prefix="otzaria-search-fixture-") as name:
    temp = Path(name)
    suffix = ".dll" if os.name == "nt" else ".so"
    run(["swiftc", "-emit-library", "-emit-module", "-module-name", "Combine",
         str(ROOT / "Tests/HQ/search/CombineFixture.swift"),
         "-o", str(temp / ("Combine" + suffix))], temp)
    # Copy only the existing portable locator declarations, with test backend IDs.
    models = (ROOT / "Source/LibraryBackend/LibraryBackendModels.swift").read_text(encoding="utf-8-sig")
    locator = models[models.index("enum TextPosition:"):models.index("/// A canonical reader destination:")]
    (temp / "Locator.swift").write_text(
        "import Foundation\nenum BackendID: String, Codable, Sendable { case otzaria, sefaria, maktabah }\n" + locator,
        encoding="utf-8")
    manager = (ROOT / "Source/Otzaria/Search/OtzariaSearchIndexManager.swift").read_text(encoding="utf-8-sig")
    validation = manager[manager.index("    func isIndexCurrent("):manager.index("    func compatibility(")]
    (temp / "IndexValidation.swift").write_text("import Foundation\nextension FixtureIndexValidator {\n" + validation + "}\n", encoding="utf-8")
    bootstrap = (ROOT / "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift").read_text(encoding="utf-8-sig")
    capacity = bootstrap[bootstrap.index("struct OtzariaStorageCapacityFailure:"):bootstrap.index("enum OtzariaStorageErrorNormalizer {")]
    (temp / "Capacity.swift").write_text("import Foundation\n" + capacity, encoding="utf-8")
    unified = (ROOT / "Source/ZayitSearch/UnifiedSearchSessionController.swift").read_text(encoding="utf-8-sig")
    navigation = unified[unified.index('        if item.archive == "Zayit" {'):unified.index("        if let book = resolveBook(from: item) {", unified.index("    func openResult("))]
    (temp / "HitNavigation.swift").write_text(
        "import Foundation\n@MainActor extension FixtureHitNavigation {\n"
        "func openResult(_ item: SearchResultItem, using manager: iOSNavigationManager) {\n" + navigation + "}\n}\n",
        encoding="utf-8")
    sources = [
        "Source/Features/Search/Models/SearchResultItem.swift",
        "Source/Otzaria/Search/OtzariaSearchMode.swift",
        "Source/Otzaria/Search/OtzariaSearchModels.swift",
        "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift",
        "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift",
        "Source/ZayitSearch/UnifiedSearchPresentationPolicy.swift",
        "Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift",
        "Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift",
        "Source/ZayitSearch/ZayitSearchSessionController.swift",
        "Tests/HQ/search/SearchFixtures.swift",
    ]
    executable = temp / ("search-fixtures.exe" if os.name == "nt" else "search-fixtures")
    started = time.monotonic()
    run(["swiftc", "-swift-version", "5", "-parse-as-library", "-I", str(temp), "-L", str(temp),
         "-lCombine", str(temp / "Locator.swift"), str(temp / "Capacity.swift"), str(temp / "IndexValidation.swift"), str(temp / "HitNavigation.swift"), *[str(ROOT / p) for p in sources],
         "-o", str(executable)], temp)
    run([str(executable), str(ROOT)], temp)
    print(f"Portable Swift fixtures completed in {time.monotonic() - started:.2f}s")
