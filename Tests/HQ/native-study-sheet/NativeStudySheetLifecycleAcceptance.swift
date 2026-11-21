import Foundation
import Darwin

@main
enum NativeStudySheetLifecycleAcceptance {
    struct Check: Codable { let id: String; let passed: Bool }
    enum Failure: Error { case checksFailed }

    static func main() throws {
        var checks: [Check] = []
        func check(_ id: String, _ body: () -> Bool) {
            checks.append(.init(id: id, passed: body()))
        }
        typealias State = NativeStudySheetPresentationState
        check("initial_has_no_presenter") {
            let s = State()
            return s.presentation == nil && s.presentedItem == nil && s.note == nil && !s.studyRequested
        }
        check("request_creates_one_identity") {
            var s = State(); s.requestStudy()
            return s.presentation != nil && s.presentation == s.presentedItem && s.studyRequested
        }
        check("repeat_request_retains_identity") {
            var s = State(); s.requestStudy(); let first = s.presentation
            s.requestStudy(); s.requestStudy()
            return first == s.presentation
        }
        check("close_retains_identity_until_actual_dismissal") {
            var s = State(); s.requestStudy(); let first = s.presentation
            s.requestDismissal()
            return s.presentedItem == nil && s.presentation == first && !s.studyRequested
        }
        check("note_cannot_attach_to_closing_presenter") {
            var s = State(); s.requestStudy(); s.requestDismissal()
            return !s.beginNote(id: UUID()) && s.note == nil
        }
        check("reopen_waits_for_exact_dismissal") {
            var s = State(); s.requestStudy(); let first = s.presentation!
            s.requestDismissal(); s.requestStudy()
            guard s.presentation == first, s.presentedItem == nil else { return false }
            let result = s.studyDidDismiss(id: first.id)
            return result?.studyStillRequested == true && s.presentedItem != nil && s.presentation != first
        }
        check("wrong_parent_callback_cannot_finish_close") {
            var s = State(); s.requestStudy(); let first = s.presentation
            s.requestDismissal()
            return s.studyDidDismiss(id: UUID()) == nil && s.presentation == first
        }
        check("callback_while_still_presented_is_refused") {
            var s = State(); s.requestStudy(); let first = s.presentation!
            return s.studyDidDismiss(id: first.id) == nil && s.presentation == first && s.isPresented
        }
        check("double_parent_callback_has_one_effect") {
            var s = State(); s.requestStudy(); let first = s.presentation!
            s.requestDismissal()
            return s.studyDidDismiss(id: first.id) != nil && s.studyDidDismiss(id: first.id) == nil && s.presentation == nil
        }
        check("child_is_bound_to_exact_study_identity") {
            var s = State(); s.requestStudy(); let first = s.presentation!; let note = UUID()
            return s.beginNote(id: note) && s.note == State.NotePresentation(id: note, host: .study(first.id))
        }
        check("second_note_cannot_replace_current_child") {
            var s = State(); s.requestStudy(); let note = UUID(); _ = s.beginNote(id: note)
            let original = s.note
            return !s.beginNote(id: UUID()) && s.note == original
        }
        check("parent_close_waits_for_actual_child_dismissal") {
            var s = State(); s.requestStudy(); let parent = s.presentation!; let note = UUID()
            _ = s.beginNote(id: note); s.requestDismissal()
            guard s.isPresented, s.presentation == parent, !s.studyRequested else { return false }
            return s.noteDidDismiss(id: note) && !s.isPresented && s.presentation == parent
        }
        check("toc_waits_for_child_and_parent_callbacks") {
            var s = State(); s.requestStudy(); let parent = s.presentation!; let note = UUID()
            _ = s.beginNote(id: note); s.requestDismissal(showContents: true)
            guard s.isPresented, s.pendingContents, s.studyDidDismiss(id: parent.id) == nil else { return false }
            guard s.noteDidDismiss(id: note), !s.isPresented, s.pendingContents else { return false }
            let result = s.studyDidDismiss(id: parent.id)
            return result?.showContents == true && s.presentation == nil && !s.pendingContents
        }
        check("wrong_child_callback_cannot_release_parent") {
            var s = State(); s.requestStudy(); let note = UUID(); _ = s.beginNote(id: note)
            s.requestDismissal()
            return !s.noteDidDismiss(id: UUID()) && s.isPresented && s.note?.id == note
        }
        check("root_note_blocks_new_study_presenter") {
            var s = State(); let note = UUID(); _ = s.beginNote(id: note); s.requestStudy()
            return s.note?.host == .reader && s.presentation == nil && s.studyRequested
        }
        check("root_note_actual_dismissal_releases_queued_study") {
            var s = State(); let note = UUID(); _ = s.beginNote(id: note); s.requestStudy()
            return s.noteDidDismiss(id: note) && s.presentedItem != nil && s.note == nil
        }
        check("old_child_callback_cannot_retire_reopened_note") {
            var s = State(); s.requestStudy(); let first = UUID(); let second = UUID()
            _ = s.beginNote(id: first); _ = s.noteDidDismiss(id: first); _ = s.beginNote(id: second)
            return !s.noteDidDismiss(id: first) && s.note?.id == second && s.isPresented
        }
        check("old_parent_callback_cannot_retire_reopened_sheet") {
            var s = State(); s.requestStudy(); let first = s.presentation!
            s.requestDismissal(); s.requestStudy(); _ = s.studyDidDismiss(id: first.id)
            let second = s.presentation
            return s.studyDidDismiss(id: first.id) == nil && s.presentation == second && s.isPresented
        }
        check("toc_request_is_not_overwritten_by_queued_reopen") {
            var s = State(); s.requestStudy(); let first = s.presentation!
            s.requestDismissal(showContents: true); s.requestStudy()
            let result = s.studyDidDismiss(id: first.id)
            return result?.showContents == true && result?.studyStillRequested == false && s.presentation == nil
        }
        check("unrelated_note_callback_does_not_create_presentation") {
            var s = State()
            return !s.noteDidDismiss(id: UUID()) && s.presentation == nil && s.note == nil
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(checks)
        if CommandLine.arguments.count == 2 {
            try bytes.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
        }
        print(String(decoding: bytes, as: UTF8.self))
        guard checks.count == 20, Set(checks.map(\.id)).count == 20,
              checks.allSatisfy(\.passed) else { exit(1) }
    }
}
