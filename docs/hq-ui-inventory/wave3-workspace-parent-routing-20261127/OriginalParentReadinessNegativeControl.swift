import Foundation
struct UIDestinationID: Equatable { let rawValue: String }
@MainActor enum MaktabahApp { static var isIpad = true }
@MainActor final class MaktabahNativeWorkspacePresentationBinding {
 enum Parent: String, CaseIterable {
  case profiles = "native.workspace.profiles", overview = "native.workspace.overview"
  var destination: UIDestinationID { .init(rawValue: rawValue) }
 }
 struct Facets {
  var requested = false; var mounted = false; var visible = false
  var blockingChild = false; var transitioning = false
 }
 var available = true
 var profiles = Facets(), overview = Facets()
 func isAvailable(parent: Parent) -> Bool { available }
 func presentationFacets(for parent: Parent) -> Facets { parent == .profiles ? profiles : overview }
}
struct NativeRoute { let destination: UIDestinationID }
struct ValidatedRoute { let route: NativeRoute }
struct Invocation { let requestId: UUID }
struct Command { let route: ValidatedRoute; let invocation: Invocation }
@MainActor final class NoteEditor { var current: Bool?; var presentationActive = false }
@MainActor final class NoteDraft { var isApplied = false }
@MainActor final class Manager { var showingTabsList = false }
@MainActor final class Sidebar { struct Overview { var blocksRouting = false }; var overview = Overview() }
@MainActor final class Bindings {
 var isPresentationReady = true
 var isWorkspaceParentPresentationReady = true
 let manager = Manager()
 var sidebar: Sidebar? = Sidebar()
}
@MainActor final class OriginalReadiness {
 let bindings = Bindings()
 var workspacePresentation: MaktabahNativeWorkspacePresentationBinding? = .init()
 var studyChatPresentationID: UUID?
 var noteEditorOwner: NoteEditor?
 var noteDraftBinding: NoteDraft?
 var command: Command?
 var submissionID: UUID?
    private var hasOriginalWorkspacePresentation: Bool {
        guard let workspacePresentation else { return false }
        return MaktabahNativeWorkspacePresentationBinding.Parent.allCases.contains {
            let actual = workspacePresentation.presentationFacets(for: $0)
            return actual.requested || actual.mounted || actual.transitioning
        }
    }
    var isPresentationReady: Bool {
        bindings.isPresentationReady && !hasOriginalWorkspacePresentation && studyChatPresentationID == nil
            && ((noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true)
                || (command?.route.route.destination.rawValue == "native.reader.noteDraft" && noteDraftBinding?.isApplied == true))
    }
    func isPresentationReady(for destination: UIDestinationID) -> Bool {
        guard let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) else {
            return isPresentationReady
        }
        guard bindings.isWorkspaceParentPresentationReady, studyChatPresentationID == nil,
              noteEditorOwner?.current == nil, noteEditorOwner?.presentationActive != true,
              let binding = workspacePresentation, binding.isAvailable(parent: parent) else { return false }
        let profiles = binding.presentationFacets(for: .profiles)
        let overview = binding.presentationFacets(for: .overview)
        let continuing = command?.route.route.destination == destination
            && submissionID == command?.invocation.requestId && submissionID != nil
        if profiles.requested || profiles.mounted {
            guard parent == .profiles,
                  true || (profiles.visible && !profiles.transitioning) else { return false }
        }
        if overview.requested || overview.mounted || bindings.manager.showingTabsList
            || bindings.sidebar?.overview.blocksRouting == true {
            guard parent == .overview || (!MaktabahApp.isIpad && parent == .profiles),
                  overview.requested else { return false }
            let coveredByOriginalProfiles = parent == .profiles && profiles.requested
                && profiles.mounted && profiles.visible && !profiles.transitioning
            guard true || coveredByOriginalProfiles
                || (overview.mounted && overview.visible && !overview.transitioning) else { return false }
        }
        return true
    }
}
@main struct Controls {
 @MainActor static func main() {
  typealias Parent = MaktabahNativeWorkspacePresentationBinding.Parent
  let profiles = Parent.profiles.destination, overview = Parent.overview.destination
  let history = UIDestinationID(rawValue: "native.history")
  var passed = 0, failed = 0
  func check(_ name: String, _ operation: (OriginalReadiness) -> Bool) {
   MaktabahApp.isIpad = true
   let original = OriginalReadiness()
   if operation(original) { passed += 1; print("PASS " + name) }
   else { failed += 1; print("FAIL " + name) }
  }
  func continuing(_ source: OriginalReadiness, _ destination: UIDestinationID, matching: Bool = true) {
   let request = UUID()
   source.command = .init(route: .init(route: .init(destination: destination)), invocation: .init(requestId: request))
   source.submissionID = matching ? request : UUID()
  }
  check("cold_original_profiles") { $0.isPresentationReady(for: profiles) }
  check("cold_original_overview") { $0.isPresentationReady(for: overview) }
  check("unknown_original_owner_unavailable") {
   $0.workspacePresentation = nil
   return !$0.isPresentationReady(for: profiles) && !$0.isPresentationReady(for: overview)
  }
  check("source_unavailable_never_inherits_generic_ready") {
   $0.workspacePresentation?.available = false
   return !$0.isPresentationReady(for: profiles) && !$0.isPresentationReady(for: overview)
  }
  check("preexisting_overview_transition_is_not_a_new_grant") {
   $0.workspacePresentation?.overview = .init(requested: true, transitioning: true)
   return !$0.isPresentationReady(for: overview)
  }
  check("same_begun_overview_can_wait_for_its_first_host") {
   continuing($0, overview)
   $0.workspacePresentation?.overview = .init(requested: true, transitioning: true)
   return $0.isPresentationReady(for: overview)
  }
  check("different_destination_cannot_borrow_transition") {
   continuing($0, profiles)
   $0.workspacePresentation?.overview = .init(requested: true, transitioning: true)
   return !$0.isPresentationReady(for: overview)
  }
  check("different_request_cannot_borrow_transition") {
   continuing($0, overview, matching: false)
   $0.workspacePresentation?.overview = .init(requested: true, transitioning: true)
   return !$0.isPresentationReady(for: overview)
  }
  check("stable_profiles_are_navigable") {
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: true)
   return $0.isPresentationReady(for: profiles)
  }
  check("preexisting_profile_transition_is_unavailable") {
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, transitioning: true)
   return !$0.isPresentationReady(for: profiles)
  }
  check("phone_nested_profiles_may_cover_their_original_overview") {
   MaktabahApp.isIpad = false
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: true)
   $0.workspacePresentation?.overview = .init(requested: true, mounted: true, transitioning: true)
   $0.bindings.manager.showingTabsList = true
   return $0.isPresentationReady(for: profiles)
  }
  check("overview_cannot_route_behind_original_profiles") {
   MaktabahApp.isIpad = false
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: true)
   $0.workspacePresentation?.overview = .init(requested: true, mounted: true, transitioning: true)
   return !$0.isPresentationReady(for: overview)
  }
  check("tablet_profiles_do_not_reuse_overview_transition") {
   continuing($0, profiles)
   $0.workspacePresentation?.overview = .init(requested: true, mounted: true, transitioning: true)
   return !$0.isPresentationReady(for: profiles)
  }
  check("unrelated_modal_blocks_same_command") {
   continuing($0, overview)
   $0.bindings.isWorkspaceParentPresentationReady = false
   return !$0.isPresentationReady(for: overview)
  }
  check("unsaved_note_blocks_parent") {
   continuing($0, profiles)
   $0.noteEditorOwner = NoteEditor(); $0.noteEditorOwner?.current = true
   return !$0.isPresentationReady(for: profiles)
  }
  check("note_dismissal_lifetime_still_blocks_parent") {
   $0.noteEditorOwner = NoteEditor(); $0.noteEditorOwner?.presentationActive = true
   return !$0.isPresentationReady(for: overview)
  }
  check("original_study_chat_blocks_parent") {
   $0.studyChatPresentationID = UUID()
   return !$0.isPresentationReady(for: profiles)
  }
  check("generic_roots_blocked_by_real_profiles_even_if_flag_consumed") {
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: true)
   return !$0.isPresentationReady(for: history)
  }
  check("generic_roots_wait_for_dismissed_host_to_unmount") {
   $0.workspacePresentation?.overview = .init(mounted: true, transitioning: true)
   return !$0.isPresentationReady(for: history)
  }
  check("existing_generic_ready_behavior_without_workspace_parent") {
   $0.workspacePresentation = nil
   guard $0.isPresentationReady(for: history) else { return false }
   $0.bindings.isPresentationReady = false
   return !$0.isPresentationReady(for: history)
  }
  print("TOTAL passed=\(passed) failed=\(failed)")
  if failed != 0 { exit(1) }
 }
}
