//
//  AppUpdate.swift
//  Maktabah
//
//  Created by MacBook on 21/01/26.
//

import AppKit
#if DIRECT_DISTRIBUTION
import Sparkle
#endif

extension AppDelegate {

    @MainActor
    func checkAppUpdates(_ atLaunch: Bool = true) async {
        #if DIRECT_DISTRIBUTION
        guard
            let isConnected =
                try? await ReusableFunc.checkInternetConnectivityDirectly(),
            isConnected
        else { return }

        let updater = updaterController.updater

        if atLaunch {
            updater.checkForUpdatesInBackground()
        } else {
            updater.checkForUpdates()
        }
        #else

        guard !atLaunch else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "Updates are managed by the App Store",
            comment: ""
        )
        alert.informativeText = NSLocalizedString(
            "Use the App Store to install the latest version of this build.",
            comment: ""
        )
        alert.alertStyle = .informational
        alert.runModal()
        #endif
    }
}

#if DIRECT_DISTRIBUTION
extension AppDelegate: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        AppConfig.appcastURL?.absoluteString
    }

    func updaterShouldPromptForPermissionToCheck(
        forUpdates updater: SPUUpdater
    ) -> Bool {
        false
    }
}
#endif
