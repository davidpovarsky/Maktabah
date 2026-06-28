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
    let onChooseOtzaria: () -> Void

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
                HStack {
                    Button("Choose Otzaria Database", action: onChooseOtzaria)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(String(localized: "Download"), action: onDownload)
                        .buttonStyle(.borderedProminent)
                }

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
                HStack {
                    Button("Choose Otzaria Database", action: onChooseOtzaria)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(String(localized: "Try Again"), action: onDownload)
                        .buttonStyle(.borderedProminent)
                }
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
        case .confirmation: String(localized: "Ready to Download")
        case .downloading: String(localized: "Downloading")
        case .error: "Error"
        }
    }

    private var bodyText: String {
        return switch state.phase {
        case .confirmation:
            if state.totalSizeString.isEmpty {
                String(localized: "core.modal.message")
            } else {
                String(localized: .coreModalMessageDownloadsize(state.totalSizeString))
            }
        case .downloading: String(localized: "core.modal.downloading")
        case let .error(message): message
        }
    }

    private var isError: Bool {
        if case .error = state.phase { return true }
        return false
    }
}
