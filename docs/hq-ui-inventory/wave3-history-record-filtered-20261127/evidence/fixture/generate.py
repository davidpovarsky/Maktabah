#!/usr/bin/env python3
"""Actual record binding/metadata/view-check source over explicit domain doubles.

Uses the original Core/UIRouting/Host modules in the preserved owned SwiftPM
source snapshot. No alternate authority or native/UIKit acceptance is asserted.
"""
import hashlib,json,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
out.mkdir(parents=True,exist_ok=False)
inputs={}; segments=[]
def read(path):
    p=root/path
    b=p.read_bytes() if p.exists() else subprocess.check_output(['git','-C',str(root),'show','HEAD:'+path])
    inputs[path]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
    return b.decode()
def block(text,marker):
    start=text.index(marker); i=text.index('{',start); depth=1; end=i+1
    while depth:
        if text[end]=='{':depth+=1
        elif text[end]=='}':depth-=1
        end+=1
    value=text[start:end];segments.append({'marker':marker,'bytes':len(value.encode()),'sha256':hashlib.sha256(value.encode()).hexdigest()})
    return value
integration='Source/ChavrusaText/UIRoutingHost/Integration/'
entry=read(integration+'MaktabahNativeHistoryRecords.swift')
views=read(integration+'MaktabahNativeHistoryRecordViews.swift')
model=read('Source/Features/History/ViewModel/HistoryViewModel.swift')
store=read('Source/LibraryBackend/QualifiedLocatorStore.swift')
models=read('Source/LibraryBackend/LibraryBackendModels.swift')
manager=read('Source/UI/iOS/Managers/iOSNavigationManager.swift')
rootowner=read(integration+'MaktabahNativeSearchEntry.swift')
binding=read(integration+'MaktabahNativeSceneBindings.swift')
bridge=read(integration+'MaktabahNativeComponentBinding.swift')
composition=read(integration+'MaktabahNativeRoutingComposition.swift')
main=read('Source/UI/iOS/Views/iOSMainView.swift')
header='import Foundation\nimport Observation\nimport XCTest\nimport OtzariaActionCore\nimport OtzariaUIRouting\n@testable import ChavrusaUIRoutingHost\n'
domain=Path(__file__).with_name('DomainBoundary.swift').read_text()
domain+='\nextension iOSTab {\n'+block(main, '    func isAvailable(for capabilities: BackendCapabilities)')+'\n}\n'
managerFields=block(manager,'    var currentMode: AppMode')+'\n    private(set) var nativeModePresentationRevision: UInt64? = 0\n'
managerFields+=block(manager,'    var selectedBook: BooksData?')+'\n    private(set) var selectedBookPresentationRevision: UInt64? = 0\n    private(set) var selectedBookPresentationMode: AppMode?\n'
assert managerFields in manager
domain+='\n@MainActor @Observable final class iOSNavigationManager {\n'+managerFields+'''
    struct ReaderTab { let id: UUID; let book: BooksData; let viewModel: ReaderViewModel }
    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?
    var selectedContentId: Int? = 523
    var selectedBookForInfo: BooksData?
    var showingTabsList = false
    var alertMessage: String?
    var activeReaderViewModel: ReaderViewModel? { openTabs.first { $0.id == activeTabId }?.viewModel }
    init(modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        nativeModePresentationRevision = modeSeed; selectedBookPresentationRevision = bookSeed
    }
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator? = nil
    let rootPublications: MaktabahNativeRootPublicationSource?
'''+block(binding,'    var isPresentationReady: Bool')+'\n}\n'
methods=model[model.index('    /// Passive provenance only.'):model.index('    let maxHistoryCount')]
domain+='\n@MainActor @Observable final class HistoryViewModel {\n    static let shared = HistoryViewModel()\n    var entriesByBookId: [Int: Int] = [:]\n    var historyOrder: [Int] = []\n    var historyBooks: [BooksData] = []\n    var favoriteBooks: [BooksData] = []\n    var searchText = ""\n'+methods+'\n}\n'
rootBody=block(rootowner,'@MainActor\nfinal class MaktabahNativeRootPublicationSource')+'''
// Test-only initialization of exact original private metadata. Product has no reset.
extension MaktabahNativeRootPublicationSource {
    convenience init(boundarySelection: UInt64?, boundarySettings: UInt64?) {
        self.init(); selectionRevision = boundarySelection; settingsRevision = boundarySettings
    }
}
'''
catalog=block(entry,'@MainActor enum MaktabahNativeHistoryRecords')
record=block(catalog,'    static func record(')
catalog=catalog.replace(record,'    static func record(_ card: HistoryQualifiedPublication.Card, kind: Kind) throws -> Record {\n        try BoundaryRecordIdentity.make(card, kind: kind)\n    }')
actual= models.split('/// A canonical reader destination:')[0]+'\n'+store+'\n'
actual+=block(model,'@MainActor\nfinal class HistoryQualifiedPublication')+'\n'+rootBody+'\n'
actual+=block(bridge,'@MainActor final class MaktabahNativeComponentSourceObservation')+'\n'
actual+=block(entry,'@MainActor\nstruct MaktabahNativeHistoryRecordParentTransition')+'\n'
actual+=block(entry,'extension MaktabahNativeSceneBindings')+'\n'+catalog+'\n'
actual+=block(binding,'@MainActor enum MaktabahNativeRootDestination')+'\n'
actual+=block(entry,'@MainActor final class MaktabahNativeHistoryRecordBinding')+'\n'
actual+=block(views,'@MainActor final class MaktabahNativeHistoryScrollOwner')+'\n'
actual+=block(views,'@MainActor enum MaktabahNativeHistoryRecordGeometry')+'\n'
metadata=Path(__file__).with_name('MetadataBoundary.swift').read_text()
metadata=metadata.replace('/* ORIGINAL_ROOT_METADATA */',block(composition,'    private func intentRootEntities()'))
metadata=metadata.replace('/* RECORD_METADATA */',block(composition,'    private func intentHistoryRecordWindows()'))
assert composition.count('try intentHistoryRecordWindows()') == 2
controls=Path(__file__).with_name('BaseBindingTests.swift').read_text()+'\n'+metadata+'\n'+Path(__file__).with_name('Tests.swift').read_text()
result=header+domain+'\n'+actual+'\n'+controls
(out/'HistoryRecordBindingSourceTests.swift').write_text(result)
(out/'DomainBoundary.swift.txt').write_text(domain)
(out/'SOURCE_INPUTS.json').write_text(json.dumps({'scope':'Verbatim production binding, parent, original counters, metadata, row geometry/scroll owner; real portable Core/UIRouting/Host modules. Explicit UIKit/SwiftUI/Combine/domain/lifetime inputs; hash constructor is a declared deterministic boundary. Actual original generic and candidate record-window metadata methods also included over explicit scene/registry-input boundaries. Only the new metadata class is run by its filter. Not SDK/native acceptance.','files':inputs,'verbatimSegments':segments,'fixtureFiles':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),Path(__file__).with_name('DomainBoundary.swift'),Path(__file__).with_name('BaseBindingTests.swift'),Path(__file__).with_name('MetadataBoundary.swift'),Path(__file__).with_name('Tests.swift')]},'generatedSHA256':hashlib.sha256(result.encode()).hexdigest()},indent=2)+'\n')
print(json.dumps({'output':str(out),'bytes':len(result.encode()),'sourceFiles':len(inputs),'sha256':hashlib.sha256(result.encode()).hexdigest()}))
