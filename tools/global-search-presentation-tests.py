"""Focused Global Search orchestration checks; no Apple UI/runtime claim.

Compiles the production session and presentation policy unchanged except imports
and two untouched UI/navigation-only method regions. Engine/storage/navigation
dependencies are explicit doubles. Observation uses the real Swift runtime.
"""
from pathlib import Path
import hashlib
import subprocess
import tempfile
import os

ROOT = Path(__file__).resolve().parents[1]

def run(args, cwd):
    subprocess.run(args, cwd=cwd, check=True)

with tempfile.TemporaryDirectory(prefix="global-search-presentation-") as tmp:
    tmp = Path(tmp)
    combine = (ROOT / "Tests/HQ/search/CombineFixture.swift").read_text(encoding="utf-8")
    combine += """
extension AnyCancellable: Hashable {
    public static func == (l: AnyCancellable, r: AnyCancellable) -> Bool { l === r }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }
}
"""
    (tmp / "Combine.swift").write_text(combine, encoding="utf-8")
    run(["swiftc", "-emit-library", "-emit-module", "-module-name", "Combine", str(tmp / "Combine.swift"),
         "-o", str(tmp / ("Combine.dll" if os.name == "nt" else "libCombine.so"))], tmp)
    path = ROOT / "Source/ZayitSearch/UnifiedSearchSessionController.swift"
    session = path.read_text(encoding="utf-8").replace("import SwiftUI", "")
    # Keep all changed methods, including Sefaria Observation and actual cancellation calls.
    # Exclude only unchanged Apple/navigation mapping; tested separately by existing suites.
    start = session.index("    func searchInBook(")
    end = session.index("    func clearResults()", start)
    session = session[:start] + session[end:]
    start = session.index("    private func mapZayitHits(")
    end = session.index("    private func zayitHitID(", start)
    session = session[:start] + "    private func mapZayitHits(_ hits: [ZayitSearchHit]) -> [SearchResultItem] { [] }\n" + session[end:]
    (tmp / "UnifiedSearchSessionController.swift").write_text(session, encoding="utf-8")
    rows = (ROOT / "Source/Features/Search/iOS/SearchResultsListView.swift").read_text(encoding="utf-8")
    begin = rows.index("                    if automaticallyLoadsMore,")
    end = rows.index("\n                    }", begin) + len("\n                    }")
    predicate = rows[begin:end]
    mount = (ROOT / "Source/Features/Search/iOS/SearchModeView.swift").read_text(encoding="utf-8")
    assert 'automaticallyLoadsMore: session.resultKitabFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty' in mount
    assert 'var automaticallyLoadsMore: Bool = true' in rows
    (tmp / "RealRowPrefetch.swift").write_text("""
func realRowPrefetch(index: Int, groups: [Int], hasMore: Bool, isLoadingMore: Bool,
                     automaticallyLoadsMore: Bool, onLoadMore: (() -> Void)?) {
""" + predicate + "\n}\n", encoding="utf-8")
    print("production-session-sha256=" + hashlib.sha256(path.read_bytes()).hexdigest(), flush=True)
    # Exact existing Otzaria option/state declarations; replace only its external engine methods.
    vm = (ROOT / "Source/Otzaria/Search/OtzariaTextSearchViewModel.swift").read_text(encoding="utf-8")
    declarations = vm[vm.index('    @Published var query = ""'):vm.index("    var resultsTruncated:")]
    (tmp / "OtzariaDouble.swift").write_text("import Foundation\nimport Combine\n@MainActor final class OtzariaTextSearchViewModel: ObservableObject {\n" + declarations + """
    var searchCalls = 0; var clearCalls = 0; var pageCalls = 0
    func refreshStatus() {}
    func search() { searchCalls += 1; isSearching = true }
    func clear() { clearCalls += 1; isSearching = false; results = [] }
    func loadNextPage() { pageCalls += 1 }
}
""", encoding="utf-8")
    models = (ROOT / "Source/LibraryBackend/LibraryBackendModels.swift").read_text(encoding="utf-8")
    backend = models[models.index("enum BackendID:"):models.index("enum TextPosition:")]
    options = models[models.index("enum LibrarySearchMode:"):models.index("struct LibrarySearchHit:")]
    (tmp / "BackendModels.swift").write_text("import Foundation\n" + backend + options, encoding="utf-8")
    executable = tmp / ("presentation.exe" if os.name == "nt" else "presentation")
    sources = ["Source/ZayitSearch/UnifiedSearchScope.swift", "Source/ZayitSearch/UnifiedSearchPresentationPolicy.swift", "Source/Otzaria/Search/OtzariaSearchMode.swift",
               "Source/Otzaria/Search/OtzariaSearchModels.swift", "Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift",
               "Source/ChavrusaText/Search/UI/GlobalSearchSessionPresentation.swift",
               "Tests/HQ/global-search/GlobalSearchPresentationFixtures.swift"]
    run(["swiftc", "-swift-version", "5", "-parse-as-library", "-I", str(tmp), "-L", str(tmp), "-lCombine",
         str(tmp / "BackendModels.swift"), str(tmp / "OtzariaDouble.swift"), str(tmp / "UnifiedSearchSessionController.swift"), str(tmp / "RealRowPrefetch.swift"),
         *[str(ROOT / source) for source in sources], "-o", str(executable)], tmp)
    run([str(executable)], tmp)
    execution_path = ROOT / "Source/Features/Search/ViewModel/Extensions/Search+Execution.swift"
    execution = execution_path.read_text(encoding="utf-8")
    effective_and_page = execution[execution.index("    func effectiveBackendSearchOptions()"):execution.index("    // MARK: - Search Execution")]
    initial = execution[execution.index("    func startSearch()"):execution.index("    func handleSearchCompletion()")]
    stop = execution[execution.index("    func stopSearch()"):execution.index("    func clearResults()")]
    (tmp / "ActualSearchExecution.swift").write_text("import Foundation\nextension SearchViewModel {\n" + effective_and_page + initial + stop + "\n}\n", encoding="utf-8")
    pagination = models[models.index("struct BackendPaginationState:") if "struct BackendPaginationState:" in models else models.index("struct BackendPaginationState {"):models.index("enum LibraryBackendError:")]
    (tmp / "ActualPagination.swift").write_text("import Foundation\n" + pagination, encoding="utf-8")
    paging_binary = tmp / ("paging.exe" if os.name == "nt" else "paging")
    print("production-search-execution-sha256=" + hashlib.sha256(execution_path.read_bytes()).hexdigest(), flush=True)
    run(["swiftc", "-swift-version", "5", "-parse-as-library", str(tmp / "BackendModels.swift"),
         str(tmp / "ActualPagination.swift"), str(tmp / "ActualSearchExecution.swift"),
         str(ROOT / "Tests/HQ/global-search/GlobalSearchPagingFixtures.swift"), "-o", str(paging_binary)], tmp)
    run([str(paging_binary)], tmp)
