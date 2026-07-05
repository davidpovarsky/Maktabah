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
                    } else {
                        iOSCoreDownloadGateView(
                            state: bootstrapManager.coreDownloadState,
                            onDownload: { bootstrapManager.startDownload() },
                            onChooseOtzaria: { showingOtzariaImporter = true }
                        )
                        .padding()
                    }
                }
            }
        }
        .task {
            bootstrapManager.prepareIfNeeded()
        }
        .fileImporter(
            isPresented: $showingOtzariaImporter,
            allowedContentTypes: [.database, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                bootstrapManager.installOtzariaDatabase(from: url)
            } else if case let .failure(error) = result {
                bootstrapManager.coreDownloadState.phase = .error(error.localizedDescription)
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
}
