from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parent
SOURCE=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'candidate'
OUT=Path(sys.argv[2]) if len(sys.argv)>2 else ROOT/'publication-controls'
OUT.mkdir(exist_ok=True)
paths=['Source/LibraryBackend/QualifiedLocatorStore.swift','Source/LibraryBackend/LibraryBackendModels.swift','Source/Features/History/ViewModel/HistoryViewModel.swift','Source/Features/History/ViewModel/Extensions/History+Database.swift']
read=lambda p:(SOURCE/p).read_text()
store=read(paths[0])
models=read(paths[1]).split('/// A canonical reader destination:')[0]
model=read(paths[2])
methods=model[model.index('    /// Passive provenance only.'):model.index('    func filterBooks(')]
publication=model[model.index('/// Source-owned correlation between the actual original cards'):]
boundary='''
// Explicit domain boundary: original backend publisher and BooksData are
// represented only by fields read by the verbatim publication implementation.
// No UIKit, Observation, app/Core or saved-reader acceptance is asserted.
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 1
    var activeTransitionToken: UInt64 = 1
    var usesNativeMaktabahDataPath = false
    var isTransitioning = false
    func reset() { activeBackendID = .otzaria; generation = 1; activeTransitionToken = 1
        usesNativeMaktabahDataPath = false; isTransitioning = false }
}
final class BooksData {
    let id: Int
    var backendLocator: TextLocator?
    init(id: Int, locator: TextLocator?) { self.id=id; backendLocator=locator }
}
@MainActor final class HistoryViewModel {
    var historyBooks: [BooksData] = []
    var favoriteBooks: [BooksData] = []
'''+methods+'\n}\n'
controls=r'''
// Test-only same-file access exercises metadata exhaustion, never app state.
extension QualifiedLocatorStore.PublicationSource {
    func testRevision(_ value: UInt64?) { lock.lock(); defer { lock.unlock() }; revision=value }
}
extension HistoryViewModel { func testLoadRevision(_ value: UInt64?) { qualifiedLoadRevision=value } }

struct ControlFailure: Error { let message: String }
@main @MainActor struct Controls {
    static var passed=0, failed=0
    static let base=URL(fileURLWithPath: CommandLine.arguments[1], isDirectory:true)
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ControlFailure(message:message) }
    }
    static func test(_ name:String, _ body: () async throws -> Void) async {
        BackendCoordinator.shared.reset()
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    static func locator(_ line:Int=3, backend:BackendID = .otzaria) -> TextLocator {
        .init(backend:backend,workKey:"book:3891",position:.legacyLine(line))
    }
    static func newStore() -> QualifiedLocatorStore {
        .init(fileURL:base.appendingPathComponent("record-\(UUID()).json"))
    }
    static func fixture(favorite:Bool=false) async throws -> (QualifiedLocatorStore,HistoryViewModel,HistoryQualifiedPublication.Load,QualifiedLocatorStore.PublishedEntries) {
        let store=newStore(), model=HistoryViewModel()
        let load=model.beginQualifiedPublication()
        if favorite { try await store.setFavorite(true,locator:locator(),title:"Original") }
        else { try await store.record(locator(),title:"Original") }
        let entries=await store.entriesWithObservation()
        model.historyBooks=[BooksData(id:3891,locator:locator())]
        if favorite { model.favoriteBooks=[BooksData(id:3891,locator:locator())] }
        model.completeQualifiedPublication(load,entries:entries)
        try check(model.qualifiedPublication?.isCurrent(in:model)==true,"fixture publication unavailable")
        return (store,model,load,entries)
    }
    static func mutation(_ body:() async throws -> Void) async {
        // Tokens must retire BEFORE mutation, including original persistence
        // failure. We report any actual Foundation I/O error separately.
        do { try await body() } catch { print("OBSERVED original persistence error: \(error)") }
    }
    static func main() async {
        do { try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true) }
        catch { print("HARNESS_SETUP_FAILURE \(error)"); exit(2) }
        await test("same actor entries and exact published objects") {
            let (store,model,_,entries)=try await fixture(favorite:true)
            let ordinary=await store.entries()
            try check(ordinary==entries.entries,"observed entries differ from original read")
            try check(model.qualifiedPublication?.history.first?.book === model.historyBooks.first,"history copied the original card")
            try check(model.qualifiedPublication?.favorites.first?.book === model.favoriteBooks.first,"favorite copied the original card")
        }
        await test("full position identity distinct from numeric work identity") {
            let (_,model,_,_)=try await fixture()
            try check(model.qualifiedPublication?.history.first?.recordID==locator().persistenceKey,"record lacks full locator")
            try check(locator().persistenceKey != locator(4).persistenceKey,"position identity collapsed")
        }
        await test("record invalidates retained publication before persistence") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.record(locator(4),title:"Later") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"record retained stale authority")
        }
        await test("favorite mutation invalidates retained publication") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"favorite retained stale authority")
        }
        await test("equal favorite publication invalidates") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"equal write was ignored")
        }
        await test("favorite ABA cannot renew old proof") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.setFavorite(false,locator:locator(),title:"Original") }
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"ABA renewed old proof")
        }
        await test("history deletion invalidates") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.removeHistory(locator()) }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"deletion retained old proof")
        }
        await test("favorite history suppression invalidates") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.removeHistory(locator()) }
            let entries=await store.entries()
            try check(entries.first?.lastOpened == .distantPast,"original favorite suppression changed")
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"suppression retained old proof")
        }
        await test("no-op absent deletion preserves publication") {
            let (store,model,_,_)=try await fixture()
            try await store.removeHistory(locator(99))
            try check(model.qualifiedPublication?.isCurrent(in:model)==true,"nonmutation retired source")
        }
        await test("legacy association mutation retires source") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.associate(locator(),withLegacyKey:"book.3891") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"association mutation was omitted")
        }
        await test("publication source overflow permanently refuses") {
            let source=QualifiedLocatorStore.PublicationSource()
            source.testRevision(.max)
            let old=source.capture()
            try check(old?.isCurrent==true,"max should still describe pre-mutation source")
            source.willChange()
            try check(old?.isCurrent==false && source.capture()==nil,"overflow renewed proof")
            source.willChange(); try check(source.capture()==nil,"nil overflow reset")
        }
        await test("new load retires original publication before arrays change") {
            let (_,model,_,_)=try await fixture()
            let old=model.qualifiedPublication!
            _=model.beginQualifiedPublication()
            try check(model.qualifiedPublication==nil && !old.isCurrent(in:model),"load failed to retire proof")
        }
        await test("stale load cannot publish after newer load") {
            let (_,model,old,entries)=try await fixture()
            let latest=model.beginQualifiedPublication()
            model.completeQualifiedPublication(latest,entries:entries)
            try check(model.qualifiedPublication != nil,"latest load unexpectedly refused")
            model.completeQualifiedPublication(old,entries:entries)
            try check(model.qualifiedPublication==nil,"late old load renewed source")
        }
        await test("backend changed during actor await refuses publication") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeBackendID = .sefaria
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"wrong backend published")
        }
        await test("backend A B A generation invalidates") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeBackendID = .sefaria
            BackendCoordinator.shared.generation += 1
            BackendCoordinator.shared.activeBackendID = .otzaria
            BackendCoordinator.shared.generation += 1
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"backend ABA renewed source")
        }
        await test("same backend resources replace generation") {
            let (_,model,_,_)=try await fixture()
            BackendCoordinator.shared.generation += 1
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"resource replacement retained source")
        }
        await test("failed transition publication invalidates without backend change") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeTransitionToken += 1
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"failed transition history ignored")
        }
        await test("active transition cannot publish") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.isTransitioning = true
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"transitional source accepted")
        }
        await test("native legacy arrays cannot infer qualified identity") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:nil)]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"legacy numeric row acquired authority")
        }
        await test("duplicate original numeric row identities refuse") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks.append(BooksData(id:3891,locator:locator()))
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"duplicate original row was accepted")
        }
        await test("duplicate full qualified entry identity refuses") {
            let (_,model,load,entries)=try await fixture()
            model.completeQualifiedPublication(load,entries:.init(entries:entries.entries+entries.entries,observation:entries.observation))
            try check(model.qualifiedPublication==nil,"duplicate full entry was accepted")
        }
        await test("favorite section cannot invent membership") {
            let (_,model,load,entries)=try await fixture()
            model.favoriteBooks=[BooksData(id:3891,locator:locator())]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"history-only entry became favorite")
        }
        await test("same numeric id replacement is a different original object") {
            let (_,model,_,_)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:locator())]
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"replacement object accepted")
        }
        await test("actual card locator mutation refuses") {
            let (_,model,_,_)=try await fixture()
            model.historyBooks[0].backendLocator=locator(4)
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"mutable locator ignored")
        }
        await test("wrong backend locator cannot acquire qualified provenance") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:locator(3,backend:.sefaria))]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"numeric cross-backend card accepted")
        }
        await test("original model owner cannot be substituted") {
            let (_,model,_,_)=try await fixture()
            let other=HistoryViewModel(); other.historyBooks=model.historyBooks
            try check(model.qualifiedPublication?.isCurrent(in:other)==false,"foreign model accepted")
        }
        await test("load revision overflow refuses without resetting") {
            let (_,model,_,entries)=try await fixture()
            model.testLoadRevision(.max)
            let load=model.beginQualifiedPublication()
            model.completeQualifiedPublication(load,entries:entries)
            try check(load.revision==nil && model.qualifiedPublication==nil,"load overflow renewed authority")
            try check(model.beginQualifiedPublication().revision==nil,"load revision reset")
        }
        await test("native data path remains explicitly unqualified") {
            let (_,model,_,entries)=try await fixture()
            BackendCoordinator.shared.usesNativeMaktabahDataPath = true
            let load=model.beginQualifiedPublication()
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"native arrays relabeled as qualified")
        }
        await test("synchronous report can revalidate the same source token") {
            let (_,model,_,_)=try await fixture()
            let publication=model.qualifiedPublication!
            let result=publication.withCurrent(in:model) {
                publication.isCurrent(in:model) ? "same original source" : "stale"
            }
            try check(result=="same original source","nested validation deadlocked or failed")
        }
        await test("retired source never executes report callback") {
            let (store,model,_,_)=try await fixture()
            let publication=model.qualifiedPublication!
            await mutation { try await store.record(locator(4),title:"Later") }
            var calls=0
            let result=publication.withCurrent(in:model) { calls += 1; return true }
            try check(result==nil && calls==0,"retired source executed report")
        }
        await test("reentrant source invalidation cannot return confirmed report") {
            let source=QualifiedLocatorStore.PublicationSource()
            let observed=source.capture()!
            let result=observed.withCurrent { source.willChange(); return true }
            try check(result==nil && !observed.isCurrent,"reentrant source change returned report")
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        exit(failed==0 ? 0 : 1)
    }
}
'''
source=models+'\n'+store+'\n'+boundary+'\n'+publication+'\n'+controls
(OUT/'Controls.swift').write_text(source)
(OUT/'DOMAIN_BOUNDARY.md').write_text('Verbatim actual QualifiedLocatorStore including persistence, actual TextLocator/BackendID contracts, actual new History publication methods and proof. BackendCoordinator and BooksData, and the minimal History owner shell, are explicit domain substitutes. Tests exercise original actor reads/mutations and new source metadata, not full app/UIKit/Core, native rendering or disk durability. Test-only same-file exhaustion setters are appended to the control build only.\n')
inputs=[]
for p in paths:
 b=(SOURCE/p).read_bytes();inputs.append(dict(path=p,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(OUT/'SOURCE_INPUTS.json').write_text(json.dumps({'source_ref':'5d4b110a61882dea413c110b3d4f8026f4aa2b54 + uncommitted exact three-file metadata candidate','inputs':inputs,'scope':'actual source/domain component; no SDK/native claim'},indent=2)+'\n')
print(json.dumps({'swift_bytes':len(source.encode()),'swift_sha256':hashlib.sha256(source.encode()).hexdigest(),'inputs':inputs}))
