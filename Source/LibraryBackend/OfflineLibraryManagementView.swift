#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class OfflineLibraryManagementViewModel: ObservableObject {
    @Published var packages: [OfflinePackage] = []
    @Published var installed: Set<String> = []
    @Published var selected: Set<String> = []
    @Published var progress: OfflineInstallProgress?
    @Published var updateSummary: OfflineUpdateSummary?
    @Published var errorMessage: String?
    @Published var isWorking = false

    private var work: Task<Void, Never>?

    func load(force: Bool = false) {
        work?.cancel()
        work = Task {
            guard let provider = BackendCoordinator.shared.offlineProvider() else { return }
            do {
                packages = try await provider.packages(forceRefresh: force)
                installed = await provider.installedPackageIDs()
                selected = installed
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func apply() {
        work?.cancel()
        isWorking = true
        work = Task {
            guard let provider = BackendCoordinator.shared.offlineProvider() else { isWorking = false; return }
            do {
                selected = Set(OfflinePackageSelection.resolve(selected, from: packages).map(\.id))
                let removals = installed.subtracting(selected)
                if !removals.isEmpty { try await provider.remove(packageIDs: removals) }
                let additions = selected.subtracting(installed)
                if !additions.isEmpty {
                    try await provider.install(packageIDs: additions) { [weak self] update in
                        Task { @MainActor in self?.progress = update }
                    }
                }
                installed = await provider.installedPackageIDs()
            } catch is CancellationError {
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }

    func checkForUpdates() {
        work?.cancel()
        work = Task {
            guard let provider = BackendCoordinator.shared.offlineProvider() else { return }
            do { updateSummary = try await provider.availableUpdates() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func update() {
        work?.cancel()
        isWorking = true
        work = Task {
            guard let provider = BackendCoordinator.shared.offlineProvider() else { isWorking = false; return }
            do {
                try await provider.update { [weak self] update in
                    Task { @MainActor in self?.progress = update }
                }
                updateSummary = try await provider.availableUpdates()
            } catch is CancellationError {
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }

    func cancel() {
        work?.cancel()
        Task { await BackendCoordinator.shared.offlineProvider()?.cancelInstall() }
        isWorking = false
    }
}

struct OfflineLibraryManagementView: View {
    @StateObject private var model = OfflineLibraryManagementViewModel()

    var body: some View {
        List {
            if let update = model.updateSummary, update.hasUpdates {
                Section("Updates") {
                    Text("\(update.changedWorkCount) downloaded works have updates.")
                    Button("Update Downloaded Library") { model.update() }
                        .disabled(model.isWorking)
                }
            }
            if let progress = model.progress, model.isWorking {
                Section("Progress") {
                    ProgressView(value: progress.totalBytes > 0
                        ? Double(progress.completedBytes) / Double(progress.totalBytes) : nil)
                    Text([progress.phase.rawValue.capitalized, progress.packageID].compactMap { $0 }.joined(separator: " — "))
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Cancel", role: .destructive) { model.cancel() }
                }
            }
            Section("Sefaria Packages") {
                ForEach(model.packages) { package in
                    Button { model.toggle(package.id) } label: {
                        HStack {
                            Image(systemName: model.selected.contains(package.id) ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading) {
                                Text(package.heTitle ?? package.title)
                                Text(ByteCountFormatter.string(fromByteCount: package.compressedSize, countStyle: .file))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.installed.contains(package.id) { Text("Downloaded").font(.caption) }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Offline Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Apply") { model.apply() }.disabled(model.isWorking) }
            ToolbarItem(placement: .secondaryAction) {
                Button("Check for Updates") { model.checkForUpdates() }
            }
        }
        .task { model.load() }
        .alert("Offline Library", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
#endif
