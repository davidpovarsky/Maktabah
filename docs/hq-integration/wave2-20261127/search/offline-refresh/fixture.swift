import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

typealias ZayitSearchArtifactManifest = String
__ACTUAL_PACKAGE_STATE__
__ACTUAL_DISTRIBUTION_ERROR__

enum ZayitSearchExistingDatabaseProvider {
    static let currentURL: URL? = URL(fileURLWithPath: "/owned-control/seforim.db")
}

actor ZayitSearchArtifactService {
    enum Discovery: Sendable { case transportFailure, unavailable, updated, ready, removeThenFail }
    static let shared = ZayitSearchArtifactService()
    private var installed: ZayitSearchPackageState = .notInstalled
    private var discovery: Discovery = .transportFailure
    private(set) var requests = 0
    func configure(_ installed: ZayitSearchPackageState, _ discovery: Discovery) {
        self.installed = installed
        self.discovery = discovery
        requests = 0
    }
    func status(databaseURL: URL?) -> ZayitSearchPackageState { installed }
    func discover(databaseURL: URL) throws -> ZayitSearchPackageState {
        requests += 1
        switch discovery {
        case .transportFailure: throw URLError(.notConnectedToInternet)
        case .unavailable: throw ZayitSearchDistributionError.unavailable
        case .updated: return .updateAvailable(installed: "valid-installed", available: "published-update")
        case .ready: return installed
        case .removeThenFail:
            installed = .notInstalled
            throw URLError(.networkConnectionLost)
        }
    }
}

@MainActor final class OriginalRefreshSubject {
    var state: ZayitSearchPackageState = .notInstalled
__ACTUAL_REFRESH_METHOD__
}

@main struct RefreshControls {
    @MainActor static func main() async {
        let service = ZayitSearchArtifactService.shared
        var passes = 0
        var failures = 0
        func check(_ condition: Bool, _ name: String) {
            if condition { passes += 1; print("PASS " + name) }
            else { failures += 1; print("FAIL " + name) }
        }
        await service.configure(.ready("valid-installed"), .transportFailure)
        let validOffline = OriginalRefreshSubject()
        await validOffline.refresh(discover: true)
        check(validOffline.state == .ready("valid-installed"), "validated installation remains ready after transport failure")

        await service.configure(.ready("valid-installed"), .unavailable)
        let noRelease = OriginalRefreshSubject()
        await noRelease.refresh(discover: true)
        check(noRelease.state == .ready("valid-installed"), "validated installation remains ready when public catalogue is unavailable")

        await service.configure(.notInstalled, .transportFailure)
        let missing = OriginalRefreshSubject()
        await missing.refresh(discover: true)
        if case .failed = missing.state { check(true, "missing package never becomes ready after network failure") }
        else { check(false, "missing package never becomes ready after network failure") }

        await service.configure(.repairRequired("checksum mismatch"), .transportFailure)
        let damaged = OriginalRefreshSubject()
        await damaged.refresh(discover: true)
        check(!damaged.state.isReady, "corrupt package cannot be made ready by fallback")

        await service.configure(.ready("valid-installed"), .updated)
        let updated = OriginalRefreshSubject()
        await updated.refresh(discover: true)
        check(updated.state == .updateAvailable(installed: "valid-installed", available: "published-update"),
              "successful original discovery still reports a published update")

        await service.configure(.ready("valid-installed"), .transportFailure)
        let local = OriginalRefreshSubject()
        await local.refresh(discover: false)
        let requestCount = await service.requests
        check(local.state == .ready("valid-installed") && requestCount == 0,
              "local refresh does not send a discovery request")

        await service.configure(.ready("valid-installed"), .removeThenFail)
        let removed = OriginalRefreshSubject()
        await removed.refresh(discover: true)
        check(!removed.state.isReady, "removal during discovery cannot restore stale readiness")

        await service.configure(.ready("valid-installed"), .ready)
        let online = OriginalRefreshSubject()
        await online.refresh(discover: true)
        check(online.state == .ready("valid-installed"), "successful discovery retains original ready package")

        print("RESULT passes=\(passes) failures=\(failures)")
        exit(failures == 0 ? 0 : 1)
    }
}
