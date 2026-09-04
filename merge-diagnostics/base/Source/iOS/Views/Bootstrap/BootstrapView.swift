//
//  BootstrapView.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 03/05/26.
//

import SwiftUI

struct iOSBootstrapView: View {
    @State private var bootstrapManager = iOSBootstrapManager()

    var body: some View {
        Group {
            if bootstrapManager.isReady {
                iOSMainView()
            } else {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()

                    if bootstrapManager.isChecking {
                        ProgressView("Preparing Library...")
                    } else {
                        iOSCoreDownloadGateView(
                            state: bootstrapManager.coreDownloadState,
                            onDownload: { bootstrapManager.startDownload() }
                        )
                        .padding()
                    }
                }
            }
        }
        .task {
            bootstrapManager.prepareIfNeeded()
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
