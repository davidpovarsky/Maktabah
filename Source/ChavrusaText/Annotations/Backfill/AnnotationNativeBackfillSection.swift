#if os(iOS) && canImport(AnytypeOriginalEditor)
import SwiftUI

/// An explicit second step in the existing preparation screen. Rendering this
/// section performs no database scan, native initialization or conversion.
@MainActor
struct AnnotationNativeBackfillSection: View {
    @Environment(\.exact9401Workspace) private var workspace
    let preparationCompleted: Bool
    @Binding var isRunning: Bool
    @State private var model = AnnotationNativeBackfillModel()
    @State private var confirming = false

    var body: some View {
        Section {
            Text("Convert saved notes to expanded editing", tableName: "AnnotationBackfill")
                .font(.headline)
            Text("Only saved notes are converted. Sharing with Anytype remains a separate choice. Existing rich notes and notes beyond the supported size remain unchanged.",
                 tableName: "AnnotationBackfill")
                .font(.footnote).foregroundStyle(.secondary)
            if model.state != .ready {
                if model.isRunning {
                    ProgressView(value: Double(model.scanned), total: max(1, Double(model.total)))
                        .accessibilityIdentifier("annotation-native-backfill-progress")
                }
                countRow(String(localized: "%lld notes converted", table: "AnnotationBackfill"),
                         value: model.converted, identifier: "annotation-native-backfill-converted", showZero: true)
                countRow(String(localized: "%lld rich notes kept unchanged", table: "AnnotationBackfill"),
                         value: model.count(.existingRich), identifier: "annotation-native-backfill-rich")
                countRow(String(localized: "%lld notes beyond the supported size kept unchanged", table: "AnnotationBackfill"),
                         value: model.count(.longNote), identifier: "annotation-native-backfill-long")
                countRow(String(localized: "%lld notes need preparation again", table: "AnnotationBackfill"),
                         value: model.count(.needsPreparation), identifier: "annotation-native-backfill-unprepared")
                countRow(String(localized: "%lld changed notes kept unchanged", table: "AnnotationBackfill"),
                         value: model.count(.changed), identifier: "annotation-native-backfill-changed")
                countRow(String(localized: "%lld unsupported notes kept unchanged", table: "AnnotationBackfill"),
                         value: model.count(.unsupported), identifier: "annotation-native-backfill-unsupported")
                countRow(String(localized: "%lld notes need manual review and remain unchanged", table: "AnnotationBackfill"),
                         value: model.count(.previewMismatch), identifier: "annotation-native-backfill-preview-mismatch")
                countRow(String(localized: "%lld highlights kept as highlights", table: "AnnotationBackfill"),
                         value: model.count(.metadataOnly), identifier: "annotation-native-backfill-highlights")
                countRow(String(localized: "%lld pending deletions kept unchanged", table: "AnnotationBackfill"),
                         value: model.count(.pendingDeletion), identifier: "annotation-native-backfill-deletions")
                status
            }
            if model.state == .closeFailed {
                Button { model.retryClose() } label: {
                    Text("Finish closing the private editor", tableName: "AnnotationBackfill")
                }
                .accessibilityIdentifier("annotation-native-backfill-close-retry")
            } else if model.isRunning {
                Button(role: .cancel) { model.pause() } label: {
                    Text("Pause conversion", tableName: "AnnotationBackfill")
                }
                .disabled(model.state == .closing || model.state == .pausing)
                .accessibilityIdentifier("annotation-native-backfill-pause")
            } else {
                Button { confirming = true } label: {
                    Text(model.state == .ready ? "Convert saved notes" : "Check and continue conversion",
                         tableName: "AnnotationBackfill")
                }
                .disabled(!preparationCompleted || workspace == nil)
                .accessibilityIdentifier("annotation-native-backfill-start")
            }
            if !preparationCompleted {
                Text("Prepare the existing notes above before starting conversion.", tableName: "AnnotationBackfill")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if workspace == nil {
                Text("Open preparation from the current study workspace to convert its notes.", tableName: "AnnotationBackfill")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("annotation-native-backfill-workspace-unavailable")
            }
        }
        .confirmationDialog(Text("Convert these saved notes?", tableName: "AnnotationBackfill"),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button {
                guard let workspace else { return }
                model.start(workspace: workspace, preparationCompleted: preparationCompleted)
            } label: {
                Text("Convert saved notes", tableName: "AnnotationBackfill")
            }
            .accessibilityIdentifier("annotation-native-backfill-confirm")
            Button(role: .cancel) {} label: { Text("Cancel", tableName: "AnnotationBackfill") }
                .accessibilityIdentifier("annotation-native-backfill-cancel-confirmation")
        } message: {
            Text("The original editor will preserve each complete saved note before saving its expanded format. Saved changes follow your existing iCloud settings. You can pause and continue; notes already converted will be kept.",
                 tableName: "AnnotationBackfill")
        }
        .onChange(of: model.isRunning) { _, running in isRunning = running }
        .onDisappear { model.pause() }
    }

    @ViewBuilder
    private func countRow(_ format: String, value: Int, identifier: String, showZero: Bool = false) -> some View {
        if value > 0 || showZero {
            Text(String(format: format, Int64(value))).accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.state {
        case .completed:
            Label {
                Text("Conversion scan complete", tableName: "AnnotationBackfill")
            } icon: { Image(systemName: "checkmark.circle") }
                .accessibilityIdentifier("annotation-native-backfill-complete")
        case .paused:
            if model.batchLimitReached {
                Text("This conversion run reached its 5,000-note limit. Continue to check the remaining notes.",
                     tableName: "AnnotationBackfill")
                    .accessibilityIdentifier("annotation-native-backfill-batch-limit")
            }
            Text("Conversion paused. Saved conversions are kept; continue to check the remaining notes.",
                 tableName: "AnnotationBackfill")
                .accessibilityIdentifier("annotation-native-backfill-paused")
        case .failed:
            Text("Conversion stopped because a saved note or the original editor could not be verified. Saved conversions are kept; other notes remain unchanged.",
                 tableName: "AnnotationBackfill")
                .accessibilityIdentifier("annotation-native-backfill-failed")
        case .closeFailed:
            Text("The private editor has not finished closing. Close any other expanded editor, then retry closing here.",
                 tableName: "AnnotationBackfill")
                .accessibilityIdentifier("annotation-native-backfill-close-failed")
        case .closing:
            Text("Closing the private editor…", tableName: "AnnotationBackfill")
        case .pausing:
            Text("Pausing conversion…", tableName: "AnnotationBackfill")
        case .ready, .running:
            EmptyView()
        }
    }
}
#endif
