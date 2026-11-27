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
 var pendingParent: Parent?
 var pendingRequestID: UUID?
 var applied = false
 var retainedProofValid = true
 func isContinuingAppliedRequest(parent: Parent, requestID: UUID) -> Bool {
  pendingParent == parent && pendingRequestID == requestID && applied && retainedProofValid
 }
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
@MainActor final class Manager { var showingTabsList = false; var selectedBookForInfo: Bool?; var activeReaderViewModel: Reader? }
@MainActor final class Sidebar { struct Overview { var blocksRouting = false }; var overview = Overview() }
@MainActor final class Cell<Value> { var wrappedValue: Value; init(_ value: Value) { wrappedValue = value } }
enum OriginalTab { case history, viewer }
@MainActor final class DonationManager {
 static let shared = DonationManager()
 var showDonationSheet = false
}
@MainActor final class Reader { var isPopoverPresented = false }
@MainActor final class Bindings {
 var isPresentationReady = true
 let manager = Manager()
 var sidebar: Sidebar? = Sidebar()
 let showSettings = Cell(false)
 let selectedTab = Cell(OriginalTab.history)
    var isWorkspaceParentPresentationReady: Bool {
        !showSettings.wrappedValue && !DonationManager.shared.showDonationSheet
            && manager.selectedBookForInfo == nil
            && manager.activeReaderViewModel?.isPopoverPresented != true
    }
    func selectOriginalWorkspaceParent() {
        selectedTab.wrappedValue = .viewer
        // Preserve the original TabView's mode publication and all existing
        // tabs/models. The actual original parent host must still appear.
    }
}
struct UIStableID { let rawValue: String }
@MainActor final class OriginalWindowBoundary {
 var ready = true
 func isPresentationReady(in sceneID: UIStableID) -> Bool { ready }
}
@MainActor final class OriginalReadiness {
 let bindings = Bindings()
 let sceneID = UIStableID(rawValue: "original_scene_boundary")
 var windowSource: OriginalWindowBoundary? = OriginalWindowBoundary()
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
        let continuing: Bool
        if let requestID = submissionID, command?.invocation.requestId == requestID,
           command?.route.route.destination == destination {
            continuing = binding.isContinuingAppliedRequest(parent: parent, requestID: requestID)
        } else {
            continuing = false
        }
        // Before the first canonical apply, the ORIGINAL window must have no
        // unrelated presented controller or unfinished dismissal. A false
        // SwiftUI sheet binding alone does not prove that UIKit has finished.
        // Warm original Workspace sheets instead use their exact host evidence.
        if !profiles.requested && !profiles.mounted && !overview.requested && !overview.mounted
            && !continuing {
            guard windowSource?.isPresentationReady(in: sceneID) == true else { return false }
        }
        if profiles.requested || profiles.mounted {
            guard parent == .profiles,
                  continuing || (profiles.visible && !profiles.transitioning) else { return false }
        }
        if overview.requested || overview.mounted || bindings.manager.showingTabsList
            || bindings.sidebar?.overview.blocksRouting == true {
            guard parent == .overview || (!MaktabahApp.isIpad && parent == .profiles),
                  overview.requested else { return false }
            let coveredByOriginalProfiles = parent == .profiles && profiles.requested
                && profiles.mounted && profiles.visible && !profiles.transitioning
            guard continuing || coveredByOriginalProfiles
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
   DonationManager.shared.showDonationSheet = false
   let original = OriginalReadiness()
   if operation(original) { passed += 1; print("PASS " + name) }
   else { failed += 1; print("FAIL " + name) }
  }
  func continuing(_ source: OriginalReadiness, _ destination: UIDestinationID, matching: Bool = true, applied: Bool = true) {
   let request = UUID()
   source.command = .init(route: .init(route: .init(destination: destination)), invocation: .init(requestId: request))
   source.submissionID = matching ? request : UUID()
   source.workspacePresentation?.pendingParent = Parent(rawValue: destination.rawValue)
   source.workspacePresentation?.pendingRequestID = request
   source.workspacePresentation?.applied = applied
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
  check("same_applied_overview_can_wait_for_its_first_host") {
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
   DonationManager.shared.showDonationSheet = true
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

  check("settings_already_shown_blocks_both_parents") {
   $0.bindings.showSettings.wrappedValue = true
   return !$0.isPresentationReady(for: profiles) && !$0.isPresentationReady(for: overview)
  }
  check("settings_cannot_be_dismissed_by_same_applied_request") {
   continuing($0, profiles)
   $0.bindings.showSettings.wrappedValue = true
   return !$0.isPresentationReady(for: profiles)
  }
  check("original_workspace_selection_does_not_clear_settings") {
   $0.bindings.showSettings.wrappedValue = true
   $0.bindings.selectOriginalWorkspaceParent()
   return $0.bindings.showSettings.wrappedValue && $0.bindings.selectedTab.wrappedValue == .viewer
  }
  check("false_settings_binding_is_not_finished_native_dismissal") {
   $0.windowSource?.ready = false
   return !$0.isPresentationReady(for: profiles) && !$0.isPresentationReady(for: overview)
  }
  check("missing_original_window_cannot_admit_cold_parent") {
   $0.windowSource = nil
   return !$0.isPresentationReady(for: profiles) && !$0.isPresentationReady(for: overview)
  }
  check("begun_unapplied_command_cannot_borrow_foreign_transition") {
   continuing($0, overview, applied: false)
   $0.workspacePresentation?.overview = .init(requested: true, transitioning: true)
   return !$0.isPresentationReady(for: overview)
  }
  check("begun_unapplied_command_cannot_skip_cold_window_gate") {
   continuing($0, profiles, applied: false)
   $0.windowSource?.ready = false
   return !$0.isPresentationReady(for: profiles)
  }
  check("retired_applied_proof_cannot_skip_cold_window_gate") {
   continuing($0, profiles)
   $0.workspacePresentation?.retainedProofValid = false
   $0.windowSource?.ready = false
   return !$0.isPresentationReady(for: profiles)
  }
  check("same_applied_source_can_wait_for_its_original_cold_mount") {
   continuing($0, profiles)
   $0.windowSource?.ready = false
   return $0.isPresentationReady(for: profiles)
  }
  check("stable_visible_original_profile_sheet_uses_its_own_witness") {
   $0.windowSource?.ready = false
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: true)
   return $0.isPresentationReady(for: profiles)
  }
  check("covered_original_profile_sheet_remains_unavailable") {
   $0.windowSource?.ready = false
   $0.workspacePresentation?.profiles = .init(requested: true, mounted: true, visible: false, transitioning: true)
   return !$0.isPresentationReady(for: profiles)
  }
  check("applied_request_for_other_parent_does_not_skip_cold_window_gate") {
   continuing($0, overview)
   $0.windowSource?.ready = false
   return !$0.isPresentationReady(for: profiles)
  }
  print("TOTAL passed=\(passed) failed=\(failed)")
  if failed != 0 { exit(1) }
 }
}
