
import Foundation
import Observation
// Explicit app-domain boundaries. No SwiftUI, UIKit, or backend delivery is simulated.
// The test double for captureOriginalSource exercises revocation; its production
// implementation has a separate immutable source/Observation proof.
enum AppMode: Equatable { case viewer, history }
@MainActor enum MaktabahApp { static var isIpad=false }
@MainActor @Observable final class BooksData {
 var id:Int;var backendLocator:String?
 init(_ id:Int=3891) {self.id=id;backendLocator="otzaria|book:\(id)|line:523"}
}
@MainActor @Observable final class ReaderViewModel {
 var currentBook:BooksData?
 var isPopoverPresented=false
 var readerInspectorVisible=false
 var originalTOCRevision:UInt64=0
 init(book:BooksData){currentBook=book}
}
@MainActor @Observable final class iOSNavigationManager {
 struct ReaderTab {let id:UUID;let book:BooksData;let viewModel:ReaderViewModel}
 var activeTabId:UUID?
 var openTabs:[ReaderTab]=[]
 var selectedContentId:Int?=523
 var selectedBookForInfo:BooksData?
 var showingTabsList=false
 var currentMode:AppMode = .history
 func switchToMode(_ mode: AppMode) {
        currentMode = mode
    }
 var activeReaderViewModel:ReaderViewModel? {openTabs.first{$0.id==activeTabId}?.viewModel}
     var selectedBook: BooksData? {
        willSet {
            // Original presentation ownership metadata. Every setter, including
            // an equal-value write, advances; exhaustion can never recycle it.
            if let revision = selectedBookPresentationRevision, revision < .max {
                selectedBookPresentationRevision = revision + 1
            } else {
                selectedBookPresentationRevision = nil
            }
        }
        didSet { selectedBookPresentationMode = selectedBook.map { _ in currentMode } }
    }
 private(set) var selectedBookPresentationMode:AppMode?
 private(set) var selectedBookPresentationRevision:UInt64?=0
}
@MainActor @Observable final class MappingSource {var event:UInt64=0}
struct MappingProjection:Equatable {let activeTabID:UUID?}
enum MappingCoverage {case liveNativeSetters;case unavailable}
@MainActor struct MappingObservation {
 let source:MappingSource;let owner:ObjectIdentifier;let scene:String
 let epoch:UInt64;let projection:MappingProjection;let coverage:MappingCoverage
}
@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
 var attached=true
 var isSwitching=false
 let sceneID:String
 let mappingOwnershipSource=MappingSource()
 var epoch:UInt64=0
 var coverage:MappingCoverage = .liveNativeSetters
 let manager:iOSNavigationManager
 init(manager:iOSNavigationManager,sceneID:String){self.manager=manager;self.sceneID=sceneID}
 func mappingOwnershipObservation()->MappingObservation? {
  .init(source:mappingOwnershipSource,owner:ObjectIdentifier(manager),scene:sceneID,
    epoch:epoch,projection:.init(activeTabID:manager.activeTabId),coverage:coverage)
 }
}
@MainActor @Observable final class MaktabahNativeWorkspaceProjectionSource {
 var isAuthoritative=true
 var workspace:StudyWorkspaceNavigationAdapter?
 init(_ workspace:StudyWorkspaceNavigationAdapter){self.workspace=workspace}
 func read() throws -> StudyWorkspaceNavigationAdapter? {workspace}
}
typealias MaktabahNativeComponentSourceObservation = NativeComponentSourceObservation
@MainActor enum MaktabahNativeTOCComponents {
 enum Anchor {case contents}
 static func currentReader(_ manager:iOSNavigationManager)->ReaderViewModel? {
  let tabs=manager.openTabs.filter{$0.id==manager.activeTabId}
  return tabs.count==1 ? tabs[0].viewModel:nil
 }
 static func captureOriginalSource(_ anchor:Anchor,manager:iOSNavigationManager) throws -> @MainActor () throws -> Void {
  guard let reader=currentReader(manager) else{throw UIRouteError(.staleState,"boundary_reader")}
  let proof=NativeComponentSourceObservation {
   _=manager.activeTabId;_=manager.openTabs;_=reader.originalTOCRevision
  }
  return {try proof.validate();guard currentReader(manager) === reader else{throw UIRouteError(.staleState,"boundary_reader_changed")}}
 }
}



enum OriginalTab { case history, viewer }
@MainActor final class OriginalBindingCell<Value> {
 var onSet: (@MainActor (Value) -> Void)?
 var wrappedValue: Value { didSet { onSet?(wrappedValue) } }
 init(_ value: Value) { wrappedValue = value }
}
@MainActor enum MaktabahNativeRootDestination {
 case library
 var isAvailable: Bool { true }
}
@MainActor final class MaktabahNativeSceneBindings {
 let manager: iOSNavigationManager
 let showSettings = OriginalBindingCell(false)
 let selectedTab = OriginalBindingCell(OriginalTab.history)
 var isPresentationReady = true
 init(manager: iOSNavigationManager) { self.manager = manager }
 func presentOriginalPhoneTOCReader(_ tab: iOSNavigationManager.ReaderTab) throws {
        let matches = manager.openTabs.filter { $0.id == tab.id }
        guard !MaktabahApp.isIpad, !showSettings.wrappedValue, isPresentationReady,
              MaktabahNativeRootDestination.library.isAvailable,
              manager.activeTabId == tab.id, matches.count == 1, let original = matches.first,
              original.book === tab.book, original.viewModel === tab.viewModel,
              manager.selectedBook == nil || manager.selectedBook === tab.book,
              let revision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_owner_changed")
        }
        let assignsBook = manager.selectedBook !== tab.book || manager.selectedBookPresentationMode != .viewer
        guard !assignsBook || revision < .max else {
            throw UIRouteError(.staleState, "native_phone_toc_presentation_exhausted")
        }
        let expectedRevision = assignsBook ? revision + 1 : revision
        selectedTab.wrappedValue = .viewer
        // selectedBook.didSet captures the ORIGINAL currentMode synchronously.
        manager.switchToMode(.viewer)
        if assignsBook { manager.selectedBook = tab.book }
        let after = manager.openTabs.filter { $0.id == tab.id }
        guard manager.activeTabId == tab.id, after.count == 1, let retained = after.first,
              retained.book === tab.book, retained.viewModel === tab.viewModel,
              manager.selectedBook === tab.book, manager.currentMode == .viewer,
              manager.selectedBookPresentationMode == .viewer,
              manager.selectedBookPresentationRevision == expectedRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_transition_changed")
        }
    }
}
