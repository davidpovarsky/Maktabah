//
//  CoreDownloadProgressView.swift
//  Maktabah
//
//  Created by MacBook on 18/03/26.
//

import SwiftUI

struct CoreDownloadProgressView: View {
    struct Configuration {
        let title: String
        let confirmationBadge: String
        let confirmationMessage: String
        let downloadingMessage: String
        let chooseTitle: String
        let cancelTitle: String?
        let downloadTitle: String
        let retryTitle: String
        let cancelDownloadTitle: String?
        let showsSearchComponents: Bool

        static let maktabah = Configuration(
            title: NSLocalizedString(
                "core.modal.title",
                value: "Database File Needed",
                comment: "Core download modal title"
            ),
            confirmationBadge: String(localized: "Factory Setting"),
            confirmationMessage: String(localized: "core.modal.message"),
            downloadingMessage: String(localized: "core.modal.downloading"),
            chooseTitle: String(localized: "Choose Library Folder…"),
            cancelTitle: String(localized: "Quit"),
            downloadTitle: String(localized: "Download"),
            retryTitle: String(localized: "Try Again"),
            cancelDownloadTitle: nil,
            showsSearchComponents: false
        )

        static let otzaria = Configuration(
            title: String(localized: "Otzaria Library Required"),
            confirmationBadge: String(localized: "Otzaria"),
            confirmationMessage: String(localized: "Install the library and recommended search data together, or continue with the library only."),
            downloadingMessage: String(localized: "Preparing the Otzaria Library…"),
            chooseTitle: String(localized: "Choose Otzaria Database…"),
            cancelTitle: String(localized: "Continue with library only"),
            downloadTitle: String(localized: "Download and install all"),
            retryTitle: String(localized: "Try Again"),
            cancelDownloadTitle: String(localized: "Cancel Download"),
            showsSearchComponents: true
        )
    }

    #if os(macOS)
    @ObservedObject var state: CoreDownloadProgressState
    #else
    var state: CoreDownloadProgressState
    #endif

    let onDownload: () -> Void
    let onChooseFolder: () -> Void
    let onQuit: () -> Void
    var configuration: Configuration = .maktabah
    var onCancelDownload: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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
                        .imageScale(.medium)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.title)
                    .font(.headline)

                    badgeView
                }
                Spacer(minLength: 0)
            }

            bodyText

            if configuration.showsSearchComponents, case .confirmation = state.phase {
                VStack(spacing: 8) {
                    searchComponent("Seforim DB", detail: "Required · 1.55 GB download · 7.87 GB installed", selected: true)
                    searchComponent("Otzaria lexical index", detail: "Recommended · 3.01 GB download · 4.11 GB installed", selected: true)
                    searchComponent("Zayit index", detail: "Recommended · separate versioned package", selected: true)
                    searchComponent("Shared lexical.db", detail: "Recommended · 57 MB", selected: true)
                }
            }

            switch state.phase {
            case .confirmation:
                confirmationButtons
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .downloading:
                downloadingProgress
            case .error(let msg):
                errorView(msg)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        #if os(macOS)
        .frame(width: 400)
        #else
        .frame(maxWidth: 400)
        #endif
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.2), value: state.phase)
        .animation(.linear(duration: 0.15), value: state.progress)
        .controlSize(.large)
    }

    private func searchComponent(_ title: String, detail: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        let label: String = {
            switch state.phase {
            case .confirmation:
                return configuration.confirmationBadge
            case .downloading:
                return String(localized: "Downloading")
            case .error:
                return String(localized: "Error")
            }
        }()

        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var bodyText: some View {
        switch state.phase {
        case .confirmation:
            let message = configuration.confirmationMessage
            if state.totalSizeString.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("\(message) (\(state.totalSizeString))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        case .downloading:
            Text(configuration.downloadingMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
        case .error(let msg):
            Text(msg)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
        }
    }

    private var confirmationButtons: some View {
        #if os(macOS)
        HStack(spacing: 12) { actionButtons }
        #else
        actionButtons
        #endif
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onChooseFolder) {
            Text(configuration.chooseTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        #if os(macOS)
        Spacer()
        #endif

        if let cancelTitle = configuration.cancelTitle {
            Button(action: onQuit) {
                Text(cancelTitle)
                #if os(iOS)
                    .frame(maxWidth: .infinity)
                #endif
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }

        Button(action: onDownload) {
            Text(configuration.downloadTitle)
            #if os(iOS)
                .frame(maxWidth: .infinity)
            #endif
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }

    private var downloadingProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: state.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack(alignment: .firstTextBaseline) {
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(
                    "\(Int((max(0, min(1, state.progress)) * 100).rounded()))%"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            if let cancelTitle = configuration.cancelDownloadTitle,
               let onCancelDownload {
                HStack {
                    Spacer()
                    Button(cancelTitle, action: onCancelDownload)
                        .buttonStyle(.bordered)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func errorView(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Spacer()
            Button(configuration.chooseTitle, action: onChooseFolder)
                .buttonStyle(.bordered)

            if let cancelTitle = configuration.cancelTitle {
                Button(cancelTitle, action: onQuit)
                    .buttonStyle(.bordered)
            }

            Button(
                configuration.retryTitle,
                action: onDownload
            )
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}


#Preview("Confirmation") {
    CoreDownloadProgressView(
        state: {
            let s = CoreDownloadProgressState()
            s.phase = .confirmation
            return s
        }(),
        onDownload: {},
        onChooseFolder: {},
        onQuit: {}
    )
    .padding()
}

#Preview("Downloading") {
    CoreDownloadProgressView(
        state: {
            let s = CoreDownloadProgressState()
            s.phase = .downloading
            s.progress = 0.42
            s.detail = "42.3 MB of 100 MB"  // ← jangan include % di sini
            return s
        }(),
        onDownload: {},
        onChooseFolder: {},
        onQuit: {}
    )
    .padding()
}

#Preview("Error") {
    CoreDownloadProgressView(
        state: {
            let s = CoreDownloadProgressState()
            s.phase = .error("Connection timed out. Check your internet connection.")
            return s
        }(),
        onDownload: {},
        onChooseFolder: {},
        onQuit: {}
    )
    .padding()
}
