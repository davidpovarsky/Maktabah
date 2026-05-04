//
//  CoreDownloaderGateView.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 03/05/26.
//

import SwiftUI

struct iOSCoreDownloadGateView: View {
    var state: CoreDownloadProgressState
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.65),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "cylinder.split.1x2.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Database File Needed")
                        .font(.headline)

                    Text(badgeText)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text(bodyText)
                .font(.callout)
                .foregroundStyle(isError ? .red : .secondary)

            switch state.phase {
            case .confirmation:
                Button("Download", action: onDownload)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)

            case .downloading:
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: state.progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Text("\(Int((max(0, min(1, state.progress)) * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

            case .error:
                Button("Try Again", action: onDownload)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .frame(maxWidth: 420)
    }

    private var badgeText: String {
        switch state.phase {
        case .confirmation: "Ready to Download"
        case .downloading: "Downloading"
        case .error: "Error"
        }
    }

    private var bodyText: String {
        switch state.phase {
        case .confirmation: "This app needs the core database files before the library can be used."
        case .downloading: "Downloading database. Please wait…"
        case let .error(message): message
        }
    }

    private var isError: Bool {
        if case .error = state.phase { return true }
        return false
    }
}
