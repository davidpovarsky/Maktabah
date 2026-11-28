# Original Apple component compilation: actual Debug and Release evidence

Four independent compilations passed on Xcode 27.0 (27A266a) with the installed iPhoneSimulator27.0 SDK. Each compilation used a new private scratch directory, the unchanged original resource and lifecycle guards, and the complete declared original source. No failed compilation was relabeled and no passing compilation was rerun to reconstruct a report.

| Component | Debug | Release | Exact compiled source scope |
| --- | --- | --- | --- |
| Host47 | 11 commands, all exit 0 | 11 commands, all exit 0 | Core31, UI13, Host47: 91 original Swift files plus 2 generated resource accessors |
| TorahInspectorKit414 | 17 commands, all exit 0 | 17 commands, all exit 0 | Complete original 169-file source tree; Core8 and UI15 Swift inputs plus 1 generated accessor; original EN/HE resources |

Host47 includes the proposed Library and BookInfo service/intents sources and does not include Inspector service/intents. Its actual source base and complete input manifest are recorded without promoting a proposal to integrated application acceptance. The later catalog794 localization compilation is preserved separately in wave3-native-localization-20261128.

Kit414 is the published original commit 414e0d3e95d53509381d233a23fcdd28ef24167a, tree294f57e29cdb414df4647358221755c3e2ebcf99. Both configurations compiled the original Core and SwiftUI implementation. Independent readback decoded four actual arm64 MH_OBJECT files with the iOS Simulator platform, reread modules/file lists/logs and compared all59 original EN and Hebrew entries with the compiled resources.

Each configuration directory contains the complete independently collected raw artifact archive and its Root proof. All194 archive members were reread and SHA256-joined again before this publication. Exact build jobs, original source trees, manifests, command results and object hashes are in ARTIFACTS.json and each archived RESULT.json.

These are component compiler results. The app Integration/PBX, Native116, Release114+2, actual Siri/Shortcuts/link delivery, complete fresh SDK and physical devices remain separate acceptance obligations. This commit changes documentation only and makes no TestFlight, signing, Archive or owner-approval claim.
