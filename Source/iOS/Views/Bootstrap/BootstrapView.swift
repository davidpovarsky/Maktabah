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
                    Color(.systemBackground)
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
    }
}
