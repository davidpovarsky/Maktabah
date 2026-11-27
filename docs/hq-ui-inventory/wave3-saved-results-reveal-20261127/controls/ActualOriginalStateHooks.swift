import Foundation
import OtzariaUIRouting
@MainActor final class OriginalStateHookFixture {
    var nativeRoutingSession: TestSession?
    let nativePresentationOwner: UUID
    let nativeSheetOwner: UUID
    init(session: TestSession, search: UUID, sheet: UUID) { nativeRoutingSession = session; nativePresentationOwner = search; nativeSheetOwner = sheet }
    @MainActor private func nativeSavedResultsBinding(_ original: Binding<Bool>) -> Binding<Bool> {
        let session = nativeRoutingSession, binding = nativeRoutingSession?.savedResultsBinding
        let owner = nativePresentationOwner
        return Binding(get: { original.wrappedValue }, set: { [weak session, weak binding] value in
            binding?.searchWillPublish(owner: owner, next: value)
            session?.originalSearchPresentationWillChange(owner: owner)
            original.wrappedValue = value
            binding?.searchDidPublish(owner: owner)
        })
    }
    @MainActor private func nativeStateBinding<Value>(_ original: Binding<Value>,
        field: MaktabahNativeSavedResultsBinding.StateField) -> Binding<Value> {
        let binding = nativeRoutingSession?.savedResultsBinding, owner = nativeSheetOwner
        return Binding(get: { original.wrappedValue }, set: { [weak binding] value in
            binding?.sheetStateWillPublish(owner: owner, field: field,
                nextPath: value as? [FolderNode], nextLoading: value as? Bool)
            original.wrappedValue = value
            binding?.sheetStateDidPublish(owner: owner, field: field)
        })
    }
    func setSearch(_ cell: Cell<Bool>, _ value: Bool) { nativeSavedResultsBinding(cell.binding).wrappedValue = value }
    func set<Value>(_ cell: Cell<Value>, field: MaktabahNativeSavedResultsBinding.StateField, value: Value) { nativeStateBinding(cell.binding, field: field).wrappedValue = value }
}
