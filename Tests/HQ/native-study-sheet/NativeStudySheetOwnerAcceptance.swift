import Foundation
import Darwin

@main
enum NativeStudySheetOwnerAcceptance {
    struct Check: Codable { let id: String; let passed: Bool }
    enum Failure: Error { case checksFailed }
    static func main() throws {
        var checks: [Check] = []
        func check(_ id: String, _ body: () -> Bool) { checks.append(.init(id: id, passed: body())) }
        check("system_nil_closes_original_owner_before_layout_callback") {
            let owner = StudySheetOwnerBoundary(); owner.originalOpenAction()
            let first = owner.nativeStudyPresentation.presentation!
            owner.actualBinding().set(nil)
            owner.originalLayoutCallback()
            guard !owner.viewModel.readerInspectorVisible,
                  owner.viewModel.resetCount == 1,
                  owner.viewModel.selectedSegmentLocator == nil,
                  owner.viewModel.otzariaSelectedLineAnchor == nil,
                  owner.viewModel.otzariaLinkedSources.isEmpty,
                  !owner.viewModel.otzariaSourcesIsLoading,
                  owner.viewModel.otzariaSourcesError == nil else { return false }
            owner.originalDidDismiss(first.id)
            return !owner.nativeStudyPresentation.studyRequested && owner.nativeStudyPresentation.presentation == nil
        }
        check("nil_binding_without_captured_owner_cannot_close_current_reader") {
            let owner = StudySheetOwnerBoundary(); let missing = owner.actualBinding()
            owner.viewModel.readerInspectorVisible = true
            missing.set(nil)
            return owner.viewModel.readerInspectorVisible && owner.viewModel.resetCount == 0
        }
        check("stale_binding_cannot_close_new_presentation") {
            let owner = StudySheetOwnerBoundary(); owner.originalOpenAction()
            let first = owner.nativeStudyPresentation.presentation!, old = owner.actualBinding()
            old.set(nil); owner.originalDidDismiss(first.id)
            owner.originalOpenAction(); let second = owner.nativeStudyPresentation.presentation
            old.set(nil); owner.originalLayoutCallback()
            return owner.viewModel.readerInspectorVisible && owner.nativeStudyPresentation.presentation == second
                && first != second && owner.viewModel.resetCount == 1
        }
        check("double_nil_callback_cannot_cancel_explicit_queued_reopen") {
            let owner = StudySheetOwnerBoundary(); owner.originalOpenAction()
            let first = owner.nativeStudyPresentation.presentation!, old = owner.actualBinding()
            old.set(nil); owner.originalOpenAction(); old.set(nil)
            owner.originalDidDismiss(first.id)
            return owner.viewModel.readerInspectorVisible && owner.nativeStudyPresentation.studyRequested
                && owner.nativeStudyPresentation.presentation != first && owner.nativeStudyPresentation.isPresented
                && owner.viewModel.resetCount == 1
        }
        check("non_nil_binding_delivery_does_not_close_original_owner") {
            let owner = StudySheetOwnerBoundary(); owner.originalOpenAction()
            let first = owner.nativeStudyPresentation.presentation!
            owner.actualBinding().set(first)
            return owner.viewModel.readerInspectorVisible && owner.nativeStudyPresentation.presentation == first
                && owner.viewModel.resetCount == 0
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(checks)
        if CommandLine.arguments.count == 2 { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic) }
        print(String(decoding: data, as: UTF8.self))
        guard checks.count == 5, Set(checks.map(\.id)).count == 5, checks.allSatisfy(\.passed) else { exit(1) }
    }
}
