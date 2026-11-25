import Foundation
import Dispatch
import notify
public func probeOriginalNotifyDeclarations(_ name: String) {
    var token: Int32 = 0
    let posted = name.withCString { notify_post($0) }
    let matched = posted == NOTIFY_STATUS_OK
    let registered = name.withCString {
        notify_register_dispatch($0, &token, DispatchQueue.main) { _ in }
    }
    let cancelled = notify_cancel(token)
    _ = (matched, registered, cancelled)
}
