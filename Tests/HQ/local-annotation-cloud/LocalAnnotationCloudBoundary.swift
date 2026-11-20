import Foundation
import OSLog

// These settings are an explicit component boundary, not the live application
// defaults or a grant. Keeping iCloud false prevents construction of the real
// CKContainer in this non-entitled Foundation executable. Account/transport
// controls use the explicit internal client bundle; no request reaches CloudKit.
enum AppConfig {
    static let useICloud = false
    static let useCrossPlatformSync = false
    static let customWorkerURL = ""
}

extension Logger {
    static let sync = Logger(subsystem: "org.otzaria.local-cloud-acceptance", category: "sync")
}
