from pathlib import Path
import json,hashlib,sys
ROOT=Path(__file__).resolve().parent
SOURCE=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'candidate'
OUT=Path(sys.argv[2]) if len(sys.argv)>2 else ROOT/'late-load-controls'
OUT.mkdir(parents=True,exist_ok=True)
paths=['Source/LibraryBackend/QualifiedLocatorStore.swift','Source/LibraryBackend/LibraryBackendModels.swift','Source/Features/History/ViewModel/HistoryViewModel.swift','Source/Features/History/ViewModel/Extensions/History+Database.swift']
read=lambda p:(SOURCE/p).read_text()
store,models,model,database=map(read,paths)
models=models.split('/// A canonical reader destination:')[0]
clock=store[store.index('    /// Read-only provenance'):store.index('    private let publicationSource')]
entry=store[store.index('    struct HistoryEntry:'):store.index('    private let fileURL:')]
methods=model[model.index('    /// Passive provenance only.'):model.index('    func filterBooks(')]
publication=model[model.index('/// Source-owned correlation between the actual original cards'):]
load=database[database.index('    func loadBooksData() {'):database.rindex('\n}')]
assert load.endswith('\n')
# Sole harness instrumentation: completion notification in a defer. It does not
# publish model data, change source guards, await, or alter task scheduling.
traced=load.replace('        Task { [weak self] in\n','        Task { [weak self] in\n            defer { self?.fixtureLoadFinished() }\n',1)
guard='''                guard self.isCurrentQualifiedLoad(publicationLoad),
                      publicationEntries.observation?.isCurrent == true else { return }
'''
proposed=traced.replace('                guard let self else { return }\n','                guard let self else { return }\n'+guard,1)
helper='''    func isCurrentQualifiedLoad(_ load: HistoryQualifiedPublication.Load) -> Bool {
        guard let revision = load.revision else { return false }
        return qualifiedLoadRevision == revision && load.isCurrent
    }
'''
boundary=r'''
// EXPLICIT DOMAIN BOUNDARIES: a controllable actor read models permitted await
// completion order; BooksData/catalog/backend expose only original read fields.
// The actual original loadBooksData body is below, with one fixture-only defer.
actor QualifiedLocatorStore {
    static let shared=QualifiedLocatorStore()
'''+clock+entry+r'''
    private var source=PublicationSource()
    private var payloads:[[HistoryEntry]]=[]
    private var continuations:[Int:CheckedContinuation<PublishedEntries,Never>]=[:]
    private var observations:[Int:PublishedEntries]=[:]
    private var total=0
    private var arrivals:[(Int,CheckedContinuation<Void,Never>)]=[]
    func reset(_ payloads:[[HistoryEntry]]) {
        precondition(continuations.isEmpty)
        self.payloads=payloads; source=PublicationSource(); total=0; observations=[:]; arrivals=[]
    }
    func entriesWithObservation() async -> PublishedEntries {
        let index=total;total += 1
        let captured=PublishedEntries(entries:payloads[index],observation:source.capture())
        return await withCheckedContinuation { continuation in
            continuations[index]=continuation;observations[index]=captured
            let ready=arrivals.filter { $0.0 <= total };arrivals.removeAll { $0.0 <= total }
            for (_,waiter) in ready { waiter.resume() }
        }
    }
    func waitForReads(_ count:Int) async {
        if total >= count { return }
        await withCheckedContinuation { arrivals.append((count,$0)) }
    }
    func deliver(_ index:Int) {
        let continuation=continuations.removeValue(forKey:index)!
        continuation.resume(returning:observations.removeValue(forKey:index)!)
    }
    func changeOriginalStorePublication() { source.willChange() }
}
@MainActor final class BackendCoordinator {
    static let shared=BackendCoordinator()
    var activeBackendID:BackendID = .otzaria
    var generation:UInt64=1
    var activeTransitionToken:UInt64=1
    var usesNativeMaktabahDataPath=false
    var isTransitioning=false
    func reset() { activeBackendID = .otzaria;generation=1;activeTransitionToken=1
        usesNativeMaktabahDataPath=false;isTransitioning=false }
}
final class BooksData {
    let id:Int;let book:String;var backendLocator:TextLocator?
    init(id:Int,locator:TextLocator?) { self.id=id;self.backendLocator=locator;book=locator?.persistenceKey ?? "legacy:\(id)" }
}
@MainActor final class LibraryDataManager {
    static let shared=LibraryDataManager()
    func getBook(_ ids:[Int]) -> [BooksData] { ids.map { BooksData(id:$0,locator:nil) } }
}
@MainActor enum MaktabahBackendAdapter {
    static func resolveBook(for locator:TextLocator,in manager:LibraryDataManager) -> BooksData? {
        BooksData(id:Int(locator.workKey.dropFirst("book:".count))!,locator:locator)
    }
}
@MainActor final class HistoryViewModel {
    var historyOrder=[90]
    var favoriteBookIds=[91]
    var historyBooks:[BooksData]=[]
    var favoriteBooks:[BooksData]=[]
    private var finished=0
    private var waiters:[(Int,CheckedContinuation<Void,Never>)]=[]
    func fixtureLoadFinished() {
        finished += 1
        let ready=waiters.filter { $0.0 <= finished };waiters.removeAll { $0.0 <= finished }
        for (_,waiter) in ready { waiter.resume() }
    }
    func waitForFinished(_ count:Int) async {
        if finished >= count { return }
        await withCheckedContinuation { waiters.append((count,$0)) }
    }
'''+methods+helper+'\n@LOAD@\n}\n'+publication
controls=r'''
struct Failed:Error { let reason:String }
@main @MainActor struct Controls {
    static var passed=0,failed=0
    static func check(_ ok:@autoclosure () -> Bool,_ reason:String) throws {
        if !ok() { throw Failed(reason:reason) }
    }
    static func entry(_ work:Int,backend:BackendID = .otzaria,favorite:Bool=false) -> QualifiedLocatorStore.HistoryEntry {
        .init(locator:.init(backend:backend,workKey:"book:\(work)",position:.legacyLine(3)),title:"Original \(work)",lastOpened:Date(timeIntervalSince1970:1),isFavorite:favorite)
    }
    static func checkUnchanged(_ model:HistoryViewModel,_ before:[BooksData]) throws {
        try check(model.historyBooks.count==before.count && zip(model.historyBooks,before).allSatisfy { $0 === $1 },
            "obsolete result replaced original visible-model cards: \(model.historyBooks.map(\.book))")
    }
    static func test(_ name:String,_ body:() async throws -> Void) async {
        BackendCoordinator.shared.reset()
        do { try await body();passed += 1;print("PASS \(name)") }
        catch { failed += 1;print("FAIL \(name): \(error)") }
    }
    static func main() async {
        await test("current qualified load keeps original order and favorite subset") {
            await QualifiedLocatorStore.shared.reset([[entry(1),entry(2,favorite:true)]])
            let model=HistoryViewModel();model.loadBooksData()
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try check(model.historyBooks.map(\.id)==[1,2] && model.favoriteBooks.map(\.id)==[2],"current load changed original output")
        }
        await test("older async load cannot replace newer visible cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)],[entry(2,favorite:true)]])
            let model=HistoryViewModel();model.loadBooksData()
            await QualifiedLocatorStore.shared.waitForReads(1)
            model.loadBooksData();await QualifiedLocatorStore.shared.waitForReads(2)
            await QualifiedLocatorStore.shared.deliver(1);await model.waitForFinished(1)
            let before=model.historyBooks
            try check(before.map(\.id)==[2],"newer task did not publish original cards")
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(2)
            try checkUnchanged(model,before)
        }
        await test("different backend cannot consume an older actor result") {
            await QualifiedLocatorStore.shared.reset([[entry(1),entry(7,backend:.sefaria)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeBackendID = .sefaria;BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("backend A B A cannot apply old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeBackendID = .sefaria;BackendCoordinator.shared.generation += 1
            BackendCoordinator.shared.activeBackendID = .otzaria;BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("same backend resource replacement rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("aborted source transition rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeTransitionToken += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("sidecar change during pending read rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.changeOriginalStorePublication()
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("original native data-path legacy arrays remain unchanged") {
            BackendCoordinator.shared.usesNativeMaktabahDataPath=true
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        exit(failed==0 ? 0 : 1)
    }
}
'''
for name,body in [('baseline',traced),('candidate',proposed)]:
 d=OUT/name;d.mkdir(exist_ok=True)
 (d/'Controls.swift').write_text(models+'\n'+boundary.replace('@LOAD@',body)+'\n'+controls)
(OUT/'ORIGINAL_LOAD.swift').write_text(load)
(OUT/'PROPOSED_HELPER.swift').write_text(helper)
(OUT/'PROPOSED_GUARD.swift').write_text(guard)
inputs=[{'path':p,'sha256':hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()} for p in paths]
(OUT/'SOURCE_INPUTS.json').write_text(json.dumps({'base':'1330c29fd259ce74d30b3e39b2e020b60bb57700','inputs':inputs,'boundary':'Verbatim original load body plus test-only completion defer; controlled actor completion, backend, catalog and original object boundaries are explicit substitutes. No app/UIKit/native claim.'},indent=2)+'\n')
print(json.dumps({'baseline':hashlib.sha256((OUT/'baseline/Controls.swift').read_bytes()).hexdigest(),'candidate':hashlib.sha256((OUT/'candidate/Controls.swift').read_bytes()).hexdigest(),'inputs':inputs}))
