"""Focused portable Swift fixtures; never install dependencies or read user data."""
from pathlib import Path
import os
import subprocess
import tempfile
import time
import argparse
import hashlib

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--otzaria-baseline", help="Compile the full view model from this Git ref for an expected red regression run")
parser.add_argument("--cached-readiness-only", action="store_true", help="Run only the whole-repository readiness regression")
parser.add_argument("--cached-readiness-baseline", help="Compile the whole repository from this Git ref for an expected red manifest-witness regression")
parser.add_argument("--bootstrap-search-only", action="store_true", help="Run the exact bootstrap search method with boundary doubles; no native/FFI acceptance")
options = parser.parse_args()


def run(args, cwd):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="", flush=True)
    if result.stderr:
        print(result.stderr, end="", flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)


if options.bootstrap_search_only:
    source = (ROOT / "Source/Otzaria/Bootstrap/OtzariaNativeBootstrapAcceptanceRunner.swift").read_text(encoding="utf-8-sig")
    start = source.index("    @MainActor\n    private static func populateSearchState(")
    method = source[start:source.index("\n    private static func runDictionaryChecks()", start)]
    print("Actual leased bootstrap method SHA256: " + hashlib.sha256(method.encode()).hexdigest(), flush=True)
    with tempfile.TemporaryDirectory(prefix="otzaria-bootstrap-search-fixture-") as name:
        temp = Path(name)
        wrapper = temp / "BootstrapSearchMethod.swift"
        wrapper.write_text("import Foundation\n@MainActor enum BootstrapSearchFixtureRunner {\n" + method + "\nstatic func run(_ report: inout Report) async throws { try await populateSearchState(&report, databaseURL: URL(fileURLWithPath: \"/explicit-fixture-db\"), lexicalURL: URL(fileURLWithPath: \"/explicit-fixture-lexical\")) }\n}\n", encoding="utf-8")
        executable = temp / ("bootstrap-search.exe" if os.name == "nt" else "bootstrap-search")
        run(["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
             str(ROOT / "Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift"), str(wrapper),
             str(ROOT / "Tests/HQ/search/BootstrapSearchAcceptanceFixtures.swift"), "-o", str(executable)], temp)
        run([str(executable)], temp)
    raise SystemExit(0)


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
        "Tests/HQ/search/OtzariaViewModelFixtures.swift",
    ]
    view_model = temp / "OtzariaTextSearchViewModel.swift"
    view_model_bytes = (ROOT / "Source/Otzaria/Search/OtzariaTextSearchViewModel.swift").read_bytes()
    if options.otzaria_baseline:
        view_model_bytes = subprocess.check_output([
            "git", "show", options.otzaria_baseline + ":Source/Otzaria/Search/OtzariaTextSearchViewModel.swift"], cwd=ROOT)
        print("Otzaria full-view-model baseline: " + options.otzaria_baseline, flush=True)
    # Append a test-only same-file accessor to await the actual private task.
    # The production class and every method body compile unchanged.
    view_model.write_bytes(view_model_bytes + b"\nextension OtzariaTextSearchViewModel { var fixturePaginationTask: Task<Void, Never>? { paginationTask } }\n")
    executable = temp / ("search-fixtures.exe" if os.name == "nt" else "search-fixtures")
    started = time.monotonic()
    if not options.cached_readiness_only:
        run(["swiftc", "-swift-version", "5", "-parse-as-library", "-I", str(temp), "-L", str(temp),
             "-lCombine", str(temp / "Locator.swift"), str(temp / "Capacity.swift"), str(temp / "IndexValidation.swift"), str(temp / "HitNavigation.swift"), *[str(ROOT / p) for p in sources],
             str(view_model), "-o", str(executable)], temp)
        run([str(executable), str(ROOT)], temp)
    # Compile the whole real repository separately from the UI/view-model
    # fixture's repository double; reuse the same isolated fixture runner.
    for resource in ("dictionary.json", "Acronyms.json"):
        (temp / resource).write_text("{}", encoding="utf-8")
    cached_executable = temp / ("cached-readiness.exe" if os.name == "nt" else "cached-readiness")
    cached_sources = ["Source/Features/Search/Models/SearchResultItem.swift",
                      "Source/Otzaria/Search/OtzariaSearchMode.swift",
                      "Source/Otzaria/Search/OtzariaSearchModels.swift",
                      "Source/Otzaria/Search/OtzariaExactOccurrenceModels.swift",
                      "Source/Otzaria/Search/OtzariaTantivySearchRepository.swift",
                      "Tests/HQ/search/CachedIndexReadinessFixtures.swift"]
    cached_paths = [str(ROOT / p) for p in cached_sources]
    if options.cached_readiness_baseline:
        baseline = temp / "OtzariaTantivySearchRepository.swift"
        body = subprocess.check_output([
            "git", "show", options.cached_readiness_baseline + ":Source/Otzaria/Search/OtzariaTantivySearchRepository.swift"], cwd=ROOT)
        baseline.write_bytes(body)
        cached_paths[cached_sources.index("Source/Otzaria/Search/OtzariaTantivySearchRepository.swift")] = str(baseline)
        print("Whole repository baseline: " + options.cached_readiness_baseline + "; SHA256 " + hashlib.sha256(body).hexdigest(), flush=True)
    run(["swiftc", "-swift-version", "5", "-parse-as-library", str(temp / "Locator.swift"),
         *cached_paths, "-o", str(cached_executable)], temp)
    run([str(cached_executable)], temp)
    print(f"Portable Swift fixtures completed in {time.monotonic() - started:.2f}s")
