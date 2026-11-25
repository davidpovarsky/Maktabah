#if os(iOS)
import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
private final class AnnotationBackfillViewModel {
    enum State: Sendable, Equatable { case ready, preparing, completed, paused, failed }
    var state: State = .ready
    var total: Int64 = 0
    var scanned = 0
    var prepared = 0
    var metadataOnly = 0
    var pendingDeletion = 0
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var owner: AnnotationLocalEditorLifetime?
    @ObservationIgnored private var runID = UUID()

    func start() {
        guard state != .preparing else { return }
        let currentRun = UUID()
        let lifetime = AnnotationLocalEditorLifetime()
        let connection: AnnotationLocalEditorConnection
        do {
            connection = try AnnotationRepository.shared.captureLocalEditorConnection()
        } catch {
            state = .failed
            return
        }
        runID = currentRun
        owner = lifetime
        state = .preparing
        total = 0
        scanned = 0
        prepared = 0
        metadataOnly = 0
        pendingDeletion = 0
        worker = Task.detached(priority: .utility) { [weak self] in
            do {
                let planner = try AnnotationBackfillPlanner(connection: connection,
                    owner: lifetime, digest: AnnotationExchangePlatformDigest())
                let snapshot = try planner.inspect()
                await self?.begin(snapshot, run: currentRun)
                var cursor: Int64 = 0
                while true {
                    let batch = try planner.prepareBatch(snapshot, afterAnnotationID: cursor)
                    // Deliver every committed receipt, even when cancellation
                    // arrives immediately after the SQLite COMMIT.
                    await self?.accept(batch, run: currentRun)
                    cursor = batch.lastAnnotationID
                    if batch.isComplete { break }
                    try Task.checkCancellation()
                }
                await self?.finish(.completed, run: currentRun)
            } catch is CancellationError {
                await self?.finish(.paused, run: currentRun)
            } catch {
                await self?.finish(lifetime.isCurrent ? .failed : .paused, run: currentRun)
            }
            lifetime.retire()
        }
    }

    func cancel() {
        worker?.cancel()
        owner?.retire()
    }

    private func begin(_ snapshot: AnnotationBackfillSnapshot, run: UUID) {
        guard runID == run else { return }
        total = snapshot.sourceRowCount
    }

    private func accept(_ batch: AnnotationBackfillBatch, run: UUID) {
        guard runID == run else { return }
        scanned += batch.scanned
        prepared += batch.prepared + batch.reused
        metadataOnly += batch.metadataOnly
        pendingDeletion += batch.pendingDeletion
    }

    private func finish(_ result: State, run: UUID) {
        guard runID == run else { return }
        state = result
        owner = nil
        worker = nil
    }
}

@MainActor
struct AnnotationBackfillView: View {
    @State private var model = AnnotationBackfillViewModel()
    #if canImport(AnytypeOriginalEditor)
    @State private var nativeConversionIsRunning = false
    #endif

    var body: some View {
        Form {
            Section {
                Text("Prepare existing notes for expanded editing and sharing.",
                     tableName: "AnnotationBackfill")
                Text("This step keeps your saved notes in the current profile. Sharing remains a separate choice in the note editor.",
                     tableName: "AnnotationBackfill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.state != .ready {
                Section {
                    if model.state == .preparing {
                        ProgressView(value: Double(model.scanned), total: max(1, Double(model.total)))
                            .accessibilityIdentifier("annotation-backfill-progress")
                    }
                    Text(String(format: String(localized: "%lld notes ready",
                        table: "AnnotationBackfill"), Int64(model.prepared)))
                        .accessibilityIdentifier("annotation-backfill-ready-count")
                    if model.metadataOnly > 0 {
                        Text(String(format: String(localized: "%lld highlights kept as highlights",
                            table: "AnnotationBackfill"), Int64(model.metadataOnly)))
                    }
                    if model.pendingDeletion > 0 {
                        Text(String(format: String(localized: "%lld pending deletions kept unchanged",
                            table: "AnnotationBackfill"), Int64(model.pendingDeletion)))
                    }
                    switch model.state {
                    case .completed:
                        Label {
                            Text("Preparation complete", tableName: "AnnotationBackfill")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                        .accessibilityIdentifier("annotation-backfill-complete")
                    case .paused:
                        Text("Preparation paused. Continue whenever you are ready.",
                             tableName: "AnnotationBackfill")
                    case .failed:
                        Text("Preparation stopped because a saved note could not be verified. Your existing notes were kept. Reopen this page to retry.",
                             tableName: "AnnotationBackfill")
                            .accessibilityIdentifier("annotation-backfill-error")
                    case .ready, .preparing:
                        EmptyView()
                    }
                }
            }
            Section {
                if model.state == .preparing {
                    Button(role: .cancel) {
                        model.cancel()
                    } label: {
                        Text("Pause preparation", tableName: "AnnotationBackfill")
                    }
                    .accessibilityIdentifier("annotation-backfill-pause")
                } else {
                    Button {
                        model.start()
                    } label: {
                        Text(model.state == .ready ? "Prepare notes" : "Check and continue",
                             tableName: "AnnotationBackfill")
                    }
                    .accessibilityIdentifier("annotation-backfill-start")
                    #if canImport(AnytypeOriginalEditor)
                    .disabled(nativeConversionIsRunning)
                    #endif
                }
            }
            #if canImport(AnytypeOriginalEditor)
            AnnotationNativeBackfillSection(preparationCompleted: model.state == .completed,
                isRunning: $nativeConversionIsRunning)
            #endif
        }
        .navigationTitle(Text("Prepare existing notes", tableName: "AnnotationBackfill"))
        .onDisappear { model.cancel() }
    }
}
#endif
