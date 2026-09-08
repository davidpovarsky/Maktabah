//
//  BootstrapView.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 03/05/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct iOSBootstrapView: View {
    @State private var bootstrapManager = iOSBootstrapManager()
    @State private var showingOtzariaImporter = false

    var body: some View {
        Group {
            if bootstrapManager.isReady {
                iOSMainView()
            } else {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()

                    if bootstrapManager.isChecking {
                        ProgressView(String(localized: "Preparing Library..."))
                    } else if bootstrapManager.requiresInitialSourceSelection {
                        BootstrapSourceSelectionView { source in
                            bootstrapManager.selectInitialSource(source)
                        }
                        .padding()
                    } else {
                        CoreDownloadProgressView(
                            state: bootstrapManager.coreDownloadState,
                            onDownload: { bootstrapManager.startDownload() },
                            onChooseFolder: { showingOtzariaImporter = true },
                            onQuit: { bootstrapManager.continueWithLibraryOnly() },
                            configuration: .otzaria,
                            onCancelDownload: { bootstrapManager.cancelManagedDownload() }
                        )
                        .padding()
                    }
                }
            }
        }
        .task {
            await bootstrapManager.prepareIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requireCoreDownload)) { notification in
            let isCancellable = notification.userInfo?["isCancellable"] as? Bool ?? false
            bootstrapManager.reloadLibrary(isCancellable: isCancellable)
        }
        .fileImporter(
            isPresented: $showingOtzariaImporter,
            allowedContentTypes: [.database, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                bootstrapManager.installOtzariaDatabase(from: url)
            } else if case .failure = result {
                bootstrapManager.handleDatabaseImportFailure()
            }
        }
        .onChange(of: bootstrapManager.isReady) { oldValue, newValue in
            if newValue, AppConfig.useICloud {
                CloudKitSyncManager.shared.fetchChanges()
            }
        }
        .overlay {
            if bootstrapManager.showCoreUpdateAlert {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { }
                        .simultaneousGesture(DragGesture())

                    CoreUpdateAlertView(
                        newVersion: bootstrapManager.availableCoreVersion ?? "",
                        onUpdate: { bootstrapManager.performCoreUpdate() },
                        onDismiss: { bootstrapManager.showCoreUpdateAlert = false }
                    )
                    .zIndex(1)
                }
            }

            if bootstrapManager.isUpdating {
                iOSCoreUpdateProgressOverlayView(
                    state: bootstrapManager.coreDownloadState
                )
            }
        }
    }

    private func cancellation() {
        if bootstrapManager.isCancellable {
            bootstrapManager.cancelDownload()
        } else {
            ReusableFunc.showAlert(
                title: "core.modal.missingFiles.title".localized,
                message: "Database File Needed".localized
            )
        }
    }
}

private struct BootstrapSourceSelectionView: View {
    let onSelect: (BackendID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.white)
                        .imageScale(.medium)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "bootstrap.source.title"))
                        .font(.headline)
                    Text(String(localized: "bootstrap.source.badge"))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(String(localized: "bootstrap.source.message"))
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                sourceButton(
                    title: String(localized: "bootstrap.source.otzaria.title"),
                    detail: String(localized: "bootstrap.source.otzaria.detail"),
                    systemImage: "externaldrive.fill",
                    source: .otzaria
                )
                sourceButton(
                    title: String(localized: "bootstrap.source.sefaria.title"),
                    detail: String(localized: "bootstrap.source.sefaria.detail"),
                    systemImage: "cloud.fill",
                    source: .sefaria
                )
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .frame(maxWidth: 400)
        .fixedSize(horizontal: false, vertical: true)
        .controlSize(.large)
    }

    private func sourceButton(
        title: String,
        detail: String,
        systemImage: String,
        source: BackendID
    ) -> some View {
        Button { onSelect(source) } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}
