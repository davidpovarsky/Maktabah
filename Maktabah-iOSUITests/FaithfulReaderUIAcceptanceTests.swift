import XCTest
import UIKit
import Vision

/// XCTest executes teardown blocks even when an assertion aborts a test method.
/// Keep Simulator-wide state restoration independent of that method's stack.
@MainActor
private final class NativeUIRestoration {
    let restore: @MainActor () async -> Void
    init(_ restore: @escaping @MainActor () async -> Void) { self.restore = restore }
    func run() async { await restore() }
}


/// Retains values from the snapshot/query that actually failed. Decimal strings
/// and IEEE-754 bits preserve coordinates that XCTest's rounded tree omits.
@MainActor
private enum NativeGeometryEvidence {
    static func frame(_ frame: CGRect) -> [String: Any] {
        let values: [String: Double] = [
            "x": Double(frame.origin.x), "y": Double(frame.origin.y),
            "width": Double(frame.size.width), "height": Double(frame.size.height),
            "minX": Double(frame.minX), "minY": Double(frame.minY),
            "maxX": Double(frame.maxX), "maxY": Double(frame.maxY)
        ]
        return [
            "decimal": values.mapValues { String($0) },
            "ieee754Hex": values.mapValues { String($0.bitPattern, radix: 16) },
            "finitePositive": GroupStressSnapshot.finitePositive(frame),
            "isNull": frame.isNull, "isInfinite": frame.isInfinite, "isEmpty": frame.isEmpty
        ]
    }

    static func element(_ element: any XCUIElementSnapshot) -> [String: Any] {
        ["identifier": element.identifier, "label": element.label,
         "type": String(describing: element.elementType), "enabled": element.isEnabled,
         "frame": frame(element.frame)]
    }

    static func text(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { return text }
        return String(reflecting: value)
    }
}

/// XCTest still invokes some legacy synchronous callers outside an actor.
/// Establish the real main queue before entering the native observer; only
/// Sendable observer ownership or diagnostic values cross this synchronous seam.
private enum NativeCaptureMainActorEntry {
    static func run<Value: Sendable>(_ operation: @MainActor () -> Value) -> Value {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { operation() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { operation() }
        }
    }
}

/// One fresh native snapshot per predicate evaluation, with current live hit
/// testing. No snapshot or element geometry survives into the next evaluation.
@MainActor
private final class NativeCaptureSettlementObservation {
    let application: XCUIApplication
    let windowed: Bool
    private(set) var evaluations: [[String: Any]] = []
    private var evaluationCount = 0

    init(application: XCUIApplication, windowed: Bool) {
        self.application = application
        self.windowed = windowed
    }

    func settled() -> Bool {
        let started = ProcessInfo.processInfo.systemUptime
        evaluationCount += 1
        var record: [String: Any] = ["evaluation": evaluationCount, "windowed": windowed]
        var querySeconds: [String: Double] = [:]
        var accepted = false
        defer {
            record["accepted"] = accepted
            record["querySeconds"] = querySeconds
            record["elapsedSeconds"] = ProcessInfo.processInfo.systemUptime - started
            if evaluations.count == 32 { evaluations.removeFirst() }
            evaluations.append(record)
        }
        func observed<T>(_ name: String, _ query: () -> T) -> T {
            let start = ProcessInfo.processInfo.systemUptime
            let value = query()
            querySeconds[name] = ProcessInfo.processInfo.systemUptime - start
            return value
        }
        let snapshotStart = ProcessInfo.processInfo.systemUptime
        let snapshot: any XCUIElementSnapshot
        do { snapshot = try application.snapshot() }
        catch {
            querySeconds["appSnapshot"] = ProcessInfo.processInfo.systemUptime - snapshotStart
            record["gate"] = "app_snapshot_unavailable"
            record["error"] = String(describing: error)
            return false
        }
        querySeconds["appSnapshot"] = ProcessInfo.processInfo.systemUptime - snapshotStart
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        guard let window = elements.first(where: { $0.elementType == .window }) else {
            record["gate"] = "actual_window_missing"
            return false
        }
        let frame = window.frame
        let landscape = observed("orientation") { XCUIDevice.shared.orientation.isLandscape }
        record["window"] = NativeGeometryEvidence.frame(frame)
        record["landscape"] = landscape
        record["windowFinitePositive"] = GroupStressSnapshot.finitePositive(frame)
        record["orientationMatches"] = windowed || (frame.width > frame.height) == landscape
        guard GroupStressSnapshot.finitePositive(frame),
              windowed || (frame.width > frame.height) == landscape else {
            record["gate"] = "actual_window_or_orientation"
            return false
        }

        let reader = application.textViews["reader-text"]
        let readerExists = observed("readerExists") { reader.exists }
        let readerHittable = readerExists && observed("readerHittable") { reader.isHittable }
        record["readerExists"] = readerExists
        record["readerHittable"] = readerHittable
        record["readerSnapshotCount"] = elements.filter {
            $0.elementType == .textView && GroupStressSnapshot.matches($0, identifying: "reader-text")
        }.count
        // Preserve the original modal/non-Reader branch; do not require an
        // obscured Reader's toolbar while another original surface owns input.
        guard readerExists && readerHittable else {
            let liveWindow = observed("liveWindowFrame") { application.windows.firstMatch.frame }
            record["liveWindow"] = NativeGeometryEvidence.frame(liveWindow)
            record["windowCurrent"] = liveWindow == frame
            record["gate"] = "reader_absent_or_not_hittable"
            accepted = liveWindow == frame
            return accepted
        }

        func eligible(_ identifier: String) -> [(any XCUIElementSnapshot, XCUIElement)]? {
            let candidates = elements.filter {
                $0.elementType == .button && $0.identifier == identifier
            }
            record[identifier + "SnapshotCount"] = candidates.count
            var observations: [[String: Any]] = []
            defer { record[identifier + "Candidates"] = observations }
            var result: [(any XCUIElementSnapshot, XCUIElement)] = []
            let query = application.buttons.matching(identifier: identifier)
            let liveCount = observed(identifier + ".liveCount") { query.count }
            record[identifier + "LiveCount"] = liveCount
            guard liveCount == candidates.count else {
                record["gate"] = "toolbar_snapshot_live_count_mismatch"
                return nil
            }
            for (index, candidate) in candidates.enumerated() {
                let candidateFrame = candidate.frame
                let finite = GroupStressSnapshot.finitePositive(candidateFrame)
                let intersects = candidateFrame.intersects(frame)
                var details = NativeGeometryEvidence.element(candidate)
                details["queryIndex"] = index
                details["intersectsWindow"] = intersects
                details["containsInWindow"] = frame.contains(candidateFrame)
                let live = query.element(boundBy: index)
                let queryStart = ProcessInfo.processInfo.systemUptime
                let current: any XCUIElementSnapshot
                do { current = try live.snapshot() }
                catch {
                    querySeconds[identifier + "[\(index)].liveSnapshot"] =
                        ProcessInfo.processInfo.systemUptime - queryStart
                    details["liveSnapshotError"] = String(describing: error)
                    observations.append(details)
                    record["gate"] = "toolbar_live_snapshot_unavailable"
                    return nil
                }
                querySeconds[identifier + "[\(index)].liveSnapshot"] =
                    ProcessInfo.processInfo.systemUptime - queryStart
                let identityMatches = current.elementType == .button
                    && current.identifier == candidate.identifier && current.label == candidate.label
                let frameMatches = current.frame == candidateFrame
                details["liveSnapshot"] = NativeGeometryEvidence.element(current)
                details["sameIdentityAtIndex"] = identityMatches
                details["sameFrameAtIndex"] = frameMatches
                // Count and the actual identity/frame at each query index bind
                // the live domain to this evaluation's original app snapshot.
                guard identityMatches && frameMatches else {
                    observations.append(details)
                    record["gate"] = "toolbar_snapshot_live_order_or_geometry_mismatch"
                    return nil
                }
                if finite && intersects {
                    let hittable = observed(identifier + "[\(index)].isHittable") { live.isHittable }
                    details["liveHittable"] = hittable
                    if hittable { result.append((candidate, live)) }
                } else {
                    details["liveHittable"] = "not_queried_outside_original_geometry_gate"
                }
                observations.append(details)
            }
            record[identifier + "EligibleCount"] = result.count
            return result
        }
        guard let more = eligible("reader-more-menu") else { return false }
        let actions: [(any XCUIElementSnapshot, XCUIElement)]
        if more.isEmpty {
            guard let overflow = eligible("BottomOverflowBarButtonItem") else { return false }
            actions = overflow
        } else {
            actions = more
        }
        record["eligibleActionCount"] = actions.count
        guard actions.count == 1, let (button, liveButton) = actions.first else {
            record["gate"] = "unique_visible_original_toolbar_action"
            return false
        }
        let buttonFrame = button.frame
        let liveButtonFrame = observed("chosenLiveButtonFrame") { liveButton.frame }
        let liveWindowFrame = observed("liveWindowFrame") { application.windows.firstMatch.frame }
        record["chosenButton"] = NativeGeometryEvidence.element(button)
        record["liveButton"] = NativeGeometryEvidence.frame(liveButtonFrame)
        record["liveWindow"] = NativeGeometryEvidence.frame(liveWindowFrame)
        record["buttonCurrent"] = liveButtonFrame == buttonFrame
        record["windowCurrent"] = liveWindowFrame == frame
        record["exactWindowContainsButton"] = frame.contains(buttonFrame)
        let originalGeometry = windowed
            ? buttonFrame.width > 0 && buttonFrame.height > 0
            : frame.contains(buttonFrame)
        record["originalGeometryGate"] = originalGeometry
        record["gate"] = "current_original_toolbar_geometry"
        accepted = liveButtonFrame == buttonFrame && liveWindowFrame == frame && originalGeometry
        return accepted
    }
}

/// Retain one actual app snapshot for all geometry in an evaluation. Scoped
/// live snapshots and real hit tests bind that same geometry to the current
/// original palette/query domain; later screenshots never substitute for it.
@MainActor
private final class NativeLibraryPaletteSettlementObservation {
    let application: XCUIApplication
    let palette: XCUIElement
    let result: XCUIElement
    private(set) var evaluations: [[String: Any]] = []
    private var evaluationCount = 0

    init(application: XCUIApplication, palette: XCUIElement, result: XCUIElement) {
        self.application = application
        self.palette = palette
        self.result = result
    }

    func settled() -> Bool {
        let started = ProcessInfo.processInfo.systemUptime
        evaluationCount += 1
        var record: [String: Any] = ["evaluation": evaluationCount]
        var querySeconds: [String: Double] = [:]
        var accepted = false
        defer {
            record["accepted"] = accepted
            record["querySeconds"] = querySeconds
            record["elapsedSeconds"] = ProcessInfo.processInfo.systemUptime - started
            if evaluations.count == 32 { evaluations.removeFirst() }
            evaluations.append(record)
        }
        func observed<T>(_ name: String, _ query: () -> T) -> T {
            let start = ProcessInfo.processInfo.systemUptime
            let value = query()
            querySeconds[name] = ProcessInfo.processInfo.systemUptime - start
            return value
        }
        func currentSnapshot(_ name: String, of element: XCUIElement) -> (any XCUIElementSnapshot)? {
            let start = ProcessInfo.processInfo.systemUptime
            defer { querySeconds[name] = ProcessInfo.processInfo.systemUptime - start }
            do { return try element.snapshot() }
            catch {
                record["gate"] = name + "_unavailable"
                record["error"] = String(describing: error)
                return nil
            }
        }
        guard let snapshot = currentSnapshot("appSnapshot", of: application) else { return false }
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        guard let window = elements.first(where: { $0.elementType == .window }) else {
            record["gate"] = "actual_window_missing"
            return false
        }
        let palettes = elements.filter { $0.identifier == "reader-library-command-palette" }
        record["paletteSnapshotCount"] = palettes.count
        guard palettes.count == 1, let originalPalette = palettes.first else {
            record["gate"] = "unique_original_palette_missing"
            return false
        }
        let children = GroupStressSnapshot.descendants(of: originalPalette)
        let inputs = children.filter { $0.elementType == .textField }
        record["inputSnapshotCount"] = inputs.count
        guard inputs.count == 1, let originalInput = inputs.first else {
            record["gate"] = "unique_original_input_missing"
            return false
        }
        let landscape = observed("orientation") { XCUIDevice.shared.orientation.isLandscape }
        let input = palette.textFields.firstMatch
        // Hittability stays a real live query on the caller's original elements.
        // Scoped snapshots below reject identity/order/geometry changes across it.
        let inputHittable = observed("inputHittable") { input.isHittable }
        let resultHittable = observed("resultHittable") { result.isHittable }
        record["inputHittable"] = inputHittable
        record["resultHittable"] = resultHittable
        guard let livePalette = currentSnapshot("livePaletteSnapshot", of: palette),
              let liveResult = currentSnapshot("liveResultSnapshot", of: result) else { return false }
        record["livePalette"] = NativeGeometryEvidence.element(livePalette)
        record["liveResult"] = NativeGeometryEvidence.element(liveResult)
        guard liveResult.elementType == .button, !liveResult.identifier.isEmpty else {
            record["gate"] = "actual_original_result_identity_missing"
            return false
        }
        let results = children.filter {
            $0.elementType == .button && $0.identifier == liveResult.identifier
                && $0.label == liveResult.label
        }
        record["resultSnapshotCount"] = results.count
        guard results.count == 1, let originalResult = results.first else {
            record["gate"] = "live_result_not_unique_in_same_original_palette_snapshot"
            return false
        }
        let currentInputs = GroupStressSnapshot.descendants(of: livePalette).filter {
            $0.elementType == .textField
        }
        record["livePaletteInputCount"] = currentInputs.count
        let inputCurrent = currentInputs.count == 1 && currentInputs.first.map {
            $0.elementType == originalInput.elementType && $0.identifier == originalInput.identifier
                && $0.label == originalInput.label && $0.frame == originalInput.frame
        } == true
        let paletteCurrent = livePalette.elementType == originalPalette.elementType
            && livePalette.identifier == originalPalette.identifier && livePalette.label == originalPalette.label
            && livePalette.frame == originalPalette.frame
        let resultCurrent = liveResult.frame == originalResult.frame
        let windowFrame = window.frame
        let paletteFrame = originalPalette.frame
        let inputFrame = originalInput.frame
        let resultFrame = originalResult.frame
        let liveWindowFrame = observed("liveWindowFrame") { application.windows.firstMatch.frame }
        let finite = [windowFrame, paletteFrame, inputFrame, resultFrame]
            .allSatisfy { GroupStressSnapshot.finitePositive($0) }
        let orientationMatches = (windowFrame.width > windowFrame.height) == landscape
        let windowContainsPalette = windowFrame.contains(paletteFrame)
        let paletteContainsInput = paletteFrame.contains(inputFrame)
        let paletteContainsResult = paletteFrame.contains(resultFrame)
        record["window"] = NativeGeometryEvidence.frame(windowFrame)
        record["palette"] = NativeGeometryEvidence.element(originalPalette)
        record["input"] = NativeGeometryEvidence.element(originalInput)
        record["result"] = NativeGeometryEvidence.element(originalResult)
        record["liveInput"] = currentInputs.first.map { NativeGeometryEvidence.element($0) }
        record["liveWindow"] = NativeGeometryEvidence.frame(liveWindowFrame)
        record["allFramesFinitePositive"] = finite
        record["orientationMatches"] = orientationMatches
        record["windowContainsPalette"] = windowContainsPalette
        record["paletteContainsInput"] = paletteContainsInput
        record["paletteContainsResult"] = paletteContainsResult
        record["paletteCurrent"] = paletteCurrent
        record["inputCurrent"] = inputCurrent
        record["resultCurrent"] = resultCurrent
        record["windowCurrent"] = liveWindowFrame == windowFrame
        record["gate"] = "same_snapshot_geometry_current_native_controls_and_live_hits"
        accepted = finite && orientationMatches && windowContainsPalette
            && paletteContainsInput && paletteContainsResult && inputHittable && resultHittable
            && paletteCurrent && inputCurrent && resultCurrent && liveWindowFrame == windowFrame
        return accepted
    }
}

/// Find only this test's unique sidecar after XCTest's app installation. The
/// pre-install container UUID is a hint to its parent, never a durable app ID.
private func matchingTestSidecars(in containers: URL, namespace: String) -> [URL] {
    guard UUID(uuidString: namespace) != nil,
          let candidates = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) else { return [] }
    return candidates.map {
        $0.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/\(namespace).json")
    }.filter { FileManager.default.fileExists(atPath: $0.path) }
}


/// Read-only evidence from this Simulator installation. The runner's pre-install
/// container UUID is only a parent hint: XCTest may reinstall the app.
private struct NativeGlobalHistoryObservation {
    let container: URL?
    let metadataBytes: Data?
    let persistedExactlyOnce: Bool
    let details: [String: Any]
}

/// Passive evidence only. Acceptance still requires the same bounded regular
/// preference file, parsed dictionary, installation pin and exact query count.
private struct NativeGlobalHistoryFileObservation {
    let data: Data?
    let details: [String: Any]
}

private func observeNativeGlobalHistoryFile(_ url: URL, maximum: Int) -> NativeGlobalHistoryFileObservation {
    var details: [String: Any] = ["maximumBytes": maximum, "bytesRead": 0]
    func failed(_ stage: String, _ reason: String, _ error: Error? = nil) -> NativeGlobalHistoryFileObservation {
        var result = details
        result["status"] = "unavailable"; result["stage"] = stage; result["reason"] = reason
        if let error {
            let value = error as NSError
            result["errorDomain"] = value.domain; result["errorCode"] = value.code
        }
        return .init(data: nil, details: result)
    }
    let values: URLResourceValues
    do {
        values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    } catch {
        let value = error as NSError
        let missing = (value.domain == NSCocoaErrorDomain &&
            [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(value.code))
            || (value.domain == NSPOSIXErrorDomain && value.code == 2)
        return failed("metadata", missing ? "missing" : "metadata_read_failed", error)
    }
    details["regularFile"] = values.isRegularFile
    details["symbolicLink"] = values.isSymbolicLink
    guard values.isSymbolicLink != true else { return failed("type", "symlink") }
    guard values.isRegularFile == true else {
        return failed("type", values.isRegularFile == false ? "nonregular" : "regular_status_unavailable")
    }
    guard values.isSymbolicLink == false else { return failed("type", "symlink_status_unavailable") }
    let handle: FileHandle
    do { handle = try FileHandle(forReadingFrom: url) }
    catch { return failed("open", "open_failed", error) }
    defer { try? handle.close() }
    do {
        var bytes = Data()
        while bytes.count <= maximum {
            guard let chunk = try handle.read(upToCount: min(65536, maximum + 1 - bytes.count)),
                  !chunk.isEmpty else {
                details["status"] = "read"; details["bytesRead"] = bytes.count
                return .init(data: bytes, details: details)
            }
            bytes.append(chunk)
            details["bytesRead"] = bytes.count
        }
    } catch { return failed("read", "read_failed", error) }
    return failed("budget", "oversize")
}

/// Existing DEBUG provider/publication observations, never an admission or
/// history-writer oracle. Missing events cannot establish that Return was lost.
private func observeNativeGlobalSearchTrace(in container: URL, namespace: String) -> [String: Any] {
    guard UUID(uuidString: namespace) != nil else { return ["status": "invalid_namespace"] }
    let file = container.appendingPathComponent("Documents/OtzariaLogs/search-native-" + namespace + ".jsonl")
    let read = observeNativeGlobalHistoryFile(file, maximum: 8 * 1024 * 1024)
    var result: [String: Any] = [
        "fileRead": read.details,
        "admissionObservation": "NOT_EXPOSED_BY_EXISTING_PASSIVE_CHANNEL",
        "historyWriterOwnerObservation": "NOT_EXPOSED_BY_EXISTING_PASSIVE_CHANNEL",
        "inMemoryHistoryObservation": "NOT_EXPOSED_BY_EXISTING_PASSIVE_CHANNEL"
    ]
    guard let data = read.data else { return result }
    var records: [[String: Any]] = []
    var rejected = 0
    for line in data.split(separator: 10) where !line.isEmpty {
        guard let value = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
              value["schemaVersion"] as? Int == 1,
              value["namespace"] as? String == namespace,
              value["profileID"] as? String == "miniTest10",
              let sessionID = value["sessionID"] as? String, UUID(uuidString: sessionID) != nil,
              let event = value["event"] as? String, ["provider", "published"].contains(event),
              let engine = value["engine"] as? String, ["otzaria", "zayit"].contains(engine) else {
            rejected += 1
            continue
        }
        var observed: [String: Any] = [
            "schemaVersion": 1, "namespace": namespace, "sessionID": sessionID,
            "event": event, "engine": engine, "profileID": "miniTest10"
        ]
        for key in ["submissionRevision", "searchGeneration", "backendGeneration"] {
            if let number = value[key] as? UInt64 { observed[key] = number }
        }
        if let hasMore = value["hasMore"] as? Bool { observed["hasMore"] = hasMore }
        if let request = value["request"] as? [String: Any],
           let digest = request["querySHA256"] as? String, digest.utf8.count == 64,
           digest.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) {
            observed["querySHA256"] = digest
        }
        records.append(observed)
    }
    result["acceptedRecordCount"] = records.count
    result["rejectedRecordCount"] = rejected
    result["lastRecords"] = Array(records.suffix(32))
    result["truncatedToLastRecords"] = records.count > 32
    return result
}

private func observeNativeGlobalHistory(
    in parent: URL, namespace: String, query: String,
    expectedContainer: URL? = nil, expectedMetadata: Data? = nil
) -> NativeGlobalHistoryObservation {
    let bundleID = "com.davidpovarsky.chavrusatext"
    func boundedRegularFile(_ url: URL, maximum: Int) -> Data? {
        observeNativeGlobalHistoryFile(url, maximum: maximum).data
    }
    func dictionary(_ bytes: Data) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: bytes, format: nil)) as? [String: Any]
    }
    let root = parent.standardizedFileURL
    let children = (try? FileManager.default.contentsOfDirectory(
        at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles])) ?? []
    let candidates: [(URL, Data)] = children.compactMap { child in
        let container = child.standardizedFileURL
        guard UUID(uuidString: container.lastPathComponent) != nil,
              container.deletingLastPathComponent().pathComponents == root.pathComponents,
              let values = try? container.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink == false,
              let metadata = boundedRegularFile(
                container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"),
                maximum: 65536),
              dictionary(metadata)?["MCMMetadataIdentifier"] as? String == bundleID else { return nil }
        return (container, metadata)
    }
    var details: [String: Any] = [
        "metadataBundleIdentifier": bundleID,
        "matchingInstallationCount": candidates.count,
        "candidateContainerIDs": candidates.map { $0.0.lastPathComponent },
        "queryPersistedExactlyOnce": false
    ]
    guard candidates.count == 1, let (container, metadata) = candidates.first else {
        details["observationError"] = "missing_or_ambiguous_original_installation"
        return .init(container: nil, metadataBytes: nil, persistedExactlyOnce: false, details: details)
    }
    // Feature-off deliberately has no workspace sidecar. If the existing UUID
    // sidecar is present, it must corroborate this same original installation.
    let sidecars = matchingTestSidecars(in: root, namespace: namespace)
    let namespaceMatches = sidecars.isEmpty || (sidecars.count == 1 &&
        sidecars[0].standardizedFileURL.pathComponents.starts(with: container.pathComponents))
    let pinned = expectedContainer != nil && expectedMetadata != nil
    let installationMatches = pinned &&
        expectedContainer?.standardizedFileURL.pathComponents == container.pathComponents && expectedMetadata == metadata
    details["containerID"] = container.lastPathComponent
    details["metadataByteCount"] = metadata.count
    details["namespaceSidecarCount"] = sidecars.count
    details["namespaceMatchesInstallation"] = namespaceMatches
    details["installationPinned"] = pinned
    details["installationMatchesInitialBytes"] = installationMatches
    let preference = container.appendingPathComponent("Library/Preferences/" + bundleID + ".plist")
    // The same preferences file also contains the real qualified-locator
    // registry. Native116 exceeded the former 1 MiB reader limit before the
    // history dictionary could be observed. Keep a finite 8 MiB read budget;
    // installation, namespace, parsing and exact history-count gates below
    // remain unchanged. This reads the original writer; it never flushes it.
    let preferenceRead = observeNativeGlobalHistoryFile(preference, maximum: 8 * 1024 * 1024)
    details["preferenceFileRead"] = preferenceRead.details
    var preferences: [String: Any]?
    if let bytes = preferenceRead.data {
        do {
            let decoded = try PropertyListSerialization.propertyList(from: bytes, format: nil)
            preferences = decoded as? [String: Any]
            details["preferenceParse"] = preferences == nil ? "dictionary_root_required" : "dictionary"
        } catch {
            let value = error as NSError
            details["preferenceParse"] = "parse_failed"
            details["preferenceParseErrorDomain"] = value.domain
            details["preferenceParseErrorCode"] = value.code
        }
    } else {
        details["preferenceParse"] = "NOT_ATTEMPTED_READ_UNAVAILABLE"
    }
    let history = preferences?["SearchHistory"] as? [String] ?? []
    let count = history.filter { $0 == query }.count
    details["preferenceReadable"] = preferences != nil
    details["historyCount"] = history.count
    details["submittedQueryCount"] = count
    if let preferences {
        details["recordSearchHistory"] = preferences["recordSearchHistory"] as? Bool ?? true
    }
    let persisted = installationMatches && namespaceMatches && preferences != nil && count == 1
    details["queryPersistedExactlyOnce"] = persisted
    if !namespaceMatches { details["observationError"] = "namespace_installation_mismatch" }
    else if pinned && !installationMatches { details["observationError"] = "original_installation_changed" }
    else if preferences == nil { details["observationError"] = "original_preferences_unreadable" }
    return .init(container: namespaceMatches ? container : nil,
                 metadataBytes: namespaceMatches ? metadata : nil,
                 persistedExactlyOnce: persisted, details: details)
}

/// Runs the supplied prototype in its own app, never demo code in Maktabah.
final class SafariPrototypeReferenceTests: XCTestCase {
    func testOriginalCompactAndExpandedToolbarOracle() {
        continueAfterFailure = false
        let prototype = XCUIApplication(bundleIdentifier: "com.example.safaritoolbarsearch")
        prototype.launchArguments = ["-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        prototype.launch()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let field = prototype.textFields["חיפוש או הזנת כתובת"]
            XCTAssertTrue(field.waitForExistence(timeout: 30))
            let compact = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            compact.name = "prototype-compact-\(orientation.isLandscape ? "landscape" : "portrait")"
            compact.lifetime = .keepAlways
            add(compact)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        prototype.textFields["חיפוש או הזנת כתובת"].tap()
        let result = prototype.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15), "The original CommandPalette must actually expand")
        let expanded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        expanded.name = "prototype-expanded-command-palette"
        expanded.lifetime = .keepAlways
        add(expanded)
        prototype.terminate()
    }
}

/// Black-box tests use the actual production-default flags and original views.
/// A unique sidecar namespace isolates tests without changing canonical sessions/data.
class FaithfulReaderUIBase: MaktabahUITestBase {
    @MainActor
    func sendNativeHID(_ usage: UIKeyboardHIDUsage) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_HID_TOKEN"],
                                 "Job-local pinned HID server is mandatory for hardware keyboard acceptance")
        let sidecar = try workspaceSidecarURL()
        let container = sidecar.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let nonce = UUID().uuidString
        let prefix = container.appendingPathComponent("Documents/r27-hid-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json")
        let ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        let payload: [String: Any] = ["token": token, "nonce": nonce, "key": usage.rawValue]
        // Keep private IPC paths out of XCTest's automatic NSError reporting.
        do {
            try JSONSerialization.data(withJSONObject: payload).write(to: request, options: .atomic)
        } catch {
            XCTFail("Could not write owned HID request")
            return
        }
        let acknowledged = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: ack.path) }, object: nil
        )], timeout: 20)
        XCTAssertEqual(acknowledged, .completed, "Real HID transport must acknowledge this exact request")
        guard acknowledged == .completed,
              let data = try? Data(contentsOf: ack),
              let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let publicData = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]),
              String(decoding: publicData, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil else {
            XCTFail("HID acknowledgement must be valid and credential-free")
            return
        }
        XCTAssertEqual(response["nonce"] as? String, nonce)
        XCTAssertEqual(response["key"] as? Int, usage.rawValue)
        XCTAssertEqual(response["delivered"] as? Bool, true, "Transport error: \(response)")
        let attachment = XCTAttachment(data: publicData, uniformTypeIdentifier: "public.json")
        attachment.name = "r27-hid-transport-only-\(usage.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    let workspaceNamespace = UUID().uuidString
    private var viewportURL: URL?
    var readerTestTier: TestTier { .smoke }
    private var recordsGlobalHistoryTrace = false
    var readerAdditionalLaunchArguments: [String] {
        recordsGlobalHistoryTrace ? ["-GlobalSearchNativeTraceEnabled", "YES"] : []
    }
    struct Viewport: Codable {
        struct Presentation: Codable {
            let wantsOverview: Bool; let isViewLoaded: Bool; let isInWindow: Bool
            let boundsWidth: Double; let boundsHeight: Double
            let parentClass: String; let presentedClass: String
            let hasHostingController: Bool; let isTransitioning: Bool
        }
        let source: Int; let offset: Double; let object: Int; let requestID: String
        let contentHeight: Double?; let viewportHeight: Double?; let contentOffsetY: Double?
        let topInset: Double?; let bottomInset: Double?
        let usesTextKit2BeforeObservation: Bool?; let usesTextKit2AfterObservation: Bool?
        let overviewPresentations: [Presentation]?
    }
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria", language: String = "he", background: Int = 0, recordViewport: Bool = false, fontSize: Float? = nil) {
        launchReader(enabled: enabled, scenario: scenario, backend: backend, language: language,
                     background: background, recordViewport: recordViewport, fontSize: fontSize,
                     tier: readerTestTier)
    }

    /// The required tier keeps every original override signature intact.
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria", language: String = "he", background: Int = 0, recordViewport: Bool = false, fontSize: Float? = nil, tier: TestTier) {
        // The downstream observer reads the actual original source anchor;
        // never activate the baseline renderer's crash-prone file exporter.
        let prefix = (recordViewport ? ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"] : nil).map {
            URL(fileURLWithPath: $0).appendingPathComponent("faithful-\(scenario)-" + UUID().uuidString).path
        }
        viewportURL = prefix.map { URL(fileURLWithPath: $0 + ".viewport.json") }
        // realUI intentionally omits a backend override in launchWithTier.
        // Preserve this helper's requested backend instead of inheriting a
        // previously persisted provider when the feature-off case relaunches.
        let backendArguments = tier == .realUI
            ? ["-preferredBackend", backend, "-smokeBackend", backend] : []
        launchWithTier(tier, scenario: scenario, backend: backend, extraArgs: backendArguments + [
            "-ChavrusaTextFaithfulReaderUIEnabled", enabled ? "YES" : "NO",
            "-studyWorkspaceTestingNamespace", workspaceNamespace,
            "-textViewBackgroundColorLight", String(background)
        ] + (fontSize.map { ["-textViewFontSize", String($0)] } ?? []) + readerAdditionalLaunchArguments, language: language, locale: language == "he" ? "he_IL" : "en_US",
        extraEnvironment: prefix.map { ["CHAVRUSA_READER_VIEWPORT_REPORT": $0] } ?? [:])
        dismissAlertsIfNeeded()
    }
    func viewport() throws -> Viewport {
        let oldURL = try XCTUnwrap(viewportURL, "The matrix must supply the viewport observation directory")
        let sidecar = try workspaceSidecarURL()
        let container = sidecar.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = container.appendingPathComponent("Documents").appendingPathComponent(oldURL.lastPathComponent)
        let request = UUID().uuidString
        let prefix = String(url.path.dropLast(".viewport.json".count))
        try request.write(toFile: prefix + ".request", atomically: true, encoding: .utf8)
        let exists = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: url),
                  let report = try? JSONDecoder().decode(Viewport.self, from: data) else { return false }
            return report.requestID == request && report.offset.isFinite
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [exists], timeout: 15), .completed)
        return try JSONDecoder().decode(Viewport.self, from: Data(contentsOf: url))
    }
    func attachViewport(_ value: Viewport, named name: String) throws {
        let attachment = XCTAttachment(data: try JSONEncoder().encode(value), uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func workspaceContainerParent() throws -> URL {
        let documents = try XCTUnwrap(ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"])
        return URL(fileURLWithPath: documents).deletingLastPathComponent().deletingLastPathComponent()
    }
    func workspaceSidecarURL() throws -> URL {
        let containers = try workspaceContainerParent()
        let namespace = workspaceNamespace
        // Receipt/workspace predicates read this helper while their own waiter
        // runs. An already-created exact UUID sidecar needs no nested XCTWaiter.
        let existing = matchingTestSidecars(in: containers, namespace: namespace)
        if existing.count == 1 { return existing[0] }
        XCTAssertLessThanOrEqual(existing.count, 1, "Duplicate UUID sidecars remain an error")
        let created = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            matchingTestSidecars(in: containers, namespace: namespace).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 15), .completed,
                       "Exactly one real sidecar for this UUID must exist in the installed app's current container")
        let matches = matchingTestSidecars(in: containers, namespace: namespace)
        XCTAssertEqual(matches.count, 1)
        return try XCTUnwrap(matches.first)
    }
    func attachWorkspaceSnapshot(_ name: String) throws {
        let snapshot = XCTAttachment(data: try Data(contentsOf: workspaceSidecarURL()), uniformTypeIdentifier: "public.json")
        snapshot.name = name
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        // An existing live snapshot already proves existence; retain the same
        // native wait for controls that have not appeared yet.
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 30), file: file, line: line)
        XCTAssertTrue(element.frame.intersects(app.windows.firstMatch.frame), "Control must be inside the actual native window", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    func readerLibraryPaletteLauncher() -> XCUIElement {
        let actions = app.buttons.matching(identifier: "reader-command-palette-launcher")
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(actions.count, 1, "Use the current original native library palette action uniquely")
        let action = actions.firstMatch
        XCTAssertTrue(action.isHittable, "The actual palette action must be reachable")
        XCTAssertTrue(!action.frame.isEmpty && app.windows.firstMatch.frame.contains(action.frame),
                      "The palette action must stay inside the actual application window")
        return action
    }

    /// The original native ReaderTabsView is intentionally mounted only with
    /// multiple documents. Establish that precondition through two real books,
    /// then return to the original document before measuring its viewport.
    func openSecondOriginalBookAndReturn() throws {
        let initialTitle = app.staticTexts["reader-header-title"].label
        let initialLocator = app.staticTexts["reader-current-locator"].label
        XCTAssertFalse(initialTitle.isEmpty)
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 20))
        let clear = palette.buttons["נקה את החיפוש"]
        if clear.exists { tap(clear) }
        let results = palette.scrollViews.buttons
        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 30))
        let candidate = try XCTUnwrap(results.allElementsBoundByIndex.first {
            !$0.label.isEmpty && $0.label != initialTitle
                && $0.isHittable && $0.frame.intersects(palette.frame)
        }, "Choose a second genuine book from the original visible command results")
        let secondTitle = candidate.label
        tap(candidate)
        assertReaderHasText()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", secondTitle),
            object: app.staticTexts["reader-header-title"]
        )], timeout: 30), .completed)
        let strip = app.descendants(matching: .any)["reader-document-tabs"]
        XCTAssertTrue(strip.waitForExistence(timeout: 30))
        let original = strip.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "reader-document-tab-", initialTitle))
        let added = strip.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "reader-document-tab-", secondTitle))
        XCTAssertEqual(original.count, 1)
        XCTAssertEqual(added.count, 1)
        XCTAssertNotEqual(original.firstMatch.identifier, added.firstMatch.identifier,
                          "The two real UI commands must create distinct document identities")
        if !original.firstMatch.isHittable { strip.swipeRight() }
        if !original.firstMatch.isHittable { strip.swipeLeft() }
        XCTAssertTrue(original.firstMatch.isHittable, "Return using the actual visible original tab button")
        tap(original.firstMatch)
        assertReaderHasText()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", initialTitle),
            object: app.staticTexts["reader-header-title"]
        )], timeout: 30), .completed)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, initialLocator,
                       "Return to the original navigation unit before the viewport assertions")
    }

    func readerBottomChromeAction() -> XCUIElement {
        let more = app.buttons.matching(identifier: "reader-more-menu").allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && $0.frame.intersects(app.windows.firstMatch.frame) && $0.isHittable
        }
        if let action = more.first {
            XCTAssertEqual(more.count, 1, "Observe one real visible reader More action")
            return action
        }
        // The genuine 9401 compact-window hierarchy exposes UIKit's native
        // bottom overflow instead of the reader's overflowed More item. Use
        // that actual control to measure chrome, never the full-height Toolbar.
        let overflow = app.buttons.matching(identifier: "BottomOverflowBarButtonItem")
        let visible = overflow.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && $0.frame.intersects(app.windows.firstMatch.frame) && $0.isHittable
        }
        XCTAssertEqual(visible.count, 1, "The original bottom toolbar must expose one real visible native overflow action")
        return visible.first ?? overflow.firstMatch
    }

    @MainActor
    func originalStudyToolsActionInWindow() throws -> XCUIElement {
        try originalTopBarActionInWindow(identifier: "reader-study-toggle",
            labels: ["Open Study Tools", "פתיחת כלי לימוד"])
    }

    @MainActor
    func originalTopBarActionInWindow(identifier: String, labels: [String]) throws -> XCUIElement {
        // SwiftUI can move the original action into UIKit's navigation menu
        // when the window narrows. Resolve the same action in either location.
        func visible(_ query: XCUIElementQuery) -> [XCUIElement] {
            let bounds = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
            return query.allElementsBoundByIndex.filter { element in
                let frame = element.frame
                return !frame.isEmpty && bounds.contains(frame) && element.isHittable
            }
        }
        func uniqueOriginalAction(_ candidates: [XCUIElement]) throws -> XCUIElement {
            XCTAssertEqual(candidates.count, 1,
                           "Require one visible original toolbar action in the current native window")
            let action = try XCTUnwrap(candidates.count == 1 ? candidates.first : nil)
            XCTAssertTrue(labels.contains(action.label),
                          "The original toolbar action must retain its exact label")
            return try XCTUnwrap(labels.contains(action.label) ? action : nil)
        }

        let directQuery = app.buttons.matching(identifier: identifier)
        // The real 375-point iOS 27 navigation bar can publish either UIKit
        // identifier for its top overflow. Keep the search inside that bar.
        let overflowQuery = app.navigationBars.buttons.matching(NSPredicate(
            format: "identifier IN %@", ["TopOverflowBarButtonItem", "OverflowBarButtonItem"]))
        let toolbarReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                !visible(directQuery).isEmpty || !visible(overflowQuery).isEmpty
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [toolbarReady], timeout: 15), .completed,
                       "The actual window must expose the original action or its native top overflow")
        let direct = visible(directQuery)
        if !direct.isEmpty {
            return try uniqueOriginalAction(direct)
        }

        let overflows = visible(overflowQuery)
        XCTAssertEqual(overflows.count, 1, "Do not choose between multiple visible native overflow controls")
        let overflow = try XCTUnwrap(overflows.count == 1 ? overflows.first : nil)
        overflow.tap()

        // UIKit may expose the menu item by the action's original visible title.
        let menuQuery = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label IN %@", identifier, labels))
        let menuReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !visible(menuQuery).isEmpty }
        }, object: nil)
        let outcome = XCTWaiter.wait(for: [menuReady], timeout: 15)
        let evidence = XCTAttachment(string:
            "actualWindow=\(app.windows.firstMatch.frame)\n\(app.debugDescription)")
        evidence.name = "original-\(identifier)-native-overflow-hierarchy"
        evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(outcome, .completed,
                       "Opening the actual native overflow must reveal the original action")
        return try uniqueOriginalAction(visible(menuQuery))
    }

    func readerSidebarToggle() -> XCUIElement {
        let custom = app.buttons["reader-host-sidebar-toggle"]
        let native = app.navigationBars.buttons.matching(NSPredicate(format:
            "label IN %@", ["הצגת סרגל הצד", "הסתרת סרגל הצד", "Show Sidebar", "Hide Sidebar"]))
        XCTAssertEqual((custom.exists ? 1 : 0) + native.count, 1,
                       "Use one actual split-view sidebar action; duplicate custom/native toggles are forbidden")
        return custom.exists ? custom : native.firstMatch
    }
    func exerciseOriginalBottomTOCAction() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let libraryPage = app.buttons["reader-sidebar-page-0"]
        if !libraryPage.exists || !libraryPage.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryPage)
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let readerWidth = app.textViews["reader-text"].frame.width
        tap(app.buttons["reader-more-menu"])
        tap(app.buttons["reader-toc-toggle"])
        let contentsPage = app.buttons["reader-sidebar-page-1"]
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: contentsPage)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed,
                       "The original TOC action must select Contents, rather than hiding an open Library page")
        XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
        XCTAssertTrue(app.frame.contains(contentsPage.frame), "Contents must actually remain on screen")
        XCTAssertEqual(app.textViews["reader-text"].frame.width, readerWidth, accuracy: 1)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        capture("candidate-original-bottom-toc-action")
    }
    func capture(_ name: String, windowed: Bool = false) {
        let application = app!
        let observation = NativeCaptureMainActorEntry.run {
            NativeCaptureSettlementObservation(application: application, windowed: windowed)
        }
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run { observation.settled() }
        }, object: nil)
        let settlement = XCTWaiter.wait(for: [settled], timeout: 20)
        if settlement != .completed {
            let text = NativeCaptureMainActorEntry.run {
                NativeGeometryEvidence.text(observation.evaluations)
            }
            let diagnostic = XCTAttachment(string: text)
            diagnostic.name = name + "-actual-settlement-evaluations"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        // Capture the display rather than XCTest's app-rectangle crop: the
        // iPadOS 27 landscape app crop can retain portrait dimensions and clip
        // the trailing toolbar. Preserve the complete system/window chrome.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        // Preserve the genuine image and hierarchy even if the strict native
        // settling assertion fails. An UNSETTLED capture is diagnostic evidence,
        // never an automatic visual-acceptance pass.
        attachment.name = settlement == .completed ? name : "UNSETTLED-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: "appFrame=\(app.frame)\nactualWindow=\(app.windows.firstMatch.frame)\norientation=\(XCUIDevice.shared.orientation.rawValue)\n\(app.debugDescription)")
        hierarchy.name = name + "-ui-tree"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertEqual(settlement, .completed,
                       "Capture only after native rotation and the original bottom toolbar settle inside the window")
    }
    /// A modal palette and the software keyboard own hit testing while open.
    /// Keep the original Reader toolbar settlement check for the restored Reader;
    /// here require the actual visible palette, input and result inside its window.
    func captureOpenLibraryPalette(_ name: String, palette: XCUIElement, result: XCUIElement) {
        retainNativeEvidence(name + "-before-settlement")
        let application = app!
        let observation = NativeCaptureMainActorEntry.run {
            NativeLibraryPaletteSettlementObservation(application: application, palette: palette, result: result)
        }
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run { observation.settled() }
        }, object: nil)
        let settlement = XCTWaiter.wait(for: [settled], timeout: 20)
        if settlement != .completed {
            let text = NativeCaptureMainActorEntry.run {
                NativeGeometryEvidence.text(observation.evaluations)
            }
            let diagnostic = XCTAttachment(string: text)
            diagnostic.name = name + "-actual-palette-settlement-evaluations"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        retainNativeEvidence(name + (settlement == .completed ? "-settled" : "-UNSETTLED"))
        XCTAssertEqual(settlement, .completed,
                       "The open original palette, search input and real result must settle inside the native window")
    }

    /// Diagnostic retention before an action/assertion; never a visual pass.
    func retainNativeEvidence(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "DIAGNOSTIC-" + name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: "appFrame=\(app.frame)\nactualWindow=\(app.windows.firstMatch.frame)\n\(app.debugDescription)")
        tree.name = "DIAGNOSTIC-" + name + "-ui-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func assertSourceActionsInsideNativeToolbarHost() {
        let hosts = app.navigationBars.containing(.button, identifier: "reader-tabs-overview")
        XCTAssertEqual(hosts.count, 1, "Identify the current original native navigation bar uniquely")
        let host = hosts.firstMatch
        XCTAssertTrue(host.exists)
        for identifier in ["reader-tabs-overview", "reader-command-palette-launcher"] {
            let actions = host.buttons.matching(identifier: identifier)
            XCTAssertEqual(actions.count, 1, "The source action must belong to this native toolbar")
            let action = actions.firstMatch
            XCTAssertTrue(action.exists && action.isHittable)
            XCTAssertFalse(action.frame.isEmpty)
            XCTAssertTrue(host.frame.insetBy(dx: -1, dy: -1).contains(action.frame),
                          "Source actions must stay inside the actual native toolbar's hit-test bounds")
            XCTAssertTrue(app.windows.firstMatch.frame.contains(action.frame))
        }
    }

    /// Actual application presentation/return, with the existing read-only
    /// TextKit observer proving identity and the current source/pixel anchor.
    @MainActor
    func exerciseOverviewReplacement(orientation: UIDeviceOrientation, phone: Bool) throws {
        XCUIDevice.shared.orientation = orientation
        let platform = phone ? "phone" : (orientation.isLandscape ? "landscape" : "portrait")
        // This supported preference renders genuine text beyond the viewport.
        // Its canonical navigation may restore the top or a later position;
        // establish the required nonzero position through the actual reader.
        launchReader(recordViewport: true, fontSize: 48)
        try establishSingleBookOverviewFixture(phone: phone)
        try exerciseOverviewAtCurrentPosition(platform: platform + "-nonzero", phone: phone, requiresNonzeroPosition: true)
        // Also retain full-display visual proof at the original 19pt default.
        launchReader(recordViewport: true, fontSize: 19)
        try establishSingleBookOverviewFixture(phone: phone)
        try exerciseOverviewAtCurrentPosition(platform: platform, phone: phone, requiresNonzeroPosition: false)
    }


    private struct OverviewFixtureWorkspace: Decodable, Sendable {
        struct Document: Decodable, Sendable {
            struct Session: Decodable, Sendable { let id: UUID; let bookId: Int }
            let backend: String; let session: Session
        }
        struct Group: Decodable, Sendable {
            let id: UUID; let profileID: UUID; let activeTabID: UUID?; let tabs: [Document]
        }
        struct Scene: Decodable, Sendable {
            let profileID: UUID; let groupID: UUID; let activeTabIDsByGroup: [UUID: UUID]?
        }
        let groups: [Group]; let scenes: [String: Scene]; let lastActiveSceneID: String?
        func current() -> (Group, UUID)? {
            guard let sceneID = lastActiveSceneID, let scene = scenes[sceneID],
                  let group = groups.first(where: { $0.id == scene.groupID && $0.profileID == scene.profileID }),
                  let activeID = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID,
                  group.tabs.contains(where: { $0.session.id == activeID }) else { return nil }
            return (group, activeID)
        }
    }

    /// A fresh sidecar still imports the ordinary reader's real saved tabs.
    /// Establish this test's one-book precondition through original UI before
    /// measuring any source/pixel anchor; never rewrite a session or viewport.
    @MainActor
    private func establishSingleBookOverviewFixture(phone: Bool) throws {
        XCTAssertNotEqual(readerTestTier, .production, "Fixture preparation is limited to the isolated miniTest10 cases")
        assertReaderHasText()
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let source = locator.components(separatedBy: "|")
        XCTAssertEqual(source.count, 3)
        XCTAssertEqual(source.first, "otzaria")
        let bookID = try XCTUnwrap(source.count == 3 && source[1].hasPrefix("book:")
            ? Int(source[1].dropFirst("book:".count)) : nil)
        tap(app.buttons[phone ? "reader-open-tabs-button" : "reader-tabs-overview"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        let toggle = app.buttons["study-tabs-layout-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if toggle.label == "תצוגת רשת" { tap(toggle) }
        let prefix = "tab-switcher-grid-cell-"
        let cells = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", prefix))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 15))
        let selected = cells.allElementsBoundByIndex.filter { $0.isSelected }
        XCTAssertEqual(selected.count, 1, "The original overview must identify one actual selected document")
        let selectedCell = try XCTUnwrap(selected.first)
        let keptID = try XCTUnwrap(UUID(uuidString: String(selectedCell.identifier.dropFirst(prefix.count))))
        let observedIDs = try cells.allElementsBoundByIndex.map {
            try XCTUnwrap(UUID(uuidString: String($0.identifier.dropFirst(prefix.count))))
        }
        let originalIDs = Set(observedIDs)
        XCTAssertEqual(originalIDs.count, observedIDs.count)
        XCTAssertLessThanOrEqual(originalIDs.count, 32, "Keep fixture cleanup bounded to the observed original group")
        let url = try workspaceSidecarURL()
        @Sendable func currentWorkspace() -> (OverviewFixtureWorkspace.Group, UUID)? {
            guard let bytes = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder().decode(OverviewFixtureWorkspace.self, from: bytes) else { return nil }
            return snapshot.current()
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let (group, active) = currentWorkspace() else { return false }
            return active == keptID && Set(group.tabs.map { $0.session.id }) == originalIDs
                && group.tabs.count == originalIDs.count
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "Corroborate the selected native UUID and every observed member with this exact test sidecar")
        let original = try XCTUnwrap(currentWorkspace())
        let retained = try XCTUnwrap(original.0.tabs.first { $0.session.id == keptID })
        XCTAssertEqual(retained.backend, "otzaria")
        XCTAssertEqual(retained.session.bookId, bookID)
        try attachWorkspaceSnapshot("overview-fixture-original-members")
        retainNativeEvidence("overview-fixture-before-native-close")
        var removed = Set<UUID>()
        for id in originalIDs.subtracting([keptID]).sorted(by: { $0.uuidString < $1.uuidString }) {
            let cell = cells[prefix + id.uuidString]
            XCTAssertTrue(cell.exists && cell.isHittable)
            XCTAssertFalse(cell.isSelected, "Never close the selected source document during preparation")
            cell.swipeRight()
            let vanished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cell)
            XCTAssertEqual(XCTWaiter.wait(for: [vanished], timeout: 15), .completed,
                           "The original RTL swipe must remove this exact observed noncurrent UUID")
            removed.insert(id)
            let expectedIDs = originalIDs.subtracting(removed)
            let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let (group, active) = currentWorkspace() else { return false }
                return group.id == original.0.id && active == keptID
                    && Set(group.tabs.map { $0.session.id }) == expectedIDs
                    && group.tabs.count == expectedIDs.count
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 15), .completed,
                           "Each original close must persist only that UUID removal and preserve the active document")
            XCTAssertTrue(cells[prefix + keptID.uuidString].exists)
            XCTAssertTrue(cells[prefix + keptID.uuidString].isSelected)
        }
        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(try XCTUnwrap(currentWorkspace()).1, keptID)
        try attachWorkspaceSnapshot("overview-fixture-single-original-book")
        tap(app.buttons["סיום"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: overview)], timeout: 15), .completed)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
    }

    private func exerciseOverviewAtCurrentPosition(platform: String, phone: Bool, requiresNonzeroPosition: Bool) throws {
        assertReaderHasText()
        let reader = app.textViews["reader-text"]
        let initial = try viewport()
        try attachViewport(initial, named: "replacement-viewport-opening-" + platform)
        capture("replacement-reader-initial-" + platform)
        var positioned = try viewport()
        if requiresNonzeroPosition {
            for attempt in 1...2 {
                let documentY = try XCTUnwrap(positioned.contentOffsetY) + XCTUnwrap(positioned.topInset)
                if positioned.source > 0 && documentY > 5 { break }
                // A short real pan targets the original text view. Its own
                // pull navigation may advance a section before positioning.
                // Never assign an offset or use the stale contentSize cache.
                let start = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                let end = start.withOffset(CGVector(dx: 0, dy: -min(220, reader.frame.height * 0.3)))
                start.press(forDuration: 0.05, thenDragTo: end)
                positioned = try viewport()
                try attachViewport(positioned, named: "replacement-viewport-user-pan-\(attempt)-" + platform)
                retainNativeEvidence("replacement-user-pan-\(attempt)-" + platform)
            }
        }
        capture("replacement-reader-before-" + platform)
        // Observe again after the full-frame settling check, not a stale report
        // from before native layout. The source/pixel anchor is authoritative.
        let before = try viewport()
        try attachViewport(before, named: "replacement-viewport-before-" + platform)
        if requiresNonzeroPosition {
            XCTAssertGreaterThan(before.source, 0, "Preserve a real visible source position beyond the opening character")
            let documentY = try XCTUnwrap(before.contentOffsetY) + XCTUnwrap(before.topInset)
            XCTAssertGreaterThan(documentY, 5, "The original reader must actually be positioned beyond the top")
        }
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let readerFrame = reader.frame
        let actionID = phone ? "reader-open-tabs-button" : "reader-tabs-overview"
        for selectsCurrent in (requiresNonzeroPosition ? [false, true] : [false]) {
            tap(app.buttons[actionID])
            let overview = app.descendants(matching: .any)["study-groups-overview"]
            let opened = overview.waitForExistence(timeout: 20)
            retainNativeEvidence("replacement-context-before-assertions-" + platform)
            if !opened, let report = try? viewport() {
                try attachViewport(report, named: "replacement-presentation-failure-" + platform)
            }
            XCTAssertTrue(opened, "The real source action must display the actual overview")
            XCTAssertEqual(overview.frame.width, app.frame.width, accuracy: 2,
                           "The source overview must occupy the reader context's whole width")
            XCTAssertGreaterThanOrEqual(overview.frame.height, app.frame.height * 0.9,
                                        "A centered partial-height sheet is not screen replacement")
            XCTAssertFalse(reader.exists && reader.isHittable,
                           "The covered original reader must not receive overview touches")
            let toggle = app.buttons["study-tabs-layout-toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 10))
            if toggle.label == "תצוגת רשת" { tap(toggle) }
            let cells = overview.collectionViews.cells.matching(NSPredicate(
                format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-"))
            XCTAssertEqual(cells.count, 1, "This fixture has one genuine active book")
            capture("replacement-overview-grid-" + platform)
            tap(toggle)
            XCTAssertTrue(overview.collectionViews.cells.matching(NSPredicate(
                format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")).firstMatch.waitForExistence(timeout: 10))
            capture("replacement-overview-list-" + platform)
            if selectsCurrent {
                tap(overview.collectionViews.cells.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")).firstMatch)
            } else {
                tap(app.buttons["סיום"])
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: overview)], timeout: 15), .completed)
            assertReaderHasText()
            let after = try viewport()
            try attachViewport(after, named: "replacement-viewport-return-\(selectsCurrent ? "selected" : "done")-" + platform)
            XCTAssertEqual(after.object, before.object, "Return must reuse the original TextKit instance")
            XCTAssertEqual(after.source, before.source, "Return must preserve the first visible source character")
            XCTAssertEqual(after.offset, before.offset, accuracy: 1, "Return must preserve the source pixel anchor")
            XCTAssertEqual(try XCTUnwrap(after.contentOffsetY), try XCTUnwrap(before.contentOffsetY), accuracy: 1,
                           "Return must also preserve the original raw native content offset")
            XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
            XCTAssertEqual(reader.frame.width, readerFrame.width, accuracy: 1)
            XCTAssertEqual(reader.frame.height, readerFrame.height, accuracy: 1)
            capture("replacement-reader-return-\(selectsCurrent ? "selected" : "done")-" + platform)
        }
    }

    func assertReaderHasText(expectedSourceText: String? = nil) {
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60), "The original TextKit reader must render")
        let application = app!
        let laidOut = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = text.frame
                return frame.width > 80 && frame.height > 80 && frame.minX.isFinite && frame.minY.isFinite
                    && frame.width <= application.frame.width + 1 && frame.height <= application.frame.height + 1
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [laidOut], timeout: 30), .completed,
                       "The actual reader must finish native window reflow before inspecting its pixels")
        let predicate: NSPredicate
        if let expectedSourceText {
            XCTAssertFalse(expectedSourceText.isEmpty, "Independent source text must not be empty")
            let directionControls: Set<UInt32> = [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069]
            // Capture the existing MainActor-owned element instead of transferring
            // NSPredicate's unisolated Any? argument across the actor boundary.
            predicate = NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    guard let actual = text.value as? String else { return false }
                    return actual.unicodeScalars.filter { !directionControls.contains($0.value) }.map(String.init)
                        .joined().trimmingCharacters(in: .whitespacesAndNewlines) == expectedSourceText
                }
            }
        } else {
            predicate = NSPredicate(format: "value MATCHES %@", "(?s).{31,}")
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: text)], timeout: 30), .completed,
                       "Require actual source text; structured diagnostics alone are not text evidence")
        let title = app.staticTexts["reader-header-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertFalse(["", "ספר", "Book 1"].contains(title.label), "A fabricated placeholder is not a genuine loaded book")
        let rendered = text.value as? String ?? ""
        XCTAssertFalse(rendered.contains("Error Domain") || rendered.contains("Content ID not found") || rendered.contains("no such table"), "An error message must not count as book text")
        if TestRenderedHighlightSnapshot.fromJSON(rendered) != nil {
            // Immutable 9401 replaces the native value with diagnostic JSON.
            // Detect actual printed glyphs inside the reader body, excluding
            // headers/toolbars. This does not OCR Hebrew or infer book identity;
            // the canonical title and native screenshots remain separate proof.
            do {
                // The public element screenshot resolves its native window
                // context. App/element coordinates and a full display screenshot
                // diverge once iPadOS places a resized window over the desktop.
                let image = text.screenshot().image
                guard let rawImage = image.cgImage else { XCTFail("The native text screenshot has no pixels"); return }
                let rotated = [.left, .right, .leftMirrored, .rightMirrored].contains(image.imageOrientation)
                let displaySize = CGSize(width: CGFloat(rotated ? rawImage.height : rawImage.width) / image.scale,
                                         height: CGFloat(rotated ? rawImage.width : rawImage.height) / image.scale)
                let format = UIGraphicsImageRendererFormat()
                format.scale = image.scale
                let normalized = UIGraphicsImageRenderer(size: displaySize, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: displaySize))
                }
                let readerFrame = text.frame
                let navigationFrames = app.navigationBars.allElementsBoundByIndex.map { $0.frame }.filter {
                    $0.width > 0 && $0.height > 0 && $0.intersects(readerFrame)
                        && $0.intersection(readerFrame).width > readerFrame.width * 0.5
                }
                let bottomAction = readerBottomChromeAction()
                guard let navigationBottom = navigationFrames.map({ $0.maxY }).max(), bottomAction.exists else {
                    XCTFail("Cannot identify the original native chrome to isolate genuine book pixels"); return
                }
                // UITextView extends behind native bars. Exclude their actual
                // measured frames so title/status/tab labels cannot count as
                // loaded book text when the original value is diagnostic JSON.
                let top = max(readerFrame.minY, navigationBottom) + 12
                // On iPadOS 27 the accessibility Toolbar container spans the
                // whole content area. Its real bottom action has precise bounds.
                let bottom = min(readerFrame.maxY, bottomAction.frame.minY) - 12
                let frame = CGRect(x: 12, y: top - readerFrame.minY,
                                   width: readerFrame.width - 24, height: bottom - top)
                guard frame.width > 0, frame.height > 0 else {
                    XCTFail("The original reader has no visible book body between its native bars"); return
                }
                let pixelsPerPointX = displaySize.width * normalized.scale / readerFrame.width
                let pixelsPerPointY = displaySize.height * normalized.scale / readerFrame.height
                let pixels = CGRect(x: frame.minX * pixelsPerPointX, y: frame.minY * pixelsPerPointY,
                                    width: frame.width * pixelsPerPointX, height: frame.height * pixelsPerPointY)
                let geometry = XCTAttachment(string: "app=\(app.frame)\nreader=\(readerFrame)\nimageSize=\(image.size)\nimageOrientation=\(image.imageOrientation.rawValue)\ndisplaySize=\(displaySize)\nbookPixels=\(pixels)")
                geometry.name = "native-reader-pixel-observation-geometry"
                geometry.lifetime = .keepAlways
                add(geometry)
                guard let crop = normalized.cgImage?.cropping(to: pixels) else {
                    XCTFail("Cannot inspect the actual reader pixels"); return
                }
                let request = VNDetectTextRectanglesRequest()
                request.reportCharacterBoxes = true
                try VNImageRequestHandler(cgImage: crop).perform([request])
                let lines = request.results ?? []
                let body = XCTAttachment(image: UIImage(cgImage: crop))
                body.name = "immutable-baseline-actual-book-body"
                body.lifetime = .keepAlways
                add(body)
                XCTAssertGreaterThanOrEqual(lines.count, 2, "The immutable baseline must display multiple real text lines")
                XCTAssertGreaterThanOrEqual(lines.reduce(0) { $0 + ($1.characterBoxes?.count ?? 0) }, 30,
                                            "A JSON accessibility value or empty/loading reader is not rendered book-text evidence")
            } catch { XCTFail("Could not inspect actual reader text pixels: \(error)") }
        } else {
            XCTAssertFalse(rendered.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
                           "Native reader value must be book text, not diagnostic JSON")
        }
    }

    @MainActor
    func exerciseNativeWindowResize(enabled: Bool) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: enabled, scenario: "readerDetail")
        assertReaderHasText()
        let application = app!
        let window = application.windows.firstMatch
        let originalLocator = app.staticTexts["reader-current-locator"].label
        capture(enabled ? "candidate-window-wide" : "baseline-window-wide")
        // Measure after the same strict native rotation/toolbar settling used
        // by the actual screenshot, rather than keeping an earlier frame.
        let originalFrame = window.frame
        let restoration = NativeUIRestoration {
            let current = window.frame
            if abs(current.width - originalFrame.width) > 2 || abs(current.height - originalFrame.height) > 2 {
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                // The retained Release failure exposes this exact public
                // SpringBoard control in screen coordinates. An application
                // frame can retain a zero origin after its native window moves.
                let controls = springboard.buttons["window-controls:com.davidpovarsky.chavrusatext"]
                let openedControls = controls.waitForExistence(timeout: 10) && controls.isHittable
                if openedControls { controls.tap() }
                let labels = ["Full Screen", "Enter Full Screen", "Zoom", "מסך מלא", "הצג במסך מלא"]
                let predicate = NSPredicate(format: "label IN %@", labels)
                let candidates = [application.buttons, application.menuItems, springboard.buttons, springboard.menuItems]
                var selected = false
                for query in candidates where openedControls {
                    let action = query.matching(predicate).firstMatch
                    if action.waitForExistence(timeout: 3), action.isHittable {
                        action.tap()
                        selected = true
                        break
                    }
                }
                if !selected {
                    XCTContext.runActivity(named: "Native window controls unavailable") { activity in
                        let tree = XCTAttachment(string: application.debugDescription + "\nSPRINGBOARD\n" + springboard.debugDescription)
                        tree.lifetime = .keepAlways
                        activity.add(tree)
                        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                        screen.lifetime = .keepAlways
                        activity.add(screen)
                    }
                    XCTFail("Cannot restore the actual window through its native Full Screen action")
                    return
                }
                let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    MainActor.assumeIsolated {
                        abs(window.frame.width - originalFrame.width) < 2 && abs(window.frame.height - originalFrame.height) < 2
                    }
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 30), .completed,
                               "Restore the actual window before other baseline/candidate cases")
            }
        }
        addTeardownBlock { await restoration.run() }
        // Apple's iPad windowing gesture: drag the system bottom-right handle.
        // This must change the actual window, not an injected size class/frame.
        let handle = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -12, dy: -12))
        let destination = window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
        handle.press(forDuration: 0.5, thenDragTo: destination)
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { window.frame.width < originalFrame.width - 80 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 30), .completed,
                       "The native iPad window must actually resize; a simulated width is not acceptance")
        if enabled {
            // Exercise the source toolbar before the separate original bottom-
            // toolbar settling gate. Its existing strict assertion stays below.
            retainNativeEvidence("candidate-narrow-toolbar-before-action")
            assertSourceActionsInsideNativeToolbarHost()
            tap(app.buttons["reader-tabs-overview"])
            let overview = app.descendants(matching: .any)["study-groups-overview"]
            retainNativeEvidence("candidate-narrow-overview-after-action")
            XCTAssertTrue(overview.waitForExistence(timeout: 15))
            capture("candidate-narrow-source-overview", windowed: true)
            tap(app.buttons["סיום"])
        }
        capture(enabled ? "candidate-window-narrow" : "baseline-window-narrow", windowed: true)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator,
                       "Window reflow must preserve the actual navigation unit")
        XCTAssertTrue(readerBottomChromeAction().exists, "The original bottom toolbar must survive narrow window reflow")
        let geometry = XCTAttachment(string: "wide=\(originalFrame)\nnarrow=\(window.frame)\napplicationSnapshot=\(app.frame)")
        geometry.name = enabled ? "candidate-native-window-geometry" : "baseline-native-window-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        if enabled {
            let field = readerLibraryPaletteLauncher()
            XCTAssertTrue(field.waitForExistence(timeout: 15))
            XCTAssertTrue(field.isHittable, "The actual library palette action must remain reachable in the native narrow window")
            field.tap()
            let palette = app.descendants(matching: .any)["reader-library-command-palette"]
            XCTAssertTrue(palette.waitForExistence(timeout: 15))
            capture("candidate-window-narrow-palette", windowed: true)
            palette.textFields.firstMatch.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
            XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed)
            let beforeInspector = getRenderedHighlightSnapshot()
            XCTAssertNotNil(beforeInspector)
            let study = try originalStudyToolsActionInWindow()
            XCTAssertTrue(study.waitForExistence(timeout: 15), "Original study tools must remain available in a real compact window")
            study.tap()
            let inspector = app.descendants(matching: .any)["torah-inspector-panel"]
            XCTAssertTrue(inspector.waitForExistence(timeout: 30))
            XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].exists)
            capture("candidate-window-narrow-original-floating-inspector", windowed: true)
            let close = app.buttons["torah-inspector-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 15))
            XCTAssertTrue(close.isHittable)
            XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(close.frame),
                          "Close the actual original Inspector inside its current native window")
            close.tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: inspector)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 15), .completed)
            assertReaderHasText()
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
            let afterInspector = getRenderedHighlightSnapshot()
            XCTAssertNotNil(afterInspector)
            XCTAssertEqual(afterInspector?.segmentSelectionCount, beforeInspector?.segmentSelectionCount,
                           "Opening the original Inspector in a compact window must not manufacture a book selection")
        }
    }

    func selectStudyGroup(named name: String) {
        let selector = app.segmentedControls["study-group-selector"]
        if selector.exists {
            tap(selector.buttons[name])
        } else {
            // The source's public AdaptiveTabContent can choose its native
            // Menu in a compact sheet/window or accessibility text size.
            tap(app.buttons["study-group-selector"])
            // The native popover is a collection of cells. The underlying
            // overview toolbar also has a button named 'All Tabs'.
            let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label == %@", name))
            XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 15))
            XCTAssertEqual(options.count, 1, "Select the unique real group action in the native popover")
            tap(options.element(boundBy: 0))
        }
    }

    @discardableResult
    func exerciseGlobalHistorySubmission(enabled: Bool) -> String {
        let previousTrace = recordsGlobalHistoryTrace
        recordsGlobalHistoryTrace = true
        defer { recordsGlobalHistoryTrace = previousTrace }
        let query = "בדיקת היסטוריה " + UUID().uuidString
        launchReader(enabled: enabled, scenario: "search")
        let fields = app.descendants(matching: .any).matching(identifier: "global-search-query")
        let globalInput = fields.firstMatch
        XCTAssertTrue(globalInput.waitForExistence(timeout: 40))
        XCTAssertEqual(fields.count, 1, "Require the single original global query field")
        XCTAssertTrue(globalInput.elementType == .searchField || globalInput.elementType == .textField)
        XCTAssertTrue(app.collectionViews["global-search-history"].waitForExistence(timeout: 20))
        func attachHistoryObservation(_ observation: NativeGlobalHistoryObservation, stage: String,
                                      nativeHistoryRowVisible: Bool? = nil, waiterResult: XCTWaiter.Result? = nil) {
            var details = observation.details
            details["stage"] = stage
            details["nativeHistoryRowVisible"] = nativeHistoryRowVisible
            details["waiterResult"] = waiterResult.map { String(describing: $0) }
            // Read only at the existing attachment points, never in settlement
            // predicates; the original DEBUG writer supplies any actual state.
            if let container = observation.container {
                details["originalPassiveSearchTrace"] = observeNativeGlobalSearchTrace(
                    in: container, namespace: workspaceNamespace)
            }
            let fields = app.descendants(matching: .any).matching(identifier: "global-search-query")
            let fieldCount = fields.count
            details["originalQueryFieldCount"] = fieldCount
            if fieldCount == 1 {
                let field = fields.element
                details["originalQueryFieldValue"] = field.value as? String
                details["originalQueryFieldMatchesExpected"] = field.value as? String == query
                details["originalQueryFieldEnabled"] = field.isEnabled
                details["originalQueryFieldHittable"] = field.isHittable
            }
            details["originalUIStates"] = [
                "history": app.collectionViews["global-search-history"].exists,
                "loading": app.otherElements["global-search-loading"].exists,
                "cancel": app.buttons["global-search-cancel"].exists,
                "error": app.otherElements["global-search-error"].exists,
                "missingIndex": app.otherElements["global-search-missing-index"].exists,
                "dirty": app.otherElements["global-search-dirty"].exists,
                "cancelled": app.otherElements["global-search-cancelled"].exists,
                "empty": app.otherElements["global-search-empty"].exists
            ]
            let data = (try? JSONSerialization.data(withJSONObject: details, options: [.prettyPrinted, .sortedKeys])) ?? Data()
            let diagnostic = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            diagnostic.name = "global-history-native-persistence-" + stage
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "global-history-original-state-" + stage
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        guard let containers = try? workspaceContainerParent() else {
            XCTFail("The matrix must provide the original Simulator container parent")
            return query
        }
        let historyNamespace = workspaceNamespace
        let initial = observeNativeGlobalHistory(in: containers, namespace: historyNamespace, query: query)
        attachHistoryObservation(initial, stage: "before-submit")
        guard let originalContainer = initial.container, let originalMetadata = initial.metadataBytes else {
            XCTFail("Require one source-identified original app installation before submitting")
            return query
        }
        let historyObservation: @Sendable () -> NativeGlobalHistoryObservation = {
            observeNativeGlobalHistory(in: containers, namespace: historyNamespace, query: query,
                                       expectedContainer: originalContainer, expectedMetadata: originalMetadata)
        }
        tap(globalInput)
        // NativeGlobalSearchField.textFieldShouldReturn submits through the
        // original session; there is no Start Search button in this header.
        globalInput.typeText(query + "\n")
        XCTAssertEqual(globalInput.value as? String, query)
        let application = app!
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                !application.collectionViews["global-search-history"].exists
                    && !application.otherElements["global-search-loading"].exists
                    && !application.buttons["global-search-cancel"].exists
                    && historyObservation().persistedExactlyOnce
            }
        }, object: nil)
        let settledResult = XCTWaiter.wait(for: [settled], timeout: 90)
        let beforeTermination = historyObservation()
        // UserDefaults writes are observed, never forced. Do not terminate merely
        // because a loading/history view disappeared, or replace a native writer.
        attachHistoryObservation(beforeTermination, stage: "before-terminate", waiterResult: settledResult)
        XCTAssertEqual(settledResult, .completed,
                       "The original Return submission must settle and persist in its own installation before relaunch")
        XCTAssertTrue(beforeTermination.persistedExactlyOnce,
                      "The exact submitted query must be written once by the original app before termination")
        // The current original screen shows inline history before a submission,
        // not on refocus of existing results. Relaunch its actual session and
        // require the same query persisted by the original submit action.
        app.terminate()
        launchReader(enabled: enabled, scenario: "search")
        let reopenedFields = app.descendants(matching: .any).matching(identifier: "global-search-query")
        XCTAssertTrue(reopenedFields.firstMatch.waitForExistence(timeout: 40))
        XCTAssertEqual(reopenedFields.count, 1)
        tap(reopenedFields.firstMatch)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10),
                      "Observe the actual native keyboard before checking usable history")
        // Capture the actual focused global screen even when the following
        // assertion fails, so immutable baseline behavior can be compared.
        capture(enabled ? "candidate-global-search-history" : "baseline-global-search-history")
        let historyRows = app.collectionViews["global-search-history"].buttons
            .matching(identifier: "global-search-history-" + query)
        let historyRow = historyRows.firstMatch
        let historyIsVisible = historyRow.waitForExistence(timeout: 20)
        let afterRelaunch = historyObservation()
        // Attach before assertions: continueAfterFailure=false previously aborted
        // this case before its persistence diagnostic could be retained.
        attachHistoryObservation(afterRelaunch, stage: "after-relaunch", nativeHistoryRowVisible: historyIsVisible)
        XCTAssertTrue(afterRelaunch.persistedExactlyOnce,
                      "The same original installation must retain the exact query after relaunch")
        XCTAssertEqual(historyRows.count, 1, "The exact genuine submitted history query must occur once")
        XCTAssertTrue(historyRow.label.contains(query))
        XCTAssertTrue(historyIsVisible, "A submitted global query must appear in the original global history")
        XCTAssertTrue(historyRow.isHittable, "The submitted history row must actually be visible and usable above the native keyboard")
        XCTAssertLessThanOrEqual(historyRow.frame.maxY, app.keyboards.firstMatch.frame.minY + 2,
                                 "The original history row must remain above the real native keyboard")
        return query
    }
}

final class FaithfulReaderVisualBaselineTests: FaithfulReaderUIBase {
    func testOriginalInspectorReferenceRetainsEvidenceBeforeReaderAssertions() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: false, scenario: "studyCommentaries")
        XCTAssertTrue(app.textViews["reader-text"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].waitForExistence(timeout: 30))
        // This is an actual original-app reference, independently retained
        // before any bottom-toolbar/pixel assertion can abort the test.
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "baseline-inspector-reference-before-reader-assertions"
        image.lifetime = .keepAlways
        add(image)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "baseline-inspector-reference-ui-tree"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        assertReaderHasText()
    }

    func testOriginalGlobalSearchHistoryThroughNativeControls() {
        exerciseGlobalHistorySubmission(enabled: false)
    }

    @MainActor
    func testOriginalWindowResizePreservesReader() throws {
        try exerciseNativeWindowResize(enabled: false)
    }

    func testOriginalReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(enabled: false, scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("baseline-reader-theme-\(name)")
        }
    }

    func testOriginalReaderLibrarySearchAnnotationsAndInspectorScreenshots() {
        for scenario in ["catalog", "reader", "readerDetail", "readerTOC", "search", "annotationsList", "studyCommentaries"] {
            launchReader(enabled: false, scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if ["reader", "readerDetail", "readerTOC", "studyCommentaries"].contains(scenario) { assertReaderHasText() }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("baseline-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        }
        launchReader(enabled: false, scenario: "readerDetail", language: "en")
        assertReaderHasText()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            capture("baseline-reader-detail-en-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
    }
}

final class FaithfulReaderIPhoneTests: FaithfulReaderUIBase {
    @MainActor
    func testSourceOverviewReplacesReaderAndRestoresViewport() throws {
        try exerciseOverviewReplacement(orientation: .portrait, phone: true)
    }

    func testIPhoneKeepsOriginalReaderWithEitherIPadFeatureSetting() {
        XCUIDevice.shared.orientation = .portrait
        for enabled in [false, true] {
            launchReader(enabled: enabled)
            assertReaderHasText()
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
            XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
            let originalBottomAction = readerBottomChromeAction()
            XCTAssertTrue(originalBottomAction.exists)
            XCTAssertTrue(app.frame.contains(originalBottomAction.frame))
            capture("iphone-original-reader-ipad-flag-\(enabled)")
            if enabled && ProcessInfo.processInfo.environment["FAITHFUL_BASELINE"] != "true" {
                tap(app.buttons["reader-open-tabs-button"])
                let overview = app.descendants(matching: .any)["study-groups-overview"]
                XCTAssertTrue(overview.waitForExistence(timeout: 20))
                let toggle = app.buttons["study-tabs-layout-toggle"]
                XCTAssertTrue(toggle.waitForExistence(timeout: 15))
                if toggle.label == "תצוגת רשת" { tap(toggle) }
                let grid = overview.collectionViews.cells.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")).firstMatch
                XCTAssertTrue(grid.waitForExistence(timeout: 15))
                XCTAssertGreaterThan(grid.frame.width, 0)
                XCTAssertGreaterThanOrEqual(grid.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(grid.frame.maxX, app.frame.maxX)
                capture("iphone-compact-original-tab-grid")
                tap(toggle)
                XCTAssertTrue(overview.collectionViews.cells.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")).firstMatch.waitForExistence(timeout: 15))
                capture("iphone-compact-original-tab-list")
                tap(app.buttons["סיום"])
                assertReaderHasText()
                XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
            }
        }
    }
}

/// Selected separately after CoreSimulator confirms the largest text setting.
final class FaithfulReaderLargeTextTests: FaithfulReaderUIBase {
    func testOriginalReaderAndPublicGroupSelectorRemainUsableAtLargeTextSize() {
        let baseline = ProcessInfo.processInfo.environment["FAITHFUL_BASELINE"] == "true"
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: !baseline)
        assertReaderHasText()
        capture(baseline ? "baseline-large-text-reader" : "candidate-large-text-reader")
        if baseline {
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        } else {
            tap(app.buttons["כל הכרטיסיות"])
            XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
            // The original safe AdaptiveTabContent uses a native menu for
            // accessibility text sizes. It must still expose real membership.
            tap(app.buttons["study-group-selector"])
            XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 10))
            capture("candidate-large-text-group-menu")
        }
    }
}

final class FaithfulReaderUIAcceptanceTests: FaithfulReaderUIBase {
    private var recordsPaletteEscape = false
    private var originalNavigationInitialTab: Int?
    override var readerAdditionalLaunchArguments: [String] {
        super.readerAdditionalLaunchArguments
            + (recordsPaletteEscape ? ["-CommandPaletteEscapeTraceEnabled", "YES"] : [])
            + (originalNavigationInitialTab.map { ["-lastSelectedTab", String($0)] } ?? [])
    }


    @MainActor
    func testLibraryMorphOutsideDismissalPreservesCanonicalQueryAndReader() throws {
        recordsPaletteEscape = true
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let before = try viewport()
        let launcher = readerLibraryPaletteLauncher()
        let compactFrame = launcher.frame
        let nativeBars = app.navigationBars.containing(.button, identifier: "reader-command-palette-launcher")
        XCTAssertEqual(nativeBars.count, 1)
        XCTAssertTrue(nativeBars.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(compactFrame))
        retainNativeEvidence("library-morph-compact-native-anchor")

        tap(launcher)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertTrue(input.isHittable)
        input.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        captureOpenLibraryPalette("library-morph-expanded-real-query", palette: palette, result: result)

        let window = app.windows.firstMatch
        let windowFrame = window.frame
        let panelFrame = palette.frame
        let keyboardFrame = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame : CGRect.null
        let candidates = [
            CGPoint(x: windowFrame.minX + 6, y: panelFrame.midY),
            CGPoint(x: windowFrame.maxX - 6, y: panelFrame.midY),
            CGPoint(x: windowFrame.midX, y: panelFrame.maxY + 12)
        ]
        let outside = try XCTUnwrap(candidates.first {
            windowFrame.contains($0) && !panelFrame.insetBy(dx: -4, dy: -20).contains($0)
                && !keyboardFrame.contains($0)
        }, "An actual visible point outside the original palette must remain inside this native window")
        window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: outside.x - windowFrame.minX, dy: outside.y - windowFrame.minY)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: palette
        )], timeout: 15), .completed)
        XCTAssertEqual(palette.textFields.count, 0, "A retained collapsed field must be absent from accessibility")
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        let after = try viewport()
        XCTAssertEqual(after.source, before.source)
        XCTAssertEqual(after.object, before.object, "Closing the morph must preserve the original reader instance")
        XCTAssertEqual(after.offset, before.offset, accuracy: 1)
        XCTAssertEqual(launcher.frame.minX, compactFrame.minX, accuracy: 1)
        XCTAssertEqual(launcher.frame.minY, compactFrame.minY, accuracy: 1)
        XCTAssertEqual(launcher.frame.width, compactFrame.width, accuracy: 1)
        XCTAssertEqual(launcher.frame.height, compactFrame.height, accuracy: 1)

        tap(readerLibraryPaletteLauncher())
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        XCTAssertEqual(input.value as? String, "בראשית",
                       "The original LibraryViewModel query must survive outside dismissal")
        tap(palette.buttons["command-palette-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: palette
        )], timeout: 15), .completed)
        retainNativeEvidence("library-morph-outside-dismissed-reader")
    }

    @MainActor
    func testLibraryMorphRepeatedOpenCloseReleasesHiddenKeyboardFocus() throws {
        recordsPaletteEscape = true
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        for cycle in 0..<3 {
            tap(readerLibraryPaletteLauncher())
            XCTAssertTrue(palette.waitForExistence(timeout: 15))
            let input = palette.textFields.firstMatch
            XCTAssertTrue(input.waitForExistence(timeout: 10))
            if cycle == 0 {
                // No input tap: a real HID keystroke proves production autofocus.
                try sendNativeHID(.keyboardA)
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
                        guard let value = input.value as? String else { return false }
                        return !value.isEmpty && value != input.placeholderValue
                    } }, object: nil
                )], timeout: 10), .completed)
                try sendNativeHID(.keyboardDeleteOrBackspace)
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
                        guard let value = input.value as? String else { return false }
                        return value.isEmpty || value == input.placeholderValue
                    } }, object: nil
                )], timeout: 10), .completed)
            }
            let emptyValue = try XCTUnwrap(input.value as? String)
            XCTAssertTrue(emptyValue.isEmpty || emptyValue == input.placeholderValue,
                          "The original field must be empty before this open/close cycle")
            tap(palette.buttons["command-palette-close"])
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: palette
            )], timeout: 15), .completed)
            XCTAssertEqual(palette.textFields.count, 0)
            try sendNativeHID(.keyboardA)
            tap(readerLibraryPaletteLauncher())
            XCTAssertTrue(input.waitForExistence(timeout: 15))
            let reopenedValue = try XCTUnwrap(input.value as? String)
            XCTAssertTrue(reopenedValue.isEmpty || reopenedValue == input.placeholderValue,
                          "A closed retained field must not accept HID input or reclaim focus")
            try sendNativeHID(.keyboardEscape)
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: palette
            )], timeout: 15), .completed)
        }
        retainNativeEvidence("library-morph-repeated-native-focus-release")
        assertReaderHasText()
    }

    @MainActor
    func testSourceOverviewReplacesReaderAndRestoresViewportLandscape() throws {
        try exerciseOverviewReplacement(orientation: .landscapeLeft, phone: false)
    }

    @MainActor
    func testSourceOverviewReplacesReaderAndRestoresViewportPortrait() throws {
        try exerciseOverviewReplacement(orientation: .portrait, phone: false)
    }

    @MainActor
    func testOriginalLibraryMenusSelectionSettingsAndBookInfoRemainUsable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", language: "en")
        assertReaderHasText()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !libraryDot.exists || !libraryDot.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryDot)
        let library = app.otherElements["library-column"]
        XCTAssertTrue(library.waitForExistence(timeout: 15))
        let bar = app.navigationBars["Library"]
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Category"])
        let categoryLabels = Set(library.staticTexts.allElementsBoundByIndex.map { $0.label })
        XCTAssertFalse(categoryLabels.isEmpty, "Observe the real canonical library tree")
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Author"])
        let regrouped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let authors = Set(library.staticTexts.allElementsBoundByIndex.map { $0.label })
                return !authors.isEmpty && authors != categoryLabels
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [regrouped], timeout: 30), .completed,
                       "The original grouping action must actually change the library's visible membership")
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Category"])
        let downloaded = bar.buttons["Downloaded"]
        if downloaded.exists {
            // The original control is conditional on bundle mode. Exercise
            // its real native state only where the original source offers it.
            let selected = downloaded.isSelected
            let value = downloaded.value as? String
            tap(downloaded)
            XCTAssertTrue(downloaded.isSelected != selected || (downloaded.value as? String) != value)
            tap(downloaded)
            XCTAssertEqual(downloaded.isSelected, selected)
            XCTAssertEqual(downloaded.value as? String, value)
        }
        let options = app.collectionViews.containing(.button, identifier: "Select…").firstMatch
        let directOptions = bar.buttons["Library Options"]
        if directOptions.exists {
            tap(directOptions)
        } else {
            // iPadOS can place the original Library menu in this toolbar's
            // native overflow; use that same observed bar and its real action.
            let overflow = bar.buttons.matching(identifier: "TopOverflowBarButtonItem")
            XCTAssertEqual(overflow.count, 1, "Require one original Library toolbar overflow")
            tap(overflow.element(boundBy: 0))
            let submenu = app.collectionViews.cells.buttons.matching(identifier: "Library Options")
            let presented = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated { options.exists || submenu.count > 0 }
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [presented], timeout: 15), .completed,
                           "The original overflow must expose Library Options or its actual actions")
            if !options.exists {
                XCTAssertEqual(submenu.count, 1, "Require the unique original Library Options submenu")
                tap(submenu.element(boundBy: 0))
            }
        }
        XCTAssertTrue(options.waitForExistence(timeout: 15))
        let actions = options.cells.buttons
        XCTAssertEqual(actions.count, 2, "Otzaria retains the original Select and Import actions")
        XCTAssertEqual(Set(actions.allElementsBoundByIndex.map { $0.label }), Set(["Select…", "Import Book"]))
        XCTAssertFalse(actions.matching(NSPredicate(format: "label BEGINSWITH %@", "Books Updates")).firstMatch.exists,
                       "The Otzaria fixture must not offer the foreign Maktabah SQL updater")
        tap(options.cells.buttons["Select…"])
        XCTAssertTrue(bar.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(bar.buttons["Delete"].exists)
        XCTAssertFalse(bar.buttons["Delete"].isEnabled, "No unselected book may be deleted")
        capture("candidate-original-library-selection-actions")
        tap(bar.buttons["Done"])
        tap(app.buttons["main-settings-button"])
        XCTAssertTrue(app.buttons["settings-done-button"].waitForExistence(timeout: 15))
        capture("candidate-original-settings")
        tap(app.buttons["settings-done-button"])
        tap(app.buttons["Book Info"])
        let close = app.navigationBars.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 30))
        XCTAssertTrue(app.segmentedControls.firstMatch.exists, "The genuine unified book-info view must load")
        capture("candidate-original-book-info")
        tap(close)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, originalTitle)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        XCTAssertTrue(app.buttons["reader-more-menu"].exists)
    }

    func testOriginalBottomTOCActionOpensContentsFromLibraryPage() {
        exerciseOriginalBottomTOCAction()
    }

    @MainActor
    func testNativeVoiceOverSpeaksRealOverviewAndPaletteControls() throws {
        guard #available(iOS 27.0, *) else {
            XCTFail("The required iPadOS 27 VoiceOver service is unavailable"); return
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let bookTitle = app.staticTexts["reader-header-title"].label
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        addTeardownBlock {
            try await MainActor.run {
                let service = XCUIDevice.shared.voiceOverService
                if wasEnabled { if !service.isEnabled { XCTAssertNoThrow(try service.enable()) } }
                else { XCTAssertNoThrow(try service.disable()) }
            }
        }

        @MainActor
        func assertSpoken(_ expected: [String], name: String) throws {
            if !service.isEnabled { try service.enable() }
            XCTAssertTrue(service.isEnabled, "VoiceOver itself must actually run")
            var speech: [String] = []
            // Enabling VoiceOver can focus the Done action rather than the
            // first RTL toolbar control. Forward navigation need not wrap;
            // exercise both native directions before declaring a label absent.
            for forward in [true, false] {
                var previous: String?
                var repeats = 0
                for _ in 0..<80 {
                    let utterance = try (forward ? service.moveForward() : service.moveBackward()).utterance
                    speech.append(utterance)
                    XCTContext.runActivity(named: name) { activity in
                        let output = XCTAttachment(string: utterance)
                        output.name = name + "-\(speech.count)"
                        output.lifetime = .keepAlways
                        activity.add(output)
                    }
                    if expected.allSatisfy({ phrase in speech.contains { $0.contains(phrase) } }) { break }
                    repeats = previous == utterance ? repeats + 1 : 0
                    previous = utterance
                    if repeats >= 4 { break }
                }
                if expected.allSatisfy({ phrase in speech.contains { $0.contains(phrase) } }) { break }
            }
            for phrase in expected {
                XCTAssertTrue(speech.contains { $0.contains(phrase) }, "Actual VoiceOver speech must include \(phrase)")
            }
            // Return to ordinary XCTest pointer/touch interaction between
            // surfaces. Never substitute an accessibility audit for speech.
            try service.disable()
        }

        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        try assertSpoken(["סיום", "פעולות בקבוצת הכרטיסיות", bookTitle], name: "candidate-native-voiceover-overview-speech")
        tap(app.buttons["סיום"])
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        XCTAssertTrue(palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(palette.buttons["נקה את החיפוש"].exists)
        try assertSpoken(["בראשית", "נקה את החיפוש"], name: "candidate-native-voiceover-palette-speech")
    }

    func testActualSidecarWriteFailureRollsBackVisibleGroupAndRecovers() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        let sidecar = try workspaceSidecarURL()
        let saved = sidecar.appendingPathExtension("ui-failure-original")
        let originalBytes = try Data(contentsOf: sidecar)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
        // Block only this UUID-scoped test sidecar's atomic destination. The
        // canonical session, corpus, notes and every other sidecar stay intact.
        try FileManager.default.moveItem(at: sidecar, to: saved)
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: saved.path) {
                if FileManager.default.fileExists(atPath: sidecar.path) {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: sidecar.path)
                    XCTAssertTrue(contents.isEmpty, "Only remove the empty directory created by this test")
                    guard contents.isEmpty else { return }
                    try FileManager.default.removeItem(at: sidecar)
                }
                try FileManager.default.moveItem(at: saved, to: sidecar)
            }
        }
        try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: false)
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let prompt = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.textFields.firstMatch.typeText("קבוצה שאסור לשמור")
        tap(prompt.buttons["שמירה"])
        let error = app.alerts["לא ניתן לשנות את סביבת הלימוד"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "The actual atomic-write error must be surfaced")
        capture("candidate-actual-sidecar-write-failure")
        tap(error.buttons["אישור"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15), "Failure must retain the original group's real document")
        XCTAssertEqual(try Data(contentsOf: saved), originalBytes, "The pre-failure bytes must remain intact")
        try FileManager.default.removeItem(at: sidecar)
        try FileManager.default.moveItem(at: saved, to: sidecar)
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        // Reopening synchronizes through the same real persistence path again.
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["לא ניתן לשנות את סביבת הלימוד"].exists)
        XCTAssertNoThrow(try Data(contentsOf: sidecar))
        capture("candidate-sidecar-write-recovery")
    }

    func testFeatureOffCreatesNoSidecarAndPreservesAnExistingWorkspace() throws {
        let containers = try workspaceContainerParent()
        launchReader(enabled: false, tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader-sidebar-pager"].exists)
        XCTAssertFalse(app.buttons["reader-command-palette-launcher"].exists)
        let originalHighlights = try XCTUnwrap(getRenderedHighlightSnapshot())
        capture("candidate-before-workspace-migration-original-reader")
        app.terminate()
        XCTAssertTrue(matchingTestSidecars(in: containers, namespace: workspaceNamespace).isEmpty,
                      "Disabled startup/shutdown must not create workspace state in any installed app container")
        launchReader(tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        XCTAssertTrue(app.buttons["reader-command-palette-launcher"].waitForExistence(timeout: 30))
        let pager = app.descendants(matching: .any)["reader-sidebar-pager"]
        if !pager.exists || !pager.isHittable { tap(readerSidebarToggle()) }
        XCTAssertTrue(pager.waitForExistence(timeout: 30), "The enabled original split must mount its actual sidebar pager")
        let migratedHighlights = try XCTUnwrap(getRenderedHighlightSnapshot())
        XCTAssertEqual(migratedHighlights.searchHighlightCount, originalHighlights.searchHighlightCount)
        XCTAssertEqual(migratedHighlights.annotationHighlightCount, originalHighlights.annotationHighlightCount)
        XCTAssertEqual(migratedHighlights.segmentSelectionCount, originalHighlights.segmentSelectionCount,
                       "Enabling the workspace must not create a fake paragraph selection")
        capture("candidate-after-workspace-migration-original-reader")
        let sidecar = try workspaceSidecarURL()
        app.terminate()
        let enabledBytes = try Data(contentsOf: sidecar)
        launchReader(enabled: false, tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader-sidebar-pager"].exists)
        XCTAssertFalse(app.buttons["reader-command-palette-launcher"].exists)
        XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
        capture("candidate-disabled-original-reader")
        app.terminate()
        XCTAssertEqual(try Data(contentsOf: workspaceSidecarURL()), enabledBytes,
                       "Disabled startup/shutdown must leave an existing workspace byte-identical")
    }

    @MainActor
    func testPointerHoverClickAndHardwareKeyboardDismissal() throws {
        recordsPaletteEscape = true
        XCTAssertTrue(XCUIDevice.shared.supportsPointerInteraction,
                      "The required iPad Simulator must support real pointer events")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let field = readerLibraryPaletteLauncher()
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        let originalFieldFrame = field.frame
        let fieldPoint = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldPoint.hover()
        capture("candidate-pointer-over-compact-search")
        fieldPoint.click()
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        try sendNativeHID(.keyboardEscape)
        let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
        XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed,
                       "The original palette's Escape handler must dismiss through keyboard focus")
        let restoredFieldFrame = field.frame
        XCTAssertEqual(restoredFieldFrame.minX, originalFieldFrame.minX, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.minY, originalFieldFrame.minY, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.width, originalFieldFrame.width, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.height, originalFieldFrame.height, accuracy: 1)
        fieldPoint.click()
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        XCTAssertEqual(input.value as? String, "בראשית",
                       "Reopening the original palette without typing must retain the canonical library query")
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let resultPoint = result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        resultPoint.hover()
        capture("candidate-pointer-over-library-result")
        resultPoint.click()
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
    }

    func testGroupCopyMoveRenameAndDeleteThroughRealMenus() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let bookTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let nameAlert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        nameAlert.textFields.firstMatch.typeText("יעד העברה")
        tap(nameAlert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        let card = app.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "tab-switcher-", bookTitle)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.press(forDuration: 1)
        tap(app.buttons["העתקה לקבוצה"])
        tap(app.collectionViews.cells.buttons["יעד העברה"])
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Copy must create a real document card in its destination")
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        tap(overview.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "סגור ", bookTitle)).firstMatch)
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Closing the copied document must preserve its source")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.press(forDuration: 1)
        tap(app.buttons["העברה לקבוצה"])
        tap(app.collectionViews.cells.buttons["יעד העברה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Move must remove the source card")
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["שינוי שם הקבוצה"])
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        let nameField = nameAlert.textFields.firstMatch
        nameField.tap()
        // Exercise the native input's Select All command without relying on
        // a particular OS translation of its transient editing-menu item.
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("יעד ששמו עודכן")
        XCTAssertEqual(nameField.value as? String, "יעד ששמו עודכן")
        tap(nameAlert.buttons["שמירה"])
        selectStudyGroup(named: "יעד ששמו עודכן")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Rename must preserve membership")
        capture("candidate-group-move-copy-rename")
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["מחיקת קבוצה"])
        // The second tap is the native destructive confirmation, not the Menu.
        tap(app.buttons["מחיקת קבוצה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertFalse(card.exists)
        capture("candidate-deleted-group-retains-replacement")
    }

    @MainActor
    func testSystemReduceMotionKeepsOriginalPaletteUsable() async {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        // Keep Settings' switch frame and screenPoint in the same portrait space.
        // The original app journey below still runs in landscape.
        XCUIDevice.shared.orientation = .portrait
        settings.launch()
        @MainActor
        func openOriginalMotionSettings() -> XCUIElement {
            // Settings can be terminated while the real app is foregrounded.
            // Reacquire its current native page and switch after activation.
            let toggle = settings.switches.matching(NSPredicate(
                format: "identifier == %@ OR label == %@", "REDUCE_MOTION", "Reduce Motion"
            )).firstMatch
            if toggle.exists && toggle.isHittable { return toggle }
            let motion = settings.staticTexts["Motion"].firstMatch
            if !motion.exists || !motion.isHittable {
                let accessibility = settings.staticTexts["Accessibility"].firstMatch
                for _ in 0..<6 {
                    if accessibility.exists && accessibility.isHittable { break }
                    settings.swipeUp()
                }
                XCTAssertTrue(accessibility.waitForExistence(timeout: 15))
                accessibility.tap()
            }
            XCTAssertTrue(motion.waitForExistence(timeout: 15))
            motion.tap()
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            return toggle
        }
        let toggle = openOriginalMotionSettings()

        // Settings exposes a labelled row and its actual nested UISwitch.
        // Target that native control, with bounds witnessed in portrait.
        @MainActor
        func tapOriginalReduceMotionSwitch(_ toggle: XCUIElement, stage: String) {
            let nativeWindow = settings.windows.firstMatch
            guard toggle.exists, toggle.isHittable, nativeWindow.exists else {
                XCTFail("The original Reduce Motion switch must be visible and hittable")
                return
            }
            let track = toggle.switches.firstMatch
            guard track.exists, track.isHittable else {
                XCTFail("The original Reduce Motion row must expose its actual native switch")
                return
            }
            let rowFrame = toggle.frame
            let controlFrame = track.frame
            let windowFrame = nativeWindow.frame
            let target = track.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let point = target.screenPoint
            let geometry = [
                rowFrame.minX, rowFrame.minY, rowFrame.width, rowFrame.height,
                controlFrame.minX, controlFrame.minY, controlFrame.width, controlFrame.height,
                windowFrame.minX, windowFrame.minY, windowFrame.width, windowFrame.height,
                point.x, point.y
            ]
            let witness = XCTAttachment(string:
                "stage=\(stage)\nrowFrame=\(rowFrame)\ncontrolFrame=\(controlFrame)\nwindowFrame=\(windowFrame)\n"
                + "screenPoint=\(point)\nsystemReduceMotion=\(UIAccessibility.isReduceMotionEnabled)\n"
                + settings.debugDescription)
            witness.name = "system-reduce-motion-\(stage)-original-switch"
            witness.lifetime = .keepAlways
            add(witness)
            guard geometry.allSatisfy({ $0.isFinite }), !controlFrame.isEmpty,
                  !windowFrame.isEmpty, !rowFrame.isEmpty, rowFrame.contains(point),
                  controlFrame.contains(point), windowFrame.contains(point) else {
                XCTFail("The original switch tap must stay inside its finite visible native window")
                return
            }
            target.tap()
        }
        // Verify the actual system preference, independent of the Settings
        // switch's localized accessibility value on this OS version.
        // Yield MainActor while the system notification is delivered. A
        // synchronous XCTWaiter on this actor can block that delivery.
        @MainActor
        func waitForOriginalReduceMotion(_ enabled: Bool) async -> XCTWaiter.Result {
            let changed = XCTestExpectation(description: "Original system Reduce Motion equals \(enabled)")
            let observation = Task { @MainActor in
                while !Task.isCancelled {
                    if UIAccessibility.isReduceMotionEnabled == enabled {
                        changed.fulfill()
                        return
                    }
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return }
                }
            }
            defer { observation.cancel() }
            return await XCTWaiter.fulfillment(of: [changed], timeout: 15)
        }
        let wasEnabled = UIAccessibility.isReduceMotionEnabled
        if !wasEnabled { tapOriginalReduceMotionSwitch(toggle, stage: "enable") }
        let restoration = NativeUIRestoration {
            let readerOrientation = XCUIDevice.shared.orientation
            defer { XCUIDevice.shared.orientation = readerOrientation }
            XCUIDevice.shared.orientation = .portrait
            settings.activate()
            let restoredToggle = openOriginalMotionSettings()
            XCTAssertTrue(restoredToggle.waitForExistence(timeout: 15))
            if UIAccessibility.isReduceMotionEnabled != wasEnabled {
                tapOriginalReduceMotionSwitch(restoredToggle, stage: "restore")
            }
            let restored = await waitForOriginalReduceMotion(wasEnabled)
            let restorationWitness = XCTAttachment(string:
                "expectedSystemReduceMotion=\(wasEnabled)\n"
                + "actualSystemReduceMotion=\(UIAccessibility.isReduceMotionEnabled)\n"
                + settings.debugDescription)
            restorationWitness.name = "system-reduce-motion-after-restoration-wait"
            restorationWitness.lifetime = .keepAlways
            self.add(restorationWitness)
            XCTAssertEqual(restored, .completed)
            settings.terminate()
        }
        addTeardownBlock { await restoration.run() }
        let reduced = await waitForOriginalReduceMotion(true)
        XCTAssertEqual(reduced, .completed,
                       "The native accessibility setting must actually reach this Simulator")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        captureOpenLibraryPalette("candidate-system-reduce-motion-palette", palette: palette, result: book)
        tap(book)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        XCTAssertTrue(readerLibraryPaletteLauncher().exists)
        capture("candidate-system-reduce-motion-reader-restored")
    }

    @MainActor
    func testCandidateWindowResizePreservesOriginalReaderAndSearch() throws {
        try exerciseNativeWindowResize(enabled: true)
    }

    func testNewManagementScreensExposeMeaningfulAccessibilityDescriptions() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["פרופיל לימוד חדש"])
        XCTAssertTrue(app.textFields["שם הפרופיל"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["ביטול"])
    }

    func testCandidateReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("candidate-reader-theme-\(name)")
        }
    }

    func testEnglishReaderAndOriginalPaletteInLeftToRightLayout() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", language: "en")
        assertReaderHasText()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            capture("candidate-reader-detail-en-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let result = palette.buttons["command-palette-row-section:ספרים/otzaria|book:1|line:0"]
        captureOpenLibraryPalette("candidate-command-palette-en", palette: palette, result: result)
    }

    func testCandidateGlobalSearchLandscapeMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("search", orientation: .landscapeLeft)
    }
    func testCandidateGlobalSearchPortraitMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("search", orientation: .portrait)
    }
    func testCandidateAnnotationsLandscapeMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("annotationsList", orientation: .landscapeLeft)
    }
    func testCandidateAnnotationsPortraitMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("annotationsList", orientation: .portrait)
    }
    func testCandidateTrimmedOriginalInspectorLandscape() {
        exerciseTrimmedOriginalInspector(orientation: .landscapeLeft)
    }
    func testCandidateTrimmedOriginalInspectorPortrait() {
        exerciseTrimmedOriginalInspector(orientation: .portrait)
    }

    private func exerciseUnchangedOriginalScreen(_ scenario: String, orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let destinationTab: Int
        switch scenario {
        case "search": destinationTab = 3
        case "annotationsList": destinationTab = 5
        default:
            XCTFail("The original navigation comparison requires a known global destination")
            return
        }
        let previousInitialTab = originalNavigationInitialTab
        defer { originalNavigationInitialTab = previousInitialTab }
        // The first launch saves its selected global tab. Without an identical
        // launch preference, the second launch exercises a different restoration
        // path. Compare both original entry paths with the same inputs on each
        // side; the actual native frames and every geometry assertion remain.
        for initialTab in [0, destinationTab] {
            originalNavigationInitialTab = initialTab
            let suffix = initialTab == 0 ? "" : "-restored-tab-\(initialTab)"
            launchReader(enabled: false, scenario: scenario)
            capture("candidate-flags-off-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")\(suffix)")
            let originalBars = app.navigationBars.allElementsBoundByIndex.map { ($0.identifier, $0.frame) }
                .sorted { $0.0 < $1.0 }
            XCTAssertFalse(originalBars.isEmpty, "Observe the actual original navigation geometry")
            launchReader(scenario: scenario)
            capture("candidate-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")\(suffix)")
            let candidateBars = app.navigationBars.allElementsBoundByIndex.map { ($0.identifier, $0.frame) }
                .sorted { $0.0 < $1.0 }
            XCTAssertEqual(candidateBars.count, originalBars.count)
            for (original, candidate) in zip(originalBars, candidateBars) {
                XCTAssertEqual(candidate.0, original.0)
                XCTAssertEqual(candidate.1.minX, original.1.minX, accuracy: 1)
                XCTAssertEqual(candidate.1.minY, original.1.minY, accuracy: 1,
                               "A viewer-only document strip must not shift another global tab's native navigation")
                XCTAssertEqual(candidate.1.width, original.1.width, accuracy: 1)
                XCTAssertEqual(candidate.1.height, original.1.height, accuracy: 1)
            }
        }
    }

    private func exerciseTrimmedOriginalInspector(orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        launchReader(scenario: "studyCommentaries")
        XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-panel"].waitForExistence(timeout: 30), "The original Inspector must actually be presented")
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].waitForExistence(timeout: 15), "Original study-tool actions must remain available")
        XCTAssertFalse(app.staticTexts["כלי לימוד"].exists, "The redundant visual study-tools heading must be removed")
        XCTAssertFalse(app.staticTexts["קטע נבחר"].exists, "The redundant visual selected-segment heading must be removed")
        capture("candidate-studyCommentaries-\(orientation.isLandscape ? "landscape" : "portrait")")
        let readerWithPanel = app.textViews["reader-text"].frame
        tap(app.buttons["torah-inspector-close"])
        let inspector = app.descendants(matching: .any)["torah-inspector-panel"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: inspector
        )], timeout: 15), .completed)
        XCTAssertEqual(app.textViews["reader-text"].frame.width, readerWithPanel.width, accuracy: 1,
                       "FloatingPanel must overlay Reader without reserving an opaque column")
    }

    @MainActor
    func testSidebarPreservesOriginalTextKitViewport() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        try openSecondOriginalBookAndReturn()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        capture("candidate-reader-landscape")
        let tocDot = app.buttons["reader-sidebar-page-1"]
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !tocDot.exists || !tocDot.frame.intersects(app.frame) || tocDot.frame.isEmpty {
            tap(readerSidebarToggle())
        }
        let originalReaderWidth = app.textViews["reader-text"].frame.width
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let library = app.otherElements["library-column"]
        XCTAssertTrue(library.waitForExistence(timeout: 15))
        library.swipeUp()
        @MainActor func visibleLibraryLabels() -> [String] {
            library.staticTexts.allElementsBoundByIndex.filter {
                !$0.frame.isEmpty && $0.frame.intersects(library.frame)
            }.map { $0.label }
        }
        let originalLibraryLabels = visibleLibraryLabels()
        XCTAssertFalse(originalLibraryLabels.isEmpty, "Observe the actual scrolled library before changing sidebar pages")
        let originalViewport = try viewport()
        for _ in 0..<20 {
            tap(tocDot)
            XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
            tap(libraryDot)
            XCTAssertTrue(app.descendants(matching: .any)["library-column"].exists)
            XCTAssertEqual(visibleLibraryLabels(), originalLibraryLabels,
                           "Changing only the sidebar page must retain the original library's visible rows and scroll")
            XCTAssertEqual(app.textViews["reader-text"].frame.width, originalReaderWidth, accuracy: 1, "Sidebar page changes must preserve reader width")
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator, "Sidebar page changes must not navigate the book")
            let actual = try viewport()
            XCTAssertEqual(actual.object, originalViewport.object, "The original TextKit view must survive sidebar page changes")
            XCTAssertEqual(actual.source, originalViewport.source, "The first visible source character must remain anchored")
            XCTAssertEqual(actual.offset, originalViewport.offset, accuracy: 1, "Sidebar page changes must not shift the book viewport")
        }
        let pager = app.descendants(matching: .any)["reader-sidebar-pager"]
        for _ in 0..<20 {
            let wasContents = tocDot.isSelected
            func changedPage() -> XCTNSPredicateExpectation {
                XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    MainActor.assumeIsolated { tocDot.isSelected != wasContents }
                }, object: nil)
            }
            pager.swipeLeft()
            // Wait for the real page transition before trying the opposite
            // RTL direction; an immediate reverse gesture can undo it.
            if XCTWaiter.wait(for: [changedPage()], timeout: 3) != .completed {
                pager.swipeRight()
                XCTAssertEqual(XCTWaiter.wait(for: [changedPage()], timeout: 15), .completed,
                               "A genuine sidebar swipe must change the selected page")
            }
            XCTAssertNotEqual(tocDot.isSelected, wasContents, "A sidebar swipe must change pages without changing the reader")
        }
        capture("candidate-library-sidebar")
        tap(tocDot)
        capture("candidate-toc-sidebar")
        tap(libraryDot)
    }

    func testSourceToolbarPaletteAndOverview() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let initialTitle = app.staticTexts["reader-header-title"].label
        XCTAssertFalse(initialTitle.isEmpty)
        assertSourceActionsInsideNativeToolbarHost()
        let field = readerLibraryPaletteLauncher()
        tap(field)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let paletteField = palette.textFields.firstMatch
        XCTAssertTrue(paletteField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15), "Capture the genuine full software keyboard, not a keyboard-free preview")
        XCTAssertGreaterThan(app.keyboards.firstMatch.frame.height, 160,
                             "A keyboard accessory strip alone does not prove the full software keyboard is visible")
        paletteField.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "בראשית", initialTitle)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Actual canonical-library books must appear in original CommandPalette")
        capture("candidate-command-palette-keyboard")
        let globalHistory = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(globalHistory.exists)
        XCTAssertGreaterThanOrEqual(paletteField.frame.minY, globalHistory.frame.maxY - 1,
                                   "The actual expanded input must clear the original global tabs instead of rendering underneath them")
        tap(result)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30),
                      "The original strip must appear after the second genuine library book opens")
        capture("candidate-library-opened-reader-no-fixture-selection")
        tap(app.buttons["כל הכרטיסיות"])
        retainNativeEvidence("candidate-overview-after-toolbar-action")
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
        let layoutToggle = app.buttons["study-tabs-layout-toggle"]
        XCTAssertTrue(layoutToggle.waitForExistence(timeout: 15))
        if layoutToggle.label == "תצוגת רשת" { tap(layoutToggle) }
        XCTAssertTrue(overview.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")
        ).firstMatch.waitForExistence(timeout: 15), "The original DuckDuckGo grid cell must render the open book")
        capture("candidate-all-tabs-public-fallback")
        tap(app.buttons["study-tabs-layout-toggle"])
        XCTAssertTrue(overview.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")
        ).firstMatch.waitForExistence(timeout: 15), "The original DuckDuckGo list cell must replace the grid cell")
        capture("candidate-all-tabs-list")
        tap(layoutToggle)
        let card = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let closedID = try XCTUnwrap(UUID(uuidString: String(card.identifier.dropFirst("tab-switcher-grid-cell-".count))))
        let sidecarURL = try workspaceSidecarURL()
        func persistedTabs(containing id: UUID) throws -> (groupID: String, ids: Set<UUID>)? {
            let value = try JSONSerialization.jsonObject(with: Data(contentsOf: sidecarURL)) as? [String: Any]
            let groups = value?["groups"] as? [[String: Any]] ?? []
            for group in groups {
                let tabs = group["tabs"] as? [[String: Any]] ?? []
                let ids = Set(tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:)))
                if ids.contains(id), let groupID = group["id"] as? String { return (groupID, ids) }
            }
            return nil
        }
        let original = try XCTUnwrap(persistedTabs(containing: closedID))
        let closedCard = overview.collectionViews.cells["tab-switcher-grid-cell-" + closedID.uuidString]
        @Sendable func persistedOrder() -> [UUID]? {
            guard let bytes = try? Data(contentsOf: sidecarURL),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]],
                  let group = groups.first(where: { $0["id"] as? String == original.groupID }),
                  let tabs = group["tabs"] as? [[String: Any]] else { return nil }
            return tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:))
        }
        let beforeDrag = try XCTUnwrap(persistedOrder())
        let gridCells = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-"))
        XCTAssertGreaterThanOrEqual(gridCells.count, 2, "Open two distinct canonical books before testing actual source drag reorder")
        let destination = gridCells.element(boundBy: gridCells.count - 1)
        XCTAssertNotEqual(closedCard.identifier, destination.identifier,
                          "The real drag destination must be a different source card")
        closedCard.press(forDuration: 0.6, thenDragTo: destination)
        retainNativeEvidence("candidate-overview-after-real-drag")
        let orderObservation = XCTAttachment(string: "before=\(beforeDrag)\nafter=\(String(describing: persistedOrder()))")
        orderObservation.name = "actual-source-drag-persisted-order"
        orderObservation.lifetime = .keepAlways
        add(orderObservation)
        let reordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let order = persistedOrder() else { return false }
            return Set(order) == Set(beforeDrag) && order != beforeDrag
                && order.filter { $0 != closedID } == beforeDrag.filter { $0 != closedID }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 15), .completed,
                       "A real source drag must persist a new order without losing IDs or disturbing the other books")
        capture("candidate-overview-original-drag-reorder")
        closedCard.swipeRight()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: closedCard)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 15), .completed,
                       "The source RTL swipe must remove the exact original card")
        let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let bytes = try? Data(contentsOf: sidecarURL),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]],
                  let group = groups.first(where: { $0["id"] as? String == original.groupID }),
                  let tabs = group["tabs"] as? [[String: Any]] else { return false }
            let ids = Set(tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:)))
            return ids == original.ids.subtracting([closedID])
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 15), .completed,
                       "Swipe close must persist the exact surviving document IDs")
        capture("candidate-overview-original-swipe-close")
        tap(app.buttons["סיום"])
        _ = readerSidebarToggle()
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        capture("candidate-profile-management")
    }

    func testReaderDocumentAndGlobalBarsCollapseAndRestoreOnManualScroll() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        try openSecondOriginalBookAndReturn()
        let sidebarPage = app.buttons["reader-sidebar-page-0"]
        if sidebarPage.exists && sidebarPage.isHittable {
            tap(readerSidebarToggle())
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hittable == false"), object: sidebarPage
            )], timeout: 15), .completed, "Establish the closed-sidebar precondition before testing opening it")
        }
        let text = app.textViews["reader-text"]
        let originalObject = try viewport().object
        let strip = app.descendants(matching: .any)["reader-document-tabs"]
        XCTAssertTrue(strip.waitForExistence(timeout: 30))

        text.swipeUp()
        retainNativeEvidence("candidate-reader-after-downward-scroll")
        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: strip
        )
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 15), .completed,
                       "A deliberate downward reader scroll must collapse the document strip")
        let globalHistory = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(!globalHistory.exists || !globalHistory.isHittable,
                      "The system global tab bar should collapse with reader chrome when supported")

        XCTAssertEqual(try viewport().object, originalObject, "Collapsing chrome must retain the original TextKit instance")
        capture("candidate-reader-scroll-chrome-hidden")
        text.swipeDown()
        XCTAssertTrue(strip.waitForExistence(timeout: 15),
                      "Upward reader scrolling must restore the document strip")
        XCTAssertTrue(findTabButton(hebrew: "היסטוריה", english: "History").waitForExistence(timeout: 15))

        text.swipeUp()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: strip
        )], timeout: 15), .completed)
        tap(readerSidebarToggle())
        XCTAssertTrue(strip.waitForExistence(timeout: 15),
                      "Opening the sidebar must restore reader navigation chrome")
        XCTAssertEqual(try viewport().object, originalObject, "Restoring chrome must retain the original TextKit instance")
        capture("candidate-reader-scroll-chrome-restored")
    }

    func testTwentyGlobalTabRoundTripsKeepOriginalReaderAndBottomBar() {
        launchReader()
        assertReaderHasText()
        for _ in 0..<20 {
            for (hebrew, english) in [("היסטוריה", "History"), ("חיפוש", "Search"), ("מוסרים", "Narrators")] {
                tap(findTabButton(hebrew: hebrew, english: english))
                tap(findTabButton(hebrew: "ספר", english: "Library"))
                assertReaderHasText()
                XCTAssertTrue(app.buttons["reader-more-menu"].exists, "Original bottom toolbar must remain present after every global-tab round trip")
            }
        }
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertReaderHasText()
            capture("candidate-reader-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
    }

    func testNewEmptyGroupAndRelaunchPersistence() throws {
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("קבוצת בדיקה")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        capture("candidate-empty-group")
        tap(app.buttons["סיום"])
        retainNativeEvidence("candidate-empty-group-after-dismissal")
        XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists,
                       "An empty group must not expose a blank document strip")
        XCTAssertTrue(app.buttons["reader-tabs-overview"].exists)
        XCTAssertTrue(readerLibraryPaletteLauncher().exists,
                      "The original native overview and library palette actions must remain available without books")
        capture("candidate-library-no-open-books-toolbar")
        try attachWorkspaceSnapshot("empty-group-sidecar-before-cold-launch")
        app.terminate()
        launchReader(scenario: "catalog")
        XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 30))
        let emptyReader = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.textViews["reader-text"])
        let restored = XCTWaiter.wait(for: [emptyReader], timeout: 30)
        try attachWorkspaceSnapshot("empty-group-sidecar-after-cold-launch")
        XCTAssertEqual(restored, .completed, "Wait for the actual asynchronous sidecar projection, retaining the empty-reader requirement")
        XCTAssertFalse(app.textViews["reader-text"].exists, "The empty sidecar group must suppress stale legacy-session resurrection")
        XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
        XCTAssertTrue(readerLibraryPaletteLauncher().exists)
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Empty selection must survive app relaunch without importing old tabs again")
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
    }

    func testHistoryRemainsGlobalAndIsAbsentFromBookSearch() {
        let query = exerciseGlobalHistorySubmission(enabled: true)
        app.terminate()
        launchReader()
        assertReaderHasText()
        let bottomToolbar = app.toolbars.containing(.button, identifier: "reader-more-menu").firstMatch
        let bookSearch = bottomToolbar.buttons.matching(NSPredicate(format: "label == 'חיפוש' OR label == 'Search'")).firstMatch
        tap(bookSearch)
        let bookInput = app.searchFields.firstMatch
        tap(bookInput)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists,
                       "The same genuine history query must not be offered inside book-local search")
        capture("candidate-book-search-without-global-history")
    }

    func testSameBookRetainsIndependentLocationsAcrossGroupsAndRelaunch() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let locator = app.staticTexts["reader-current-locator"]
        let initial = locator.label
        XCTAssertFalse(initial.isEmpty)
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("מיקום שני")
        tap(alert.buttons["שמירה"])
        selectStudyGroup(named: "מיקום שני")
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(locator.label, initial)
        let next = app.buttons.matching(NSPredicate(format: "label == 'העמוד הבא' OR label == 'Next Page'")).firstMatch
        XCTAssertTrue(next.isEnabled, "The genuine fixture book must have another navigation unit")
        tap(next)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initial), object: locator)], timeout: 30), .completed)
        let second = locator.label
        XCTAssertFalse(second.isEmpty)
        for _ in 0..<20 {
            for (name, expected) in [("כל הכרטיסיות", initial), ("מיקום שני", second)] {
                tap(app.buttons["כל הכרטיסיות"])
                selectStudyGroup(named: name)
                tap(app.buttons["סיום"])
                assertReaderHasText()
                XCTAssertEqual(locator.label, expected, "Each group must restore its own actual canonical locator")
            }
        }
        capture("candidate-independent-group-locations")
        try attachWorkspaceSnapshot("independent-locations-sidecar-before-cold-launch")
        app.terminate()
        launchReader(scenario: "catalog")
        assertReaderHasText()
        let restored = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", second), object: app.staticTexts["reader-current-locator"])], timeout: 30)
        try attachWorkspaceSnapshot("independent-locations-sidecar-after-cold-launch")
        XCTAssertEqual(restored, .completed, "The asynchronously hydrated reader must reach the exact independently retained locator")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, second, "The selected group's actual locator must survive cold relaunch")
    }

    func testThreeProfilesWithThreeGroupsThroughNativeManagement() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        for name in ["לימוד א", "לימוד ב"] {
            tap(app.buttons["פרופיל לימוד חדש"])
            let field = app.textFields["שם הפרופיל"]
            tap(field)
            field.typeText(name)
            tap(app.buttons["שמירה"])
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10))
        }
        tap(app.buttons["סיום"])
        for profileName in ["אישי", "לימוד א", "לימוד ב"] {
            tap(app.buttons["study-profile-menu"])
            tap(app.buttons[profileName])
            tap(app.buttons["כל הכרטיסיות"])
            for suffix in ["א", "ב"] {
                tap(app.buttons["study-group-actions-menu"])
                tap(app.buttons["קבוצה ריקה"])
                let alert = app.alerts["שם קבוצת הכרטיסיות"]
                XCTAssertTrue(alert.waitForExistence(timeout: 10))
                alert.textFields.firstMatch.typeText("\(profileName) \(suffix)")
                tap(alert.buttons["שמירה"])
                XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
            }
            let selector = app.segmentedControls["study-group-selector"]
            let expected = ["כל הכרטיסיות", "\(profileName) א", "\(profileName) ב"]
            if selector.exists {
                XCTAssertEqual(selector.buttons.count, 3)
                for name in expected { XCTAssertTrue(selector.buttons[name].exists) }
            } else {
                // A native page sheet has compact traits even on a wide iPad.
                // Inspect the original public fallback's actual menu membership.
                let menu = app.buttons["study-group-selector"]
                XCTAssertTrue(menu.waitForExistence(timeout: 15))
                let selected = menu.value as? String
                XCTAssertEqual(selected, "\(profileName) ב")
                tap(menu)
                let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label IN %@", expected))
                XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 15))
                XCTAssertEqual(options.count, 3)
                for name in expected { XCTAssertEqual(options.matching(NSPredicate(format: "label == %@", name)).count, 1) }
                tap(options.matching(NSPredicate(format: "label == %@", "\(profileName) ב")).element(boundBy: 0))
            }
            capture("candidate-profile-groups-\(profileName)")
            tap(app.buttons["סיום"])
        }
    }
}

/// Run only against a Release binary over the full native production install.
/// No smoke scenario, bootstrap bypass, feature override or test namespace.
final class FaithfulProductionReleaseTests: FaithfulReaderUIBase {
    private var observedProductionWorkspace: (url: URL, groupID: UUID)?

    private static func documentCount(in url: URL, groupID: UUID) -> Int? {
        guard let bytes = try? Data(contentsOf: url),
              let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              let groups = value["groups"] as? [[String: Any]],
              let group = groups.first(where: { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == groupID }),
              let tabs = group["tabs"] as? [[String: Any]] else { return nil }
        return tabs.count
    }

    private static func productionWorkspaces(in containers: URL, containing documentID: UUID) -> [(url: URL, groupID: UUID)] {
        guard let directories = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) else { return [] }
        return directories.flatMap { directory -> [(url: URL, groupID: UUID)] in
            let file = directory.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")
            guard let bytes = try? Data(contentsOf: file),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]] else { return [] }
            return groups.compactMap { group in
                guard let id = (group["id"] as? String).flatMap(UUID.init(uuidString:)),
                      let tabs = group["tabs"] as? [[String: Any]],
                      tabs.contains(where: { tab in
                          let session = tab["session"] as? [String: Any]
                          return (session?["id"] as? String).flatMap(UUID.init(uuidString:)) == documentID
                      }) else { return nil }
                return (file, id)
            }
        }
    }

    private func observeProductionCurrentDocumentID() -> UUID? {
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        XCTAssertFalse(title.isEmpty)
        tap(app.buttons["reader-tabs-overview"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 15))
        let cards = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "tab-switcher-", title + ", "))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(cards.count, 1, "Observe the exact real selected book's original overview card uniquely")
        let card = cards.firstMatch
        XCTAssertTrue(!card.frame.isEmpty && card.frame.intersects(overview.frame))
        let prefix = card.identifier.hasPrefix("tab-switcher-grid-cell-")
            ? "tab-switcher-grid-cell-" : "tab-switcher-list-cell-"
        let id = UUID(uuidString: String(card.identifier.dropFirst(prefix.count)))
        XCTAssertNotNil(id, "Observe the actual original-source card's document identity")
        tap(overview.buttons["סיום"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: overview
        )], timeout: 15), .completed)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator,
                       "Identity observation must not navigate or substitute the current reader")
        return id
    }

    private func requireProductionDocumentCount(_ count: Int) {
        if observedProductionWorkspace == nil {
            guard let hint = ProcessInfo.processInfo.environment["FAITHFUL_PRODUCTION_WORKSPACE_FILE"] else {
                XCTFail("The production matrix must provide its native installation container hint"); return
            }
            guard let documentID = observeProductionCurrentDocumentID() else {
                XCTFail("Observe the actual original-source document identity before locating its ordinary sidecar"); return
            }
            var containers = URL(fileURLWithPath: hint)
            for _ in 0..<6 { containers.deleteLastPathComponent() }
            let root = containers
            let located = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                Self.productionWorkspaces(in: root, containing: documentID).count == 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [located], timeout: 30), .completed,
                           "Resolve the actual ordinary sidecar by the independently observed UI document, after XCTest installation")
            let matches = Self.productionWorkspaces(in: root, containing: documentID)
            XCTAssertEqual(matches.count, 1, "Do not choose a stale container or an arbitrary scene")
            observedProductionWorkspace = matches.first
        }
        guard let observed = observedProductionWorkspace else {
            XCTFail("The production workspace was not independently located"); return
        }
        let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Self.documentCount(in: observed.url, groupID: observed.groupID) == count
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 30), .completed,
                       "The actual production projection must persist exactly \(count) documents")
    }

    private func replacePaletteQuery(_ query: String, in input: XCUIElement) {
        input.typeKey(XCUIKeyboardKey(rawValue: "a"), modifierFlags: .command)
        input.typeText(query)
        XCTAssertEqual(input.value as? String, query)
    }

    private func openProductionBook(named title: String, isFirstDocument: Bool = false) {
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 20))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        replacePaletteQuery(title, in: input)
        let result = palette.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Select an actual title obtained from the production palette")
        tap(result)
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60))
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "(?s).+"), object: text)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 30), .completed)
        let value = text.value as? String ?? ""
        XCTAssertFalse(value.contains("Error Domain") || value.contains("Content ID not found") || value.contains("no such table"))
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        if isFirstDocument {
            // The original strip's count>1 contract is unchanged. Verify the
            // sole real document through its original overview card instead.
            XCTAssertNotNil(observeProductionCurrentDocumentID())
            return
        }
        let strip = app.descendants(matching: .any)["reader-document-tabs"]
        let selectedTitle = strip.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "reader-document-tab-", title)).firstMatch
        XCTAssertTrue(selectedTitle.waitForExistence(timeout: 15), "The genuine selected document must appear in the original-source tab strip")
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !selectedTitle.frame.isEmpty && selectedTitle.frame.intersects(strip.frame) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 15), .completed, "The selected real book tab must be inside the strip viewport")
    }

    private func exerciseThirtyRealProductionDocuments(initialTitle: String) {
        requireProductionDocumentCount(1)
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 20))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        replacePaletteQuery("משנה", in: input)
        let results = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "משנה"))
        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 30))
        var titles: [String] = []
        for _ in 0..<20 {
            for result in results.allElementsBoundByIndex {
                let title = result.label
                if title != initialTitle && !titles.contains(title) { titles.append(title) }
            }
            if titles.count >= 29 { break }
            palette.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertGreaterThanOrEqual(titles.count, 29, "Obtain 29 distinct genuine titles from the visible production UI; no invented book IDs")
        input.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let chosen = Array(titles.prefix(29))
        let membership = XCTAttachment(string: chosen.joined(separator: "\n"))
        membership.name = "release-production-thirty-real-document-titles"
        membership.lifetime = .keepAlways
        add(membership)
        for repetition in 1...2 {
            requireProductionDocumentCount(1)
            for (index, title) in chosen.enumerated() {
                openProductionBook(named: title)
                requireProductionDocumentCount(index + 2)
                if index == 0 { capture("release-production-tabs-2-cycle-\(repetition)") }
            }
            requireProductionDocumentCount(30)
            capture("release-production-tabs-30-cycle-\(repetition)")
            tap(app.buttons["כל הכרטיסיות"])
            let overview = app.descendants(matching: .any)["study-groups-overview"]
            XCTAssertTrue(overview.waitForExistence(timeout: 15))
            for remaining in stride(from: 29, through: 0, by: -1) {
                let close = overview.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "סגור ")).firstMatch
                tap(close)
                requireProductionDocumentCount(remaining)
                if remaining <= 1 { capture("release-production-tabs-\(remaining)-cycle-\(repetition)") }
            }
            XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
            tap(app.buttons["סיום"])
            XCTAssertFalse(app.textViews["reader-text"].exists)
            openProductionBook(named: initialTitle, isFirstDocument: true)
            requireProductionDocumentCount(1)
        }
    }

    func testRealProductionLibraryReaderAndGroupRestore() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria")
        dismissAlertsIfNeeded()
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 30))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        let count = palette.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ commands?$")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 30), "The original palette must expose its genuine command membership")
        let commandCount = Int(count.label.split(separator: " ").first.map(String.init) ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(commandCount, 100, "The production UI must exercise at least 100 real library results")
        input.typeText("ברכות")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ברכות")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 60), "Full production catalog must supply an actual book")
        capture("release-production-library-palette")
        tap(book)
        assertReaderHasText()
        let initialTitle = app.staticTexts["reader-header-title"].label
        for _ in 0..<20 {
            tap(findTabButton(hebrew: "היסטוריה", english: "History"))
            tap(findTabButton(hebrew: "ספר", english: "Library"))
            assertReaderHasText()
            XCTAssertTrue(app.buttons["reader-more-menu"].exists)
        }
        capture("release-production-reader")
        exerciseThirtyRealProductionDocuments(initialTitle: initialTitle)
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("בדיקת Release")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        tap(app.buttons["סיום"])
        app.terminate()
        launchWithTier(.production, backend: "otzaria")
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.textViews["reader-text"])], timeout: 30), .completed,
                       "The ordinary production sidecar must finish restoring its empty group")
        XCTAssertFalse(app.textViews["reader-text"].exists)
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 30))
        capture("release-production-empty-group-restored")
    }
}


/// Real UI bootstrap, the original profile editor/store, and a per-test UUID sidecar.
/// This case is deliberately iPad-only; it is not physical-device visual acceptance.
final class StudyProfileNativeAcceptanceTests: R27NativeUIBase {
    func testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace() throws {
        XCTAssertTrue(isPad, "The selected profile-color case requires an actual iPad Simulator")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        let locator = try assertTarget(backend: "otzaria")
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])

        // Create through the original native UI, never seed or mutate the sidecar.
        tap(app.buttons["פרופיל לימוד חדש"])
        let name = app.textFields["שם הפרופיל"]
        tap(name)
        name.typeText("פרופיל צבע נוסף")
        tap(app.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["פרופיל צבע נוסף"].waitForExistence(timeout: 10))
        let before = try profileWorkspace()
        let profiles = try XCTUnwrap(before["profiles"] as? [[String: Any]])
        XCTAssertEqual(profiles.count, 2)
        let personal = try XCTUnwrap(profiles.first { $0["name"] as? String == "אישי" })
        let other = try XCTUnwrap(profiles.first { $0["name"] as? String == "פרופיל צבע נוסף" })
        let profileID = try XCTUnwrap(personal["id"] as? String)
        XCTAssertNotNil(UUID(uuidString: profileID))
        XCTAssertNil(personal["color"])
        XCTAssertNil(other["color"])

        openProfileEditor(id: profileID)
        chooseProfileColor(named: "אדום")
        tap(app.buttons["ביטול"])
        XCTAssertTrue(app.buttons["study-profile-actions-\(profileID)"].waitForExistence(timeout: 10))
        let cancelled = try profileWorkspace()
        XCTAssertEqual(try normalizedProfileValue(cancelled["profiles"]),
                       try normalizedProfileValue(before["profiles"]),
                       "Cancel must not persist the draft color or alter another profile")

        openProfileEditor(id: profileID)
        XCTAssertEqual(profileColorPicker().value as? String, "ברירת מחדל")
        chooseProfileColor(named: "כחול")
        tap(app.buttons["שמירה"])
        let rows = app.staticTexts.matching(identifier: "study-profile-\(profileID)")
        let row = rows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1, "The original visible text must identify exactly this profile UUID")
        XCTAssertEqual(row.label, try XCTUnwrap(personal["name"] as? String))
        XCTAssertTrue(row.isHittable)
        XCTAssertEqual(row.value as? String, "כחול", "The original visible profile row must expose the selected color")
        capture("profile-color-original-management-blue")
        try attachWorkspaceSnapshot("profile-color-after-original-save")
        let saved = try profileWorkspace()
        let savedProfiles = try XCTUnwrap(saved["profiles"] as? [[String: Any]])
        var changed = try XCTUnwrap(savedProfiles.first { $0["id"] as? String == profileID })
        XCTAssertEqual(changed.removeValue(forKey: "color") as? String, "blue")
        XCTAssertEqual(try normalizedProfileValue(changed), try normalizedProfileValue(personal),
                       "A color-only Save preserves the original profile UUID, name, icon and order")
        XCTAssertEqual(try normalizedProfileValue(savedProfiles.first { $0["id"] as? String == other["id"] as? String }),
                       try normalizedProfileValue(other), "Another profile remains unchanged")
        for key in ["groups", "scenes"] {
            XCTAssertEqual(try normalizedProfileValue(saved[key]), try normalizedProfileValue(before[key]),
                           "A profile color cannot change documents, locators, group membership or scene selection")
        }
        tap(app.buttons["סיום"])
        XCTAssertEqual(try assertTarget(backend: "otzaria"), locator)

        app.terminate()
        launchReader()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), locator)
        let restored = try profileWorkspace()
        XCTAssertEqual(try normalizedProfileValue(restored["profiles"]), try normalizedProfileValue(saved["profiles"]),
                       "The actual persisted color and untouched profile must survive a cold app launch")
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        openProfileEditor(id: profileID)
        XCTAssertEqual(profileColorPicker().value as? String, "כחול")
        capture("profile-color-original-editor-after-cold-relaunch")
        chooseProfileColor(named: "ברירת מחדל")
        tap(app.buttons["שמירה"])
        XCTAssertTrue(app.buttons["study-profile-actions-\(profileID)"].waitForExistence(timeout: 10))
        let reset = try profileWorkspace()
        let resetProfiles = try XCTUnwrap(reset["profiles"] as? [[String: Any]])
        XCTAssertEqual(try normalizedProfileValue(resetProfiles), try normalizedProfileValue(profiles),
                       "Explicit default selection restores the original omitted optional field")
        try attachWorkspaceSnapshot("profile-color-reset-to-original-default")
        tap(app.buttons["סיום"])
        XCTAssertEqual(try assertTarget(backend: "otzaria"), locator)
    }

    private func openProfileEditor(id: String) {
        tap(app.buttons["study-profile-actions-\(id)"])
        let editActions = app.collectionViews.cells.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "pencil", "עריכה")
        )
        XCTAssertTrue(editActions.firstMatch.waitForExistence(timeout: 15),
                      "The selected profile's original Edit menu action must appear")
        XCTAssertEqual(editActions.count, 1,
                       "The profile Edit action must be distinct from the navigation bar's reordering Edit button")
        tap(editActions.element)
        XCTAssertTrue(profileColorPicker().waitForExistence(timeout: 10))
    }

    private func profileColorPicker() -> XCUIElement {
        app.buttons["study-profile-color"]
    }

    private func chooseProfileColor(named name: String) {
        let picker = profileColorPicker()
        XCTAssertTrue(picker.isHittable)
        guard let currentValue = picker.value as? String, !currentValue.isEmpty else {
            XCTFail("The identified native Picker must expose its current value before interaction")
            return
        }
        let valueLabels = picker.staticTexts.matching(NSPredicate(format: "label == %@", currentValue))
        guard valueLabels.count == 1 else {
            XCTFail("Tap the unique exact current-value label inside the identified native Picker")
            return
        }
        let valueLabel = valueLabels.element
        let pickerFrame = picker.frame
        let valueFrame = valueLabel.frame
        let windowFrame = app.windows.firstMatch.frame
        let finiteFrames = [pickerFrame, valueFrame, windowFrame].allSatisfy {
            !$0.isNull && !$0.isInfinite && !$0.isEmpty
                && $0.minX.isFinite && $0.minY.isFinite
                && $0.width.isFinite && $0.height.isFinite
        }
        guard picker.isHittable, valueLabel.isHittable, finiteFrames,
              pickerFrame.contains(valueFrame), windowFrame.contains(valueFrame) else {
            XCTFail("The current-value label must be hittable and fully inside its Picker and actual window")
            return
        }
        tap(valueLabel)
        tap(app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch)
        XCTAssertEqual(picker.value as? String, name, "Selection must be visible in the original native Picker before Save")
    }

    private func profileWorkspace() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: workspaceSidecarURL())) as? [String: Any])
    }

    private func normalizedProfileValue(_ value: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: XCTUnwrap(value), options: [.sortedKeys, .fragmentsAllowed])
    }
}

// MARK: - One hundred original group transitions (additional Native acceptance)

extension FaithfulReaderUIBase {
    @MainActor
    fileprivate func prepareSingleBookForGroupStress() throws {
        try establishSingleBookOverviewFixture(phone: false)
    }
}

/// Read-only projection of the original persisted document/navigation identity.
/// Geometry checkpoints and revision are observed separately, never rewritten.
private struct GroupStressWorkspace: Decodable, Sendable {
    struct Profile: Decodable, Equatable, Sendable {
        let id: UUID
        let name: String
        let symbol: String
        let order: Int
        let color: String?
    }
    struct Locator: Decodable, Equatable, Sendable {
        struct Position: Decodable, Equatable, Sendable {
            let kind: String
            let integer: Int?
            let string: String?
        }
        let backend: String
        let workKey: String
        let position: Position
    }
    struct Document: Decodable, Equatable, Sendable {
        struct Session: Decodable, Equatable, Sendable {
            let id: UUID
            let bookId: Int
            let bookTitle: String?
            let backendLocator: Locator?
            let locator: Locator?
            let contentId: Int?
            let page: Int?
            let part: Int?
            let searchText: String?
            let searchModeRaw: Int?
            let nearDistance: Int?
            let highlightTerms: [String]?
        }
        let backend: String
        let session: Session
    }
    struct Group: Decodable, Equatable, Sendable {
        let id: UUID
        let profileID: UUID
        let name: String
        let order: Int
        let tabs: [Document]
        let activeTabID: UUID?
    }
    struct Scene: Decodable, Sendable {
        let profileID: UUID
        let groupID: UUID
        let activeTabIDsByGroup: [UUID: UUID]?
    }
    let version: Int
    let revision: UInt64
    let profiles: [Profile]
    let groups: [Group]
    let scenes: [String: Scene]
    let lastActiveSceneID: String?

    var current: (sceneID: String, scene: Scene, group: Group, document: Document)? {
        guard let sceneID = lastActiveSceneID, let scene = scenes[sceneID],
              let group = groups.first(where: { $0.id == scene.groupID && $0.profileID == scene.profileID }),
              let activeID = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID,
              let document = group.tabs.first(where: { $0.session.id == activeID }) else { return nil }
        return (sceneID, scene, group, document)
    }
}

@MainActor
private enum GroupStressSnapshot {
    // All attributes below come from one actual XCTest snapshot. No snapshot
    // survives a tap, workspace transition, or predicate evaluation.
    static func descendants(of root: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        var result: [any XCUIElementSnapshot] = []
        for child in root.children {
            result.append(child)
            result.append(contentsOf: descendants(of: child))
        }
        return result
    }

    static func matches(_ element: any XCUIElementSnapshot, identifying name: String) -> Bool {
        // Preserve XCUIElementQuery's string-subscript identifying properties.
        element.identifier == name || element.title == name || element.label == name
            || element.value as? String == name || element.placeholderValue == name
    }

    static func documentCards(under overview: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        @MainActor
        func visit(_ node: any XCUIElementSnapshot, insideCollection: Bool) -> [any XCUIElementSnapshot] {
            var result: [any XCUIElementSnapshot] = []
            for child in node.children {
                if insideCollection, child.elementType == .cell,
                   child.identifier.hasPrefix("tab-switcher-grid-cell-") {
                    result.append(child)
                }
                result.append(contentsOf: visit(child, insideCollection:
                    insideCollection || child.elementType == .collectionView))
            }
            return result
        }
        // The original scope is overview.collectionViews.cells, not all cards
        // anywhere in the app. Visit each descendant once even for nested lists.
        return visit(overview, insideCollection: false)
    }

    static func finitePositive(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !frame.isEmpty
            && frame.minX.isFinite && frame.minY.isFinite
            && frame.width.isFinite && frame.height.isFinite
    }
}

@MainActor
private final class GroupStressNativeObservation {
    let application: XCUIApplication
    let url: URL
    let name: String
    let sceneID: String?
    let afterRevision: UInt64?

    init(application: XCUIApplication, url: URL, name: String, sceneID: String?, afterRevision: UInt64?) {
        self.application = application
        self.url = url
        self.name = name
        self.sceneID = sceneID
        self.afterRevision = afterRevision
    }

    func read() -> GroupStressWorkspace? {
        guard let bytes = try? Data(contentsOf: url),
              let workspace = try? JSONDecoder().decode(GroupStressWorkspace.self, from: bytes),
              let current = workspace.current, workspace.version == 1,
              current.group.name == name, current.group.tabs.count == 1,
              sceneID.map({ current.sceneID == $0 }) ?? true,
              afterRevision.map({ workspace.revision > $0 }) ?? true else { return nil }
        guard let snapshot = try? application.snapshot() else { return nil }
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        let overviews = elements.filter { GroupStressSnapshot.matches($0, identifying: "study-groups-overview") }
        guard overviews.count == 1, let overviewSnapshot = overviews.first,
              !elements.contains(where: {
                  $0.elementType == .alert
                      && GroupStressSnapshot.matches($0, identifying: "לא ניתן לשנות את סביבת הלימוד")
              }) else { return nil }
        let segments = elements.filter {
            $0.elementType == .segmentedControl && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        }
        let controls = segments.isEmpty ? elements.filter {
            $0.elementType == .button && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        } : segments
        guard controls.count == 1, let controlSnapshot = controls.first,
              controlSnapshot.isEnabled, controlSnapshot.value as? String == name else { return nil }
        let cards = GroupStressSnapshot.documentCards(under: overviewSnapshot)
        let expectedCardID = "tab-switcher-grid-cell-" + current.document.session.id.uuidString
        guard cards.count == 1, let cardSnapshot = cards.first,
              cardSnapshot.identifier == expectedCardID, cardSnapshot.isSelected else { return nil }

        // Hittability is a live XCUIElement property, not a frame approximation
        // or snapshot attribute. Keep both original real hit-test requirements.
        let overview = application.descendants(matching: .any)["study-groups-overview"]
        let control = controlSnapshot.elementType == .segmentedControl
            ? application.segmentedControls["study-group-selector"]
            : application.buttons["study-group-selector"]
        let card = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier == %@", expectedCardID)).element
        guard control.isHittable, card.isHittable else { return nil }
        return workspace
    }
}

@MainActor
private final class GroupStressEvidence {
    var transitions: [[String: Any]] = []
    var completedTransitions = 0
    var coldRestoreVerified = false
    let emit: @MainActor (Data) -> Void

    init(emit: @escaping @MainActor (Data) -> Void) { self.emit = emit }

    func record(_ value: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("GROUP_STRESS_OBSERVATION " + text)
        }
    }

    func attachReport() {
        let value: [String: Any] = [
            "schema": 1, "requiredConsecutiveTransitions": 100,
            "completedTransitions": completedTransitions,
            "coldRestoreVerified": coldRestoreVerified,
            "timingScope": "XCTest tap, original commit and accessibility observation; not product p95",
            "transitions": transitions
        ]
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) { emit(data) }
    }
}

// MARK: Actual app process observations for the original groups100 case

private struct GroupStressApplicationMetric: Codable, Sendable {
    let schema: Int
    let timingScope: String
    let memoryMetric: String
    let memoryScope: String
    let namespace: String
    let operationID: UUID
    let launchID: UUID
    let sequence: Int
    let processID: Int32
    let sceneID: String
    let fromGroupID: UUID?
    let toGroupID: UUID
    let observedGroupID: UUID?
    let fromDocumentID: UUID?
    let observedDocumentID: UUID?
    let beforeRevision: UInt64?
    let afterRevision: UInt64?
    let fromBackend: String
    let observedBackend: String
    let footprintBeforeBytes: UInt64?
    let footprintAfterBytes: UInt64?
    let elapsedSeconds: Double
    let returnedNormally: Bool
}

private struct GroupStressMetricExpectation: Sendable {
    let sceneID: String
    let fromGroupID: UUID
    let toGroupID: UUID
    let fromDocumentID: UUID
    let toDocumentID: UUID
    let observedBeforeRevision: UInt64
    let observedAfterRevision: UInt64
}

/// Reads the real app container's original reader log. Matching is independently
/// bound to the UI/sidecar observations, not to a flag claiming a successful test.
private struct GroupStressMetricReader: Sendable {
    enum Failure: Error { case missingOrInvalidEvidence }
    let url: URL
    let namespace: String
    let expected: [GroupStressMetricExpectation]

    func samples() throws -> [GroupStressApplicationMetric] {
        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard resource.isRegularFile == true, resource.isSymbolicLink == false else {
            throw Failure.missingOrInvalidEvidence
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let prefix = "[NativeGroupSwitchPerformance] "
        return try text.split(separator: "\n").compactMap { line in
            guard let range = line.range(of: prefix) else { return nil }
            let bytes = Data(line[range.upperBound...].utf8)
            let sample = try JSONDecoder().decode(GroupStressApplicationMetric.self, from: bytes)
            return sample.namespace == namespace ? sample : nil
        }
    }

    func matched() throws -> [GroupStressApplicationMetric] {
        let records = try samples()
        guard expected.count == 100 else { throw Failure.missingOrInvalidEvidence }
        var selected: [GroupStressApplicationMetric] = []
        for observation in expected {
            let matches = records.filter { sample in
                guard sample.sceneID == observation.sceneID,
                      sample.fromGroupID == observation.fromGroupID,
                      sample.toGroupID == observation.toGroupID,
                      sample.observedGroupID == observation.toGroupID,
                      sample.fromDocumentID == observation.fromDocumentID,
                      sample.observedDocumentID == observation.toDocumentID,
                      let before = sample.beforeRevision, let after = sample.afterRevision else { return false }
                // Ordinary checkpoints may advance revision between the UI
                // observations and tap. The actual commit must lie inside them.
                return before >= observation.observedBeforeRevision && after > before
                    && after <= observation.observedAfterRevision
            }
            guard matches.count == 1, let sample = matches.first,
                  sample.schema == 1, sample.returnedNormally,
                  sample.fromBackend == "otzaria", sample.observedBackend == "otzaria",
                  sample.processID > 0, sample.elapsedSeconds.isFinite, sample.elapsedSeconds >= 0,
                  sample.timingScope == "original group operation through ordinary session persistence",
                  sample.memoryMetric == "phys_footprint_bytes",
                  sample.memoryScope == "operation boundary samples; not continuous peak RSS",
                  (sample.footprintBeforeBytes ?? 0) > 0, (sample.footprintAfterBytes ?? 0) > 0 else {
                throw Failure.missingOrInvalidEvidence
            }
            selected.append(sample)
        }
        guard Set(selected.map(\.operationID)).count == 100,
              Set(selected.map(\.launchID)).count == 1,
              Set(selected.map(\.processID)).count == 1,
              let first = selected.first,
              selected.enumerated().allSatisfy({ $0.element.sequence == first.sequence + $0.offset }) else {
            throw Failure.missingOrInvalidEvidence
        }
        return selected
    }
}

// END Actual app process observations

/// Additional iPad/miniTest10 coverage. This does not replace any original case,
/// full-production-data acceptance, physical-device testing, or a latency gate.
final class StudyGroupStressNativeAcceptanceTests: R27NativeUIBase {
    override var readerTestTier: TestTier { .realUI }
    override var readerAdditionalLaunchArguments: [String] {
        super.readerAdditionalLaunchArguments + ["-StudyGroupPerformanceEnabled", "YES"]
    }

    @MainActor
    func testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore() throws {
        XCTAssertTrue(isPad, "This additional case requires the original iPad group UI")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", tier: .realUI)
        let initialLocator = try assertTarget(backend: "otzaria")
        let url = try verifiedGroupStressSidecar()
        // A fresh UUID sidecar can import real legacy tabs. Use the existing
        // original UI preparation only after the miniTest10/ownership gates.
        try prepareSingleBookForGroupStress()
        openGroupStressOverview()
        let initial = try readGroupStressWorkspace(url)
        XCTAssertEqual(initial.version, 1)
        XCTAssertEqual(initial.profiles.count, 1)
        XCTAssertEqual(initial.groups.count, 1)
        let original = try XCTUnwrap(initial.current)
        XCTAssertEqual(original.group.tabs.count, 1)
        XCTAssertEqual(original.document.backend, "otzaria")
        var workspace = try waitForOriginalGroup(named: original.group.name, at: url,
                                                 sceneID: original.sceneID, afterRevision: nil)
        let profileID = original.scene.profileID
        var names = [original.group.name]
        for name in ["רצף א", "רצף ב"] {
            XCTAssertFalse(workspace.groups.contains { $0.name == name })
            let beforeRevision = workspace.revision
            tap(app.buttons["study-group-actions-menu"])
            tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
            let prompt = app.alerts["שם קבוצת הכרטיסיות"]
            XCTAssertTrue(prompt.exists || prompt.waitForExistence(timeout: 10))
            prompt.textFields.firstMatch.typeText(name)
            tap(prompt.buttons["שמירה"])
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: beforeRevision)
            names.append(name)
        }
        XCTAssertEqual(workspace.groups.count, 3)
        XCTAssertEqual(Set(workspace.groups.map(\.id)).count, 3)
        XCTAssertTrue(workspace.groups.allSatisfy { $0.profileID == profileID && $0.tabs.count == 1 })
        XCTAssertEqual(Set(workspace.groups.flatMap { $0.tabs.map { $0.session.id } }).count, 3,
                       "Original copies must retain three different document owners, not one shared UUID")

        // Hydrate every original reader before pinning its durable navigation
        // state. These preparation transitions are explicitly not counted.
        var locators: [UUID: String] = [:]
        for name in names {
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(previous.group.name, name)
            selectOriginalStressGroup(named: name)
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let current = try XCTUnwrap(workspace.current)
            closeGroupStressOverview()
            let locator = try assertTarget(backend: "otzaria")
            XCTAssertEqual(locator, initialLocator, "Copying a group preserves the actual original reading unit")
            locators[current.group.id] = locator
            openGroupStressOverview()
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: nil)
        }
        let baseline = workspace
        XCTAssertEqual(locators.count, 3)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-before-consecutive-switches")
        retainNativeEvidence("groups100-before-consecutive-switches")
        let evidence = GroupStressEvidence { [weak self] data in
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "groups100-original-transition-observations"
            attachment.lifetime = .keepAlways
            self?.add(attachment)
        }
        addTeardownBlock { await evidence.attachReport() }

        var performanceExpectations: [GroupStressMetricExpectation] = []
        for step in 1...100 {
            let target = try XCTUnwrap(baseline.groups.first { $0.name == names[(step - 1) % names.count] })
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(target.id, previous.group.id, "A same-group tap is not a counted transition")
            let targetDocument = try XCTUnwrap(target.tabs.first)
            XCTAssertNotEqual(targetDocument.session.id, previous.document.session.id)
            let start = ProcessInfo.processInfo.systemUptime
            var observation: [String: Any] = [
                "step": step, "state": "attempted", "sceneID": previous.sceneID,
                "profileID": profileID.uuidString,
                "fromGroupID": previous.group.id.uuidString, "toGroupID": target.id.uuidString,
                "fromDocumentID": previous.document.session.id.uuidString,
                "toDocumentID": targetDocument.session.id.uuidString,
                "beforeRevision": workspace.revision
            ]
            evidence.transitions.append(observation)
            evidence.record(observation)
            selectOriginalStressGroup(named: target.name)
            let selectionReturnedAt = ProcessInfo.processInfo.systemUptime
            workspace = try waitForOriginalGroup(named: target.name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let observationReturnedAt = ProcessInfo.processInfo.systemUptime
            observation["automationSelectionElapsedSeconds"] = selectionReturnedAt - start
            observation["automationObservationElapsedSeconds"] = observationReturnedAt - selectionReturnedAt
            let current = try XCTUnwrap(workspace.current)
            XCTAssertEqual(current.group.id, target.id)
            XCTAssertEqual(current.document.session.id, targetDocument.session.id)
            XCTAssertEqual(current.scene.profileID, profileID)
            try assertOriginalGroupMembership(workspace, matches: baseline)
            performanceExpectations.append(.init(
                sceneID: previous.sceneID, fromGroupID: previous.group.id, toGroupID: current.group.id,
                fromDocumentID: previous.document.session.id, toDocumentID: current.document.session.id,
                observedBeforeRevision: try XCTUnwrap(observation["beforeRevision"] as? UInt64),
                observedAfterRevision: workspace.revision))
            observation["state"] = "committed"
            observation["afterRevision"] = workspace.revision
            observation["observedGroupID"] = current.group.id.uuidString
            observation["observedDocumentID"] = current.document.session.id.uuidString
            observation["selectedOriginalCardID"] = "tab-switcher-grid-cell-" + current.document.session.id.uuidString
            observation["selectedOriginalGroupName"] = current.group.name
            observation["automationElapsedSeconds"] = ProcessInfo.processInfo.systemUptime - start
            evidence.transitions[step - 1] = observation
            evidence.completedTransitions += 1
            evidence.record(observation)
        }
        XCTAssertEqual(evidence.completedTransitions, 100)
        XCTAssertEqual(evidence.transitions.count, 100)
        try captureGroupApplicationMetrics(sidecar: url, expected: performanceExpectations)
        let final = try XCTUnwrap(workspace.current)
        try attachWorkspaceSnapshot("groups100-after-100-original-commits")
        retainNativeEvidence("groups100-after-100-original-commits")
        closeGroupStressOverview()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), locators[final.group.id])

        app.terminate()
        launchReader(scenario: "catalog", backend: "otzaria", tier: .realUI)
        XCTAssertEqual(try verifiedGroupStressSidecar().standardizedFileURL, url.standardizedFileURL,
                       "Cold launch must retain this same installed app and owned namespace")
        let finalLocator = try XCTUnwrap(locators[final.group.id])
        let locator = app.staticTexts["reader-current-locator"]
        if locator.label != finalLocator {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", finalLocator), object: locator)], timeout: 30), .completed)
        }
        XCTAssertEqual(try assertTarget(backend: "otzaria"), finalLocator)
        openGroupStressOverview()
        // A genuine cold launch may create a different system scene identifier.
        // Its restored group/profile/document must still be the exact final one.
        workspace = try waitForOriginalGroup(named: final.group.name, at: url,
                                              sceneID: nil, afterRevision: nil)
        let restored = try XCTUnwrap(workspace.current)
        XCTAssertEqual(restored.scene.profileID, profileID)
        XCTAssertEqual(restored.group.id, final.group.id)
        XCTAssertEqual(restored.document.session.id, final.document.session.id)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-after-cold-restore")
        retainNativeEvidence("groups100-after-cold-restore")
        closeGroupStressOverview()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), finalLocator)
        evidence.coldRestoreVerified = true
    }


    @MainActor
    private func captureGroupApplicationMetrics(sidecar: URL, expected: [GroupStressMetricExpectation]) throws {
        var container = sidecar
        for _ in 0..<6 { container.deleteLastPathComponent() }
        let reader = GroupStressMetricReader(
            url: container.appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log"),
            namespace: workspaceNamespace, expected: expected)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? reader.matched()) != nil
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 10)
        // Retain available real observations even if the additional evidence
        // requirement fails. Never substitute XCTest IPC duration or a constant.
        if let raw = try? reader.samples(), let bytes = try? JSONEncoder().encode(raw) {
            let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            attachment.name = "groups100-application-raw-boundary-samples"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(result, .completed, "Require 100 uniquely matched actual app operation/memory observations")
        let samples = try reader.matched()
        let elapsedMS = samples.map { $0.elapsedSeconds * 1000 }.sorted()
        func percentile(_ fraction: Double) -> Double {
            elapsedMS[max(0, Int(ceil(Double(elapsedMS.count) * fraction)) - 1)]
        }
        let footprint = samples.flatMap { [$0.footprintBeforeBytes!, $0.footprintAfterBytes!] }
        let value: [String: Any] = [
            "schema": 1, "namespace": workspaceNamespace, "count": samples.count,
            "timingScope": samples[0].timingScope, "percentileMethod": "nearest rank",
            "p50OperationMilliseconds": percentile(0.50),
            "p95OperationMilliseconds": percentile(0.95),
            "maxOperationMilliseconds": elapsedMS.last!,
            "memoryMetric": samples[0].memoryMetric, "memoryScope": samples[0].memoryScope,
            "boundarySampleCount": footprint.count,
            "firstFootprintBytes": samples[0].footprintBeforeBytes!,
            "lastFootprintBytes": samples.last!.footprintAfterBytes!,
            "maxObservedBoundaryFootprintBytes": footprint.max()!,
            "performanceThresholdDefined": false,
            "scope": "Debug iPad Simulator miniTest10; not first-pixel, physical-device, full-corpus, CPU or continuous-peak acceptance"
        ]
        let report = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                                  uniformTypeIdentifier: "public.json")
        report.name = "groups100-application-operation-memory-summary"
        report.lifetime = .keepAlways
        add(report)
    }

    @MainActor
    private func verifiedGroupStressSidecar() throws -> URL {
        XCTAssertEqual(readerTestTier, .realUI)
        XCTAssertNotNil(UUID(uuidString: workspaceNamespace))
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        for (key, expected) in [("-OtzariaDataProfile", "miniTest10"),
                                ("-studyWorkspaceTestingNamespace", workspaceNamespace),
                                ("-preferredBackend", "otzaria")] {
            let indexes = app.launchArguments.indices.filter { app.launchArguments[$0] == key }
            XCTAssertEqual(indexes.count, 1)
            let index = try XCTUnwrap(indexes.first)
            XCTAssertTrue(app.launchArguments.indices.contains(index + 1))
            XCTAssertEqual(app.launchArguments[index + 1], expected)
        }
        XCTAssertEqual(app.launchEnvironment["OTZARIA_DATA_PROFILE"], "miniTest10")
        XCTAssertEqual(app.launchEnvironment["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"], "miniTest10")
        XCTAssertTrue(try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"]).hasPrefix("book:"),
                      "The original matrix must independently validate the installed miniTest10 fixture")
        let url = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        XCTAssertEqual(Array(url.pathComponents.suffix(suffix.count)), suffix)
        var container = url
        for _ in suffix { container.deleteLastPathComponent() }
        XCTAssertEqual(container.deletingLastPathComponent(), try workspaceContainerParent().standardizedFileURL)
        XCTAssertNotNil(UUID(uuidString: container.lastPathComponent))
        let metadata = try Data(contentsOf: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
        let record = try XCTUnwrap(PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        XCTAssertEqual(record["MCMMetadataIdentifier"] as? String, "com.davidpovarsky.chavrusatext")
        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        XCTAssertEqual(resource.isRegularFile, true)
        XCTAssertEqual(resource.isSymbolicLink, false)
        return url
    }

    private func readGroupStressWorkspace(_ url: URL) throws -> GroupStressWorkspace {
        try JSONDecoder().decode(GroupStressWorkspace.self, from: Data(contentsOf: url))
    }

    @MainActor
    private func openGroupStressOverview() {
        tap(app.buttons["reader-tabs-overview"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.exists || overview.waitForExistence(timeout: 15))
        let toggle = app.buttons["study-tabs-layout-toggle"]
        XCTAssertTrue(toggle.exists || toggle.waitForExistence(timeout: 10))
        if toggle.label == "תצוגת רשת" { tap(toggle) }
    }

    @MainActor
    private func closeGroupStressOverview() {
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        tap(overview.buttons["סיום"])
        if overview.exists {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: overview)], timeout: 15), .completed)
        }
    }

    @MainActor
    private func retainOriginalGroupSelectionObservation(
        _ gate: String, expectedName: String,
        selectors: [any XCUIElementSnapshot], targets: [any XCUIElementSnapshot],
        window: (any XCUIElementSnapshot)?, snapshotSeconds: Double,
        live: [String: Any] = [:],
        attachmentName: String = "groups100-original-selection-failed-snapshot"
    ) {
        let selector = selectors.first
        let target = targets.first
        var value: [String: Any] = [
            "gate": gate, "expectedLabel": expectedName,
            "selectorCount": selectors.count, "targetCount": targets.count,
            "oneEnabledSelector": selectors.count == 1 && selector?.isEnabled == true,
            "oneExactLabelTarget": targets.count == 1,
            "windowPresent": window != nil,
            "selectors": selectors.map { NativeGeometryEvidence.element($0) },
            "targets": targets.map { NativeGeometryEvidence.element($0) },
            "snapshotSeconds": snapshotSeconds, "liveQueries": live
        ]
        if let window { value["window"] = NativeGeometryEvidence.element(window) }
        if let selector, let target, let window {
            value["allFramesFinitePositive"] = [selector.frame, target.frame, window.frame]
                .allSatisfy { GroupStressSnapshot.finitePositive($0) }
            value["selectorContainsTarget"] = selector.frame.contains(target.frame)
            value["windowContainsTarget"] = window.frame.contains(target.frame)
            let tapPoint = CGPoint(x: target.frame.midX, y: target.frame.midY)
            let components = ["x": Double(tapPoint.x), "y": Double(tapPoint.y)]
            value["requestedTapPoint"] = [
                "decimal": components.mapValues { String($0) },
                "ieee754Hex": components.mapValues { String($0.bitPattern, radix: 16) }
            ]
            value["targetEnabled"] = target.isEnabled
            value["selectorContainsRequestedTapPoint"] = selector.frame.contains(tapPoint)
            value["windowContainsRequestedTapPoint"] = window.frame.contains(tapPoint)
            value["observationContract"] = "Original midpoint interaction; whole-selector AX containment remains diagnostic"
        }
        let attachment = XCTAttachment(string: NativeGeometryEvidence.text(value))
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func selectOriginalStressGroup(named name: String) {
        let snapshotStart = ProcessInfo.processInfo.systemUptime
        guard let snapshot = try? app.snapshot() else {
            retainOriginalGroupSelectionObservation("snapshot_unavailable", expectedName: name,
                selectors: [], targets: [], window: nil,
                snapshotSeconds: ProcessInfo.processInfo.systemUptime - snapshotStart)
            XCTFail("Require a fresh actual app snapshot before the original group action")
            return
        }
        let snapshotSeconds = ProcessInfo.processInfo.systemUptime - snapshotStart
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        let selectors = elements.filter {
            $0.elementType == .segmentedControl && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        }
        if !selectors.isEmpty {
            guard selectors.count == 1, let selectorSnapshot = selectors.first,
                  selectorSnapshot.isEnabled else {
                retainOriginalGroupSelectionObservation("unique_enabled_selector", expectedName: name,
                    selectors: selectors, targets: [],
                    window: elements.first(where: { $0.elementType == .window }),
                    snapshotSeconds: snapshotSeconds)
                XCTFail("Require the unique enabled original segmented group selector")
                return
            }
            let targets = GroupStressSnapshot.descendants(of: selectorSnapshot).filter {
                $0.elementType == .button && $0.label == name
            }
            guard targets.count == 1, let target = targets.first,
                  let windowSnapshot = elements.first(where: { $0.elementType == .window }),
                  target.isEnabled,
                  [selectorSnapshot.frame, target.frame, windowSnapshot.frame].allSatisfy({ GroupStressSnapshot.finitePositive($0) }),
                  target.frame.midX.isFinite, target.frame.midY.isFinite,
                  selectorSnapshot.frame.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)),
                  windowSnapshot.frame.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)),
                  windowSnapshot.frame.contains(target.frame) else {
                retainOriginalGroupSelectionObservation("exact_snapshot_geometry", expectedName: name,
                    selectors: selectors, targets: targets,
                    window: elements.first(where: { $0.elementType == .window }),
                    snapshotSeconds: snapshotSeconds)
                XCTFail("Require the enabled original group button wholly inside the actual window and its requested midpoint inside the original selector")
                return
            }
            let selector = app.segmentedControls["study-group-selector"]
            let liveTarget = selector.buttons.matching(NSPredicate(format: "label == %@", name)).element
            let window = app.windows.firstMatch
            var live: [String: Any] = [:]
            var queryStart = ProcessInfo.processInfo.systemUptime
            let liveHittable = liveTarget.isHittable
            live["hittable"] = liveHittable
            live["hittableSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
            var targetCurrent = false
            var windowCurrent = false
            // Preserve the original short-circuit order and record each actual
            // queried value once; never replace it with a later failure snapshot.
            if liveHittable {
                queryStart = ProcessInfo.processInfo.systemUptime
                let frame = liveTarget.frame
                live["targetFrame"] = NativeGeometryEvidence.frame(frame)
                live["targetFrameSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
                targetCurrent = frame == target.frame
                if targetCurrent {
                    queryStart = ProcessInfo.processInfo.systemUptime
                    let frame = window.frame
                    live["windowFrame"] = NativeGeometryEvidence.frame(frame)
                    live["windowFrameSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
                    windowCurrent = frame == windowSnapshot.frame
                }
            }
            live["targetCurrent"] = targetCurrent
            live["windowCurrent"] = windowCurrent
            guard liveHittable, targetCurrent, windowCurrent else {
                retainOriginalGroupSelectionObservation("current_live_target", expectedName: name,
                    selectors: selectors, targets: targets, window: windowSnapshot,
                    snapshotSeconds: snapshotSeconds, live: live)
                XCTFail("The original group button and window must remain live and match the fresh snapshot")
                return
            }
            // Preserve the raw full-parent containment result, even when an
            // AX edge differs by one representable Double. This is interaction
            // evidence; it does not assert whole-control visual containment.
            retainOriginalGroupSelectionObservation("validated_original_midpoint",
                expectedName: name, selectors: selectors, targets: targets,
                window: windowSnapshot, snapshotSeconds: snapshotSeconds, live: live,
                attachmentName: "groups100-original-selection-observation")
            // A real XCTest tap at the same validated button midpoint, relative
            // to its original window. Preserve ordinary XCTest idle handling.
            window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: target.frame.midX - windowSnapshot.frame.minX,
                                     dy: target.frame.midY - windowSnapshot.frame.minY)).tap()
        } else {
            let menu = app.buttons["study-group-selector"]
            XCTAssertTrue(menu.exists && menu.isEnabled)
            tap(menu)
            let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label == %@", name))
            XCTAssertTrue(options.firstMatch.exists || options.firstMatch.waitForExistence(timeout: 15))
            XCTAssertEqual(options.count, 1, "Only the exact original native group action may be selected")
            tap(options.element(boundBy: 0))
        }
    }

    @MainActor
    private func waitForOriginalGroup(named name: String, at url: URL,
                                      sceneID: String?, afterRevision: UInt64?) throws -> GroupStressWorkspace {
        // The predicate captures an explicitly actor-isolated observer, not a
        // local function that implicitly transfers XCTestCase/self in Swift 6.
        let observation = GroupStressNativeObservation(application: app, url: url, name: name,
                                                       sceneID: sceneID, afterRevision: afterRevision)
        if let workspace = observation.read() { return workspace }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { observation.read() != nil }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "Require the same original scene, committed sidecar, enabled selected group, and selected original document card")
        return try XCTUnwrap(observation.read())
    }

    private func assertOriginalGroupMembership(_ workspace: GroupStressWorkspace,
                                               matches baseline: GroupStressWorkspace) throws {
        XCTAssertEqual(workspace.profiles, baseline.profiles)
        XCTAssertEqual(workspace.groups, baseline.groups,
                       "Group order, UUID membership, active documents, canonical locators and search state must remain unchanged")
        let current = try XCTUnwrap(workspace.current)
        for group in baseline.groups {
            let document = try XCTUnwrap(group.tabs.first)
            XCTAssertEqual(current.scene.activeTabIDsByGroup?[group.id], document.session.id,
                           "The original scene must retain each group's independent document owner")
        }
    }
}

// BEGIN ADDITIVE FULL-V32 ORIGINAL READER OBSERVATIONS
import Darwin
import notify

// This Debug/production-corpus diagnostic is distinct from the existing Release
// case and the immutable miniTest10 Native116 catalog.
private struct FullV32ReaderTarget: Decodable {
    let key: String
    let bookID: Int
    let bookTitle: String
    let focusLineIndex: Int
    let unitID: String
    let unitMode: String
    let unitStartLineIndex: Int
    let unitEndLineIndex: Int
    let unitRowCount: Int
    let sourceUTF16Length: Int
    let sourceSHA256: String
    let sectionLocator: String
    let focusLocator: String
}
private struct FullV32ReaderCatalog: Decodable {
    let schema: Int
    let databaseSHA256: String
    let targets: [FullV32ReaderTarget]
}
private struct FullV32ObservationFailure: Error {}
@MainActor
private struct FullV32ProductionContext {
    let container: URL
    let workspace: URL
    let groupID: UUID
    let documentID: UUID
    let viewportBasename: String
    var interactionEvidence: [String: Any]? = nil
    var documents: URL { container.appendingPathComponent("Documents") }
    var readerLog: URL { documents.appendingPathComponent("OtzariaLogs/otzaria-reader.log") }
    var inspectorBasename: String { viewportBasename.replacingOccurrences(of: "full-v32-reader-", with: "full-v32-inspector-") }
}
extension FaithfulProductionReleaseTests {

    @MainActor private func fullV32BoundedData(_ url: URL, limit: Int) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        if descriptor < 0 { throw FullV32ObservationFailure() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat()
        guard fstat(descriptor, &before) == 0, before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              before.st_size > 0, before.st_size <= limit,
              let bytes = try handle.read(upToCount: limit + 1), bytes.count > 0, bytes.count <= limit
        else { throw FullV32ObservationFailure() }
        var after = stat()
        var atPath = stat()
        guard fstat(descriptor, &after) == 0, lstat(url.path, &atPath) == 0,
              atPath.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              after.st_dev == atPath.st_dev, after.st_ino == atPath.st_ino,
              before.st_size == after.st_size, after.st_size == atPath.st_size,
              after.st_size == bytes.count,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              after.st_mtimespec.tv_sec == atPath.st_mtimespec.tv_sec,
              after.st_mtimespec.tv_nsec == atPath.st_mtimespec.tv_nsec
        else { throw FullV32ObservationFailure() }
        return bytes
    }
    @MainActor private func fullV32Require(_ condition: Bool, _ message: String,
                                           file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(condition, message, file: file, line: line)
        if !condition { throw FullV32ObservationFailure() }
    }

    @MainActor private func fullV32Attach(_ value: [String: Any], _ name: String) throws {
        let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor private func fullV32Catalog() throws -> FullV32ReaderCatalog {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["FULL_V32_CATALOG_FILE"])
        let bytes = try fullV32BoundedData(URL(fileURLWithPath: path), limit: 131072)
        try fullV32Require(bytes.count <= 131072, "The independently generated target catalog must be bounded")
        let catalog = try JSONDecoder().decode(FullV32ReaderCatalog.self, from: bytes)
        try fullV32Require(catalog.schema == 1 && catalog.targets.count == 10
            && Set(catalog.targets.map(\.key)).count == 10
            && catalog.databaseSHA256 == "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765",
            "Require the ten actual original full-v32 identities, never a mini database")
        return catalog
    }

    @MainActor private func fullV32Launch(_ basename: String) {
        // Ordinary production defaults and sidecar. No namespace, scenario,
        // bootstrap bypass, feature override or forced line mode.
        launchWithTier(.production, backend: "otzaria", extraEnvironment: [
            "CHAVRUSA_READER_VIEWPORT_REPORT": basename,
            "CHAVRUSA_FULL_V32_SOURCE_OBSERVATION": "1",
            "CHAVRUSA_FULL_V32_INSPECTOR_OBSERVATION": basename.replacingOccurrences(of: "full-v32-reader-", with: "full-v32-inspector-")
        ])
    }

    @MainActor private func fullV32Locate(_ basename: String, interactionEpoch: String? = nil,
                                         resourceContext: FullV32ProductionContext? = nil) throws -> FullV32ProductionContext {
        let observationStarted = ProcessInfo.processInfo.systemUptime
        try fullV32Require((interactionEpoch == nil) == (resourceContext == nil),
                           "The existing overview interaction must have either a complete resource owner or none")
        var interaction: [String: Any]?
        // Observe a genuine overview-card UUID after XCTest's installation.
        // The pre-install path is a parent-directory hint, never the identity.
        try fullV32Require(app.staticTexts["reader-header-title"].waitForExistence(timeout: 30)
            && app.staticTexts["reader-current-locator"].waitForExistence(timeout: 30),
            "The actual restored Reader identity must become available")
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        try fullV32Require(!title.isEmpty && !locator.isEmpty, "Original Reader identity must exist")
        let actionRequested = ProcessInfo.processInfo.systemUptime
        tap(app.buttons["reader-tabs-overview"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        try fullV32Require(overview.waitForExistence(timeout: 15), "Original overview must appear")
        let cards = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "tab-switcher-", title + ", "))
        try fullV32Require(cards.firstMatch.waitForExistence(timeout: 15) && cards.count == 1,
                           "Actual selected original book card must be unique")
        let card = cards.firstMatch
        try fullV32Require(!card.frame.isEmpty && card.frame.intersects(overview.frame),
                           "Original document card must be genuinely visible")
        let prefix = card.identifier.hasPrefix("tab-switcher-grid-cell-")
            ? "tab-switcher-grid-cell-" : "tab-switcher-list-cell-"
        let documentID = try XCTUnwrap(UUID(uuidString: String(card.identifier.dropFirst(prefix.count))))
        let contentObserved = ProcessInfo.processInfo.systemUptime
        if let interactionEpoch, let resourceContext {
            let resources = try fullV32Host("end", context: resourceContext, fields: ["epoch": interactionEpoch])
            interaction = [
                "epoch": interactionEpoch, "observationStartedUptime": observationStarted,
                "nativeActionRequestedUptime": actionRequested, "originalOverviewObservedUptime": contentObserved,
                "requestToOriginalOverviewUpperBoundSeconds": contentObserved - observationStarted,
                "nativeActionToOverviewUpperBoundSeconds": contentObserved - actionRequested,
                "actualOverviewIdentifier": overview.identifier, "actualCardIdentifier": card.identifier,
                "actualDocumentID": documentID.uuidString, "resources": resources,
                "scope": "existing original post-open overview interaction; native action/query latency included; not general UI responsiveness"
            ]
        }
        // Resource accounting ends before dismissal, sidecar lookup, source
        // inspection or any full-content/identity comparison.
        tap(overview.buttons["סיום"])
        try fullV32Require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: overview
        )], timeout: 15) == .completed, "The original overview must dismiss")
        try fullV32Require(app.staticTexts["reader-header-title"].label == title
            && app.staticTexts["reader-current-locator"].label == locator,
            "Observation must not navigate the original Reader")
        let hint = try XCTUnwrap(ProcessInfo.processInfo.environment["FAITHFUL_PRODUCTION_WORKSPACE_FILE"])
        var containers = URL(fileURLWithPath: hint)
        for _ in 0..<6 { containers.deleteLastPathComponent() }
        let parent = containers
        let located = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Self.productionWorkspaces(in: parent, containing: documentID).count == 1
        }, object: nil)
        try fullV32Require(XCTWaiter.wait(for: [located], timeout: 30) == .completed,
                           "Resolve only the actual ordinary workspace containing the observed document UUID")
        let matches = Self.productionWorkspaces(in: parent, containing: documentID)
        try fullV32Require(matches.count == 1, "No stale or arbitrary container is eligible")
        let match = try XCTUnwrap(matches.first)
        var container = match.url
        // workspace-v1.json → StudyWorkspace → ChavrusaText → Application
        // Support → Library → actual application container (five parents).
        for _ in 0..<5 { container.deleteLastPathComponent() }
        return FullV32ProductionContext(container: container, workspace: match.url,
            groupID: match.groupID, documentID: documentID, viewportBasename: basename,
            interactionEvidence: interaction)
    }

    @MainActor private func fullV32Host(_ action: String, context: FullV32ProductionContext,
                                       fields: [String: Any] = [:]) throws -> [String: Any] {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["FULL_V32_OBSERVER_TOKEN"])
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_URL_UDID"])
        let nonce = UUID().uuidString
        let prefix = context.documents.appendingPathComponent("full-v32-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json")
        let ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        var payload = fields
        payload.merge(["schema": 1, "token": token, "nonce": nonce, "udid": udid, "action": action]) { _, new in new }
        do {
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            try fullV32Require(bytes.count <= 262144, "Observation IPC must remain bounded")
            try bytes.write(to: request, options: .atomic)
        } catch {
            XCTFail("Could not write the owned observation request")
            throw FullV32ObservationFailure()
        }
        let delivered = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: ack.path)
        }, object: nil)], timeout: 30)
        try fullV32Require(delivered == .completed, "Owned observation transport must acknowledge the exact request")
        let bytes = try fullV32BoundedData(ack, limit: 262144)
        try fullV32Require(bytes.count <= 262144
            && String(decoding: bytes, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil,
            "Observation response must be bounded and credential-free")
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        try fullV32Require(result["schema"] as? Int == 1 && result["nonce"] as? String == nonce
            && result["udid"] as? String == udid && result["action"] as? String == action
            && result["ok"] as? Bool == true, "Actual observation failed; retain the host's original receipt")
        return result
    }

    @MainActor private func fullV32ReceiptLines(_ context: FullV32ProductionContext) throws -> [String] {
        guard FileManager.default.fileExists(atPath: context.readerLog.path) else { return [] }
        let data = try fullV32BoundedData(context.readerLog, limit: 33554432)
        try fullV32Require(data.count <= 33554432, "Bound the ordinary native log without truncating receipt history")
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
            .filter { $0.contains("[NativeNavigationReceipt]") && $0.contains("destination=native.reader ") }
    }

    @MainActor private func fullV32ConfirmSystemDialog(_ springboard: XCUIApplication) throws {
        let titles: Set<String> = ["Open in \u{201C}ChavrusaText\u{201D}?", "Open in \"ChavrusaText\"?"]
        let alerts = springboard.alerts.allElementsBoundByIndex
        try fullV32Require(alerts.count == 1, "Exactly one genuine SpringBoard confirmation is required")
        let alert = try XCTUnwrap(alerts.first)
        try fullV32Require(titles.contains(alert.label) || titles.contains(where: { alert.staticTexts[$0].exists }),
                           "Unexpected SpringBoard prompt must never be approved")
        let buttons = alert.buttons.matching(NSPredicate(format: "label == %@", "Open"))
        try fullV32Require(buttons.count == 1 && buttons.firstMatch.isHittable,
                           "Require the exact original unique hittable Open action")
        buttons.firstMatch.tap()
        try fullV32Require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 0"), object: springboard.alerts
        )], timeout: 10) == .completed, "Actual SpringBoard confirmation must dismiss")
    }

    @MainActor private func fullV32Open(_ target: FullV32ReaderTarget, context: FullV32ProductionContext,
                                       deadline: TimeInterval, sectionOnly: Bool = false) throws -> [String: Any] {
        let prior = try fullV32ReceiptLines(context)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        try fullV32Require(springboard.alerts.count == 0, "No preexisting SpringBoard prompt may be accepted")
        let ref: (Int) -> [String: Any] = { index in
            ["backend": "otzaria", "workKey": "book:\(target.bookID)",
             "position": ["kind": "legacyLine", "value": index]]
        }
        // Public v2 deliberately imports NO local request, scene or document ID.
        // The one freshly issued actual Core receipt is bound after completion.
        var content: [String: Any] = [
            "sectionLocator": ref(target.unitStartLineIndex), "presentationMode": "sameTab"
        ]
        if !sectionOnly { content["focusLocator"] = ref(target.focusLineIndex) }
        let route: [String: Any] = [
            "version": 2, "destination": "native.reader", "backend": "otzaria",
            "presentation": "currentTab", "content": content
        ]
        let routeBytes = try JSONSerialization.data(withJSONObject: route, options: [.sortedKeys])
        let encoded = routeBytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let url = "maktabah-debug://action/v2/native.reader?route=" + encoded
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_URL_TOKEN"])
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_URL_UDID"])
        let nonce = UUID().uuidString
        let prefix = context.documents.appendingPathComponent("r27-url-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json")
        let ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        let payload = ["token": token, "nonce": nonce, "udid": udid, "url": url]
        let requestBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        // This upper bound includes real system transport and native receipt
        // polling. It is not exact first pixel or a production latency budget.
        let started = ProcessInfo.processInfo.systemUptime
        do { try requestBytes.write(to: request, options: .atomic) }
        catch { XCTFail("Could not write the original owned system URL request"); throw FullV32ObservationFailure() }
        let delivery = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: ack.path)
        }, object: nil)], timeout: 20)
        try fullV32Require(delivery == .completed, "Original system URL transport did not acknowledge")
        let ackBytes = try fullV32BoundedData(ack, limit: 262144)
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: ackBytes) as? [String: Any])
        try fullV32Require(Set(response.keys) == ["udid", "transport", "delivered", "nonce", "time"]
            && response["nonce"] as? String == nonce && response["udid"] as? String == udid
            && response["transport"] as? String == "simctl-system-openurl"
            && response["delivered"] as? Bool == true
            && (response["time"] as? Double)?.isFinite == true
            && String(decoding: ackBytes, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil,
            "System URL ACK proves transport only and must have the exact credential-free identity")
        var newest: String?
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run {
                do {
                    let actual = try self.fullV32ReceiptLines(context)
                    guard actual.count >= prior.count, Array(actual.prefix(prior.count)) == prior else { return false }
                    if actual.count == prior.count + 1 { newest = actual.last; return true }
                    if actual.count > prior.count + 1 { return false }
                    if springboard.alerts.count > 0 { try self.fullV32ConfirmSystemDialog(springboard) }
                    return false
                } catch { return false }
            }
        }, object: nil)
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        try fullV32Require(remaining > 0 && XCTWaiter.wait(for: [complete], timeout: remaining) == .completed,
                           "The actual Core/glyph-visible receipt must complete within the original case deadline")
        let observed = ProcessInfo.processInfo.systemUptime
        let line = try XCTUnwrap(newest)
        let parts = line.split(separator: " ", maxSplits: 2)
        try fullV32Require(parts.count == 3, "Actual native receipt format changed")
        var fields: [String: String] = [:]
        for item in parts[2].split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            try fullV32Require(pair.count == 2 && fields[String(pair[0])] == nil, "Native receipt fields must be unique")
            fields[String(pair[0])] = String(pair[1])
        }
        try fullV32Require(Set(fields.keys) == ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"]
            && fields["request"].flatMap(UUID.init(uuidString:)) != nil
            && fields["scene"]?.isEmpty == false && fields["backend"] == "otzaria"
            && fields["generation"].flatMap(UInt64.init) != nil && fields["epoch"] == "none"
            && fields["destination"] == "native.reader" && fields["presentation"] == "currentTab",
            "Require the authentic original Core reader/glyph/scene receipt")
        let revisions = (fields["revision"] ?? "").components(separatedBy: "->")
        try fullV32Require(revisions.count == 2 && UInt64(revisions[0]) != nil && UInt64(revisions[1]) != nil
            && UInt64(revisions[1])! > UInt64(revisions[0])!, "Native receipt must advance the actual revision")
        return ["transport": response, "nativeReceipt": line, "receiptFields": fields,
                "targetKey": target.key, "sectionLocator": target.sectionLocator,
                "focusLocator": sectionOnly ? NSNull() : target.focusLocator as Any, "sectionOnly": sectionOnly,
                "requestWrittenUptime": started, "nativeReceiptObservedUptime": observed,
                "requestToNativeVisibleUpperBoundSeconds": observed - started,
                "timingScope": "test monotonic request write to observed original Core glyph-visible receipt; transport/polling included; not exact first pixel"]
    }

    @MainActor private func fullV32PostSample(_ target: FullV32ReaderTarget, context: FullV32ProductionContext,
                                             epoch: String?, receipt: [String: Any]?,
                                             resourceEndAcknowledgedUptime: TimeInterval? = nil) throws -> [String: Any] {
        // The host enforces no active CPU/RSS epoch before accepting this request.
        _ = try fullV32Host("require_idle", context: context)
        let requestID = UUID().uuidString
        let prefix = context.documents.appendingPathComponent(context.viewportBasename)
        let reportURL = URL(fileURLWithPath: prefix.path + ".viewport.json")
        let requestedUptime = ProcessInfo.processInfo.systemUptime
        if let resourceEndAcknowledgedUptime {
            try fullV32Require(requestedUptime >= resourceEndAcknowledgedUptime,
                               "Native source/report work must begin after the resource end acknowledgement")
        }
        try requestID.write(to: URL(fileURLWithPath: prefix.path + ".request"), atomically: true, encoding: .utf8)
        var report: [String: Any]?
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run {
                guard let bytes = try? self.fullV32BoundedData(reportURL, limit: 32768), bytes.count <= 32768,
                      let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                      value["requestID"] as? String == requestID else { return false }
                report = value; return true
            }
        }, object: nil)
        try fullV32Require(XCTWaiter.wait(for: [observed], timeout: 15) == .completed,
                           "A fresh original native source/viewport observation is required")
        let observedUptime = ProcessInfo.processInfo.systemUptime
        let value = try XCTUnwrap(report)
        let sample = try XCTUnwrap(value["fullV32SourceObservation"] as? [String: Any])
        try fullV32Require(sample["status"] as? String == "AVAILABLE",
                           "Unavailable or over-cap source evidence must not silently pass")
        try fullV32Require(app.staticTexts["reader-header-title"].label == target.bookTitle
            && app.staticTexts["reader-current-locator"].label == target.sectionLocator,
            "Actual Reader title and canonical section must match the original full-v32 catalog")
        let workspace = try XCTUnwrap(JSONSerialization.jsonObject(with: fullV32BoundedData(context.workspace, limit: 4194304)) as? [String: Any])
        let scenes = try XCTUnwrap(workspace["scenes"] as? [String: Any])
        if let receipt, let fields = receipt["receiptFields"] as? [String: String] {
            try fullV32Require(scenes[fields["scene"] ?? ""] != nil, "Receipt must belong to the actual ordinary production scene")
        }
        var proof: [String: Any] = ["targetKey": target.key, "viewport": value,
            "viewportBasename": context.viewportBasename,
            "sourceProbeRequestedUptime": requestedUptime, "sourceProbeObservedUptime": observedUptime,
            "workspaceDocumentID": context.documentID.uuidString, "workspaceGroupID": context.groupID.uuidString]
        if let resourceEndAcknowledgedUptime { proof["resourceEndAcknowledgedUptime"] = resourceEndAcknowledgedUptime }
        if let epoch { proof["epoch"] = epoch }
        if let receipt { proof["routeEvidence"] = receipt }
        let checked = try fullV32Host("validate_source", context: context, fields: proof)
        proof["independentSourceComparison"] = checked
        try fullV32Attach(proof, "full-v32-source-" + target.key + "-" + (epoch ?? requestID))
        return proof
    }

    @MainActor
    func testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch() throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 600
        let catalog = try fullV32Catalog()
        let basename = "full-v32-reader-" + UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        fullV32Launch(basename)
        dismissAlertsIfNeeded()
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        openProductionBook(named: catalog.targets[0].bookTitle, isFirstDocument: true)
        tap(app.buttons["reader-more-menu"])
        tap(app.buttons["Display by"])
        tap(app.buttons["Chapter"])
        var context = try fullV32Locate(basename)
        var previousPID: Int?
        var observations: [[String: Any]] = []
        var forcedRestores: [[String: Any]] = []
        for target in catalog.targets {
            let away = try XCTUnwrap(catalog.targets.first { $0.bookID != target.bookID })
            _ = try fullV32Open(away, context: context, deadline: deadline)
            context = try fullV32Locate(basename)
            let beforeCold = try fullV32Host("process", context: context)
            app.terminate()
            try fullV32Require(app.wait(for: .notRunning, timeout: 30), "Process-cold requires a genuine terminated app")
            fullV32Launch(basename)
            context = try fullV32Locate(basename)
            let coldProcess = try fullV32Host("process", context: context)
            let coldPID = try XCTUnwrap(coldProcess["processID"] as? Int)
            try fullV32Require(coldPID != beforeCold["processID"] as? Int && coldPID != previousPID,
                               "Process-cold must have an actually new native PID; OS/disk caches are not claimed cold")
            for mode in ["process-cold", "warm"] {
                if mode == "warm" {
                    _ = try fullV32Open(away, context: context, deadline: deadline)
                    context = try fullV32Locate(basename)
                    try fullV32Require(app.staticTexts["reader-current-locator"].label != target.sectionLocator,
                                       "Warm observation must navigate away before the real return request")
                }
                let epoch = UUID().uuidString
                let started = try fullV32Host("begin", context: context,
                    fields: ["epoch": epoch, "targetKey": target.key, "mode": mode, "kind": "reader-open"])
                try fullV32Require(started["processID"] as? Int == coldPID,
                                   "Both observations must target the actual same new application PID")
                let route = try fullV32Open(target, context: context, deadline: deadline)
                let ended = try fullV32Host("end", context: context, fields: ["epoch": epoch])
                let resourceEndAcknowledgedUptime = ProcessInfo.processInfo.systemUptime
                try fullV32Require(ended["processID"] as? Int == coldPID, "A measured warm route cannot restart the application")
                let interactionEpoch = UUID().uuidString
                _ = try fullV32Host("begin", context: context,
                    fields: ["epoch": interactionEpoch, "targetKey": target.key, "mode": mode, "kind": "reader-overview"])
                context = try fullV32Locate(basename, interactionEpoch: interactionEpoch, resourceContext: context)
                let interaction = try XCTUnwrap(context.interactionEvidence)
                let sample = try fullV32PostSample(target, context: context, epoch: epoch, receipt: route,
                    resourceEndAcknowledgedUptime: resourceEndAcknowledgedUptime)
                let row: [String: Any] = ["epoch": epoch, "targetKey": target.key, "mode": mode,
                    "processID": coldPID, "route": route, "resources": ended,
                    "firstInteraction": interaction, "postTimingSource": sample]
                observations.append(row)
                try fullV32Attach(row, "full-v32-open-" + target.key + "-" + mode)
            }
            let before = try fullV32PostSample(target, context: context, epoch: nil, receipt: nil)
            let savedDocument = context.documentID, savedGroup = context.groupID
            app.terminate()
            try fullV32Require(app.wait(for: .notRunning, timeout: 30), "Forced relaunch must actually terminate the original process")
            fullV32Launch(basename)
            let restored = try fullV32Locate(basename)
            try fullV32Require(restored.documentID == savedDocument && restored.groupID == savedGroup,
                               "Forced relaunch must restore the same genuine ordinary document/group identity")
            let after = try fullV32PostSample(target, context: restored, epoch: nil, receipt: nil)
            let beforeView = try XCTUnwrap(before["viewport"] as? [String: Any])
            let afterView = try XCTUnwrap(after["viewport"] as? [String: Any])
            XCTAssertEqual(afterView["source"] as? Int, beforeView["source"] as? Int,
                           "Forced relaunch must preserve the actual first visible source anchor")
            XCTAssertEqual(try XCTUnwrap(afterView["offset"] as? Double),
                           try XCTUnwrap(beforeView["offset"] as? Double), accuracy: 1,
                           "Use the existing original Reader pixel-anchor preservation contract")
            let restoredProcess = try fullV32Host("process", context: restored)
            try fullV32Require(restoredProcess["processID"] as? Int != coldPID,
                               "Cold restore must be observed in a different actual application process")
            let restoreEvidence: [String: Any] = [
                "targetKey": target.key, "beforeProcessID": coldPID,
                "afterProcessID": try XCTUnwrap(restoredProcess["processID"] as? Int),
                "documentID": savedDocument.uuidString, "groupID": savedGroup.uuidString,
                "beforeRequestID": try XCTUnwrap(beforeView["requestID"] as? String),
                "afterRequestID": try XCTUnwrap(afterView["requestID"] as? String),
                "beforeSource": try XCTUnwrap(beforeView["source"] as? Int),
                "afterSource": try XCTUnwrap(afterView["source"] as? Int),
                "beforeOffset": try XCTUnwrap(beforeView["offset"] as? Double),
                "afterOffset": try XCTUnwrap(afterView["offset"] as? Double)
            ]
            forcedRestores.append(restoreEvidence)
            try fullV32Attach(restoreEvidence, "full-v32-forced-restore-" + target.key)
            previousPID = restoredProcess["processID"] as? Int
            context = restored
        }
        try fullV32Require(observations.count == 20
            && observations.filter { $0["mode"] as? String == "process-cold" }.count == 10
            && observations.filter { $0["mode"] as? String == "warm" }.count == 10,
            "Exactly twenty original opens must complete; no discarded failures")
        // Detailed original rows are already retained in their attachments and
        // source-proof records. Completion sends immutable IDs/measurements,
        // avoiding a second transfer of twenty bounded native source reports.
        let completionRows: [[String: Any]] = try observations.map { row in
            let sample = try XCTUnwrap(row["postTimingSource"] as? [String: Any])
            let viewport = try XCTUnwrap(sample["viewport"] as? [String: Any])
            return [
                "epoch": try XCTUnwrap(row["epoch"] as? String),
                "targetKey": try XCTUnwrap(row["targetKey"] as? String),
                "mode": try XCTUnwrap(row["mode"] as? String),
                "processID": try XCTUnwrap(row["processID"] as? Int),
                "route": try XCTUnwrap(row["route"] as? [String: Any]),
                "firstInteraction": try XCTUnwrap(row["firstInteraction"] as? [String: Any]),
                "sourceObservationID": try XCTUnwrap(viewport["requestID"] as? String)
            ]
        }
        _ = try fullV32Host("complete_reader", context: context,
            fields: ["observations": completionRows, "forcedRelaunches": 10, "forcedRestoreEvidence": forcedRestores])
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "full-v32-original-reader-final"; image.lifetime = .keepAlways; add(image)
    }

    @MainActor private func fullV32Rect(_ frame: CGRect) throws -> [String: Double] {
        try fullV32Require(!frame.isNull && !frame.isInfinite && !frame.isEmpty
            && [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
            "Require the finite actual original native rectangle without rounding or inset tolerance")
        return ["x": Double(frame.minX), "y": Double(frame.minY),
                "width": Double(frame.width), "height": Double(frame.height)]
    }

    @MainActor private func fullV32InspectorPanel() throws -> XCUIElement {
        let query = app.descendants(matching: .any).matching(identifier: "torah-inspector-panel")
        try fullV32Require(query.firstMatch.waitForExistence(timeout: 30) && query.count == 1,
                           "The actual original Inspector panel must exist uniquely")
        return query.firstMatch
    }

    @MainActor private func fullV32InspectorTool(_ tool: String, panel: XCUIElement) throws {
        let labels = tool == "commentaries" ? ["Commentaries", "מפרשים"] : ["Links", "קישורים"]
        let selector = panel.descendants(matching: .any)["torah-inspector-tools"]
        try fullV32Require(selector.waitForExistence(timeout: 15), "Require the original Inspector tool selector")
        let matches = selector.buttons.matching(NSPredicate(format: "label IN %@", labels))
        try fullV32Require(matches.count == 1 && matches.firstMatch.isHittable,
                           "Require the unique genuine original relationship tool action")
        if !matches.firstMatch.isSelected { tap(matches.firstMatch) }
        try fullV32Require(matches.firstMatch.isSelected, "The actual original relationship tool must be selected")
    }

    @MainActor private func fullV32WaitForInspectorContent(_ panel: XCUIElement, deadline: TimeInterval) throws {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run {
                guard panel.exists else { return false }
                let row = panel.buttons.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "torah-inspector-source-")).firstMatch
                let group = panel.descendants(matching: .any).matching(NSPredicate(
                    format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                    "torah-inspector-commentary-group-", "torah-inspector-quoting-commentary-group-")).firstMatch
                let empty = panel.staticTexts.matching(NSPredicate(format: "label IN %@", ["No results", "אין תוצאות"])).firstMatch
                return row.exists || group.exists || empty.exists
            }
        }, object: nil)
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        try fullV32Require(remaining > 0 && XCTWaiter.wait(for: [ready], timeout: remaining) == .completed,
                           "Original relationship content or genuine empty state must appear within the original case deadline")
    }

    @MainActor private func fullV32InspectorRows(_ panel: XCUIElement) throws -> [[String: Any]] {
        // This is post-resource observation. Never snapshot the Reader's full
        // AX text body, and never enumerate every row as a latency surrogate.
        let rows = panel.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "torah-inspector-source-"))
        let count = rows.count
        var observed: [[String: Any]] = []
        let window = app.windows.firstMatch.frame
        let panelFrame = panel.frame
        for index in 0..<min(count, 12) {
            let row = rows.element(boundBy: index)
            guard row.isHittable else { continue }
            let snapshot = try row.snapshot()
            let identifier = snapshot.identifier
            guard identifier.hasPrefix("torah-inspector-source-"),
                  !identifier.hasPrefix("torah-inspector-source-expanded-"),
                  snapshot.elementType == .button,
                  !snapshot.frame.isEmpty && panelFrame.contains(snapshot.frame)
                    && window.contains(snapshot.frame),
                  panel.buttons.matching(identifier: identifier).count == 1 else { continue }
            let id = String(identifier.dropFirst("torah-inspector-source-".count))
            try fullV32Require(!id.isEmpty && id.utf8.count <= 4096 && snapshot.label.utf8.count <= 8192,
                               "Actual native row metadata must fit the evidence bound")
            observed.append([
                "id": id, "identifier": identifier, "elementType": "button", "label": snapshot.label,
                "value": snapshot.value as? String ?? "", "hittable": true,
                "frame": try fullV32Rect(snapshot.frame), "panelFrame": try fullV32Rect(panelFrame),
                "windowFrame": try fullV32Rect(window)
            ])
            if observed.count == 3 { break }
        }
        return observed
    }

    @MainActor private func fullV32RevealOriginalRows(_ panel: XCUIElement,
                                                      deadline: TimeInterval) throws -> (String, [[String: Any]], [String: Any]?) {
        for tool in ["commentaries", "links"] {
            try fullV32InspectorTool(tool, panel: panel)
            try fullV32WaitForInspectorContent(panel, deadline: deadline)
            if tool == "commentaries" {
                let groups = panel.descendants(matching: .any).matching(NSPredicate(
                    format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                    "torah-inspector-commentary-group-", "torah-inspector-quoting-commentary-group-"))
                if groups.firstMatch.exists {
                    let group = groups.firstMatch
                    try fullV32Require(group.isHittable, "Expand only the real original visible commentary group")
                    // Native disclosure action, not a model/cache mutation.
                    tap(group)
                    let rows = panel.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "torah-inspector-source-"))
                    try fullV32Require(rows.firstMatch.waitForExistence(timeout: 15),
                                       "The original disclosure must actually produce native source rows")
                }
            }
            let rows = try fullV32InspectorRows(panel)
            if !rows.isEmpty { return (tool, rows, nil) }
        }
        let empty = panel.staticTexts.matching(NSPredicate(format: "label IN %@", ["No results", "אין תוצאות"]))
        try fullV32Require(empty.count == 1 && empty.firstMatch.isHittable,
                           "An exploration with no source rows must retain the genuine original empty-state UI")
        let snap = try empty.firstMatch.snapshot()
        return ("links", [], [
            "label": snap.label, "frame": try fullV32Rect(snap.frame),
            "panelFrame": try fullV32Rect(panel.frame), "windowFrame": try fullV32Rect(app.windows.firstMatch.frame)
        ])
    }

    @MainActor private func fullV32ObserveInspector(
        _ target: FullV32ReaderTarget, context: FullV32ProductionContext, epoch: String,
        route: [String: Any], selectedTool: String, rows: [[String: Any]], emptyState: [String: Any]?
    ) throws -> [String: Any] {
        var fields: [String: Any] = [
            "epoch": epoch, "targetKey": target.key, "inspectorBasename": context.inspectorBasename,
            "workspaceDocumentID": context.documentID.uuidString, "workspaceGroupID": context.groupID.uuidString,
            "routeEvidence": route, "selectedTool": selectedTool,
            "actualPanelIdentifier": "torah-inspector-panel", "visibleRows": rows
        ]
        if let emptyState { fields["emptyState"] = emptyState }
        let armed = try fullV32Host("arm_inspector", context: context, fields: fields)
        let requestID = try XCTUnwrap(armed["requestID"] as? String)
        let notification = try XCTUnwrap(armed["notificationName"] as? String)
        try fullV32Require(notification == "com.davidpovarsky.chavrusatext." + context.inspectorBasename
            && armed["armedAfterResourceEpoch"] as? Bool == true,
            "Only the collector's actual post-resource owned notification is eligible")
        let responseFile = try XCTUnwrap(armed["responseFile"] as? String)
        try fullV32Require(responseFile == context.inspectorBasename + ".observation.json",
                           "Use only this current request's original native response file")
        let responseURL = context.documents.appendingPathComponent(responseFile)
        let notified = ProcessInfo.processInfo.systemUptime
        try fullV32Require(notify_post(notification) == NOTIFY_STATUS_OK,
                           "Actual Simulator Darwin notification delivery must succeed")
        var native: [String: Any]?
        let produced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NativeCaptureMainActorEntry.run {
                guard let bytes = try? self.fullV32BoundedData(responseURL, limit: 65536),
                      let result = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                      result["requestID"] as? String == requestID else { return false }
                native = result
                return true
            }
        }, object: nil)
        let completed = XCTWaiter.wait(for: [produced], timeout: 30)
        let observed = ProcessInfo.processInfo.systemUptime
        if completed != .completed {
            _ = try? fullV32Host("fail_inspector", context: context, fields: ["requestID": requestID])
        }
        try fullV32Require(completed == .completed, "The actual current native Inspector observation must answer this exact UUID")
        let report = try XCTUnwrap(native)
        let checked = try fullV32Host("validate_inspector", context: context, fields: [
            "requestID": requestID, "nativeReport": report,
            "notificationPostedUptime": notified, "responseObservedUptime": observed
        ])
        let evidence: [String: Any] = ["targetKey": target.key, "epoch": epoch, "native": report,
            "visibleRows": rows, "independentValidation": checked,
            "scope": "actual original UI rows plus full passive cache count; not full rendered-body or exact-size acceptance"]
        try fullV32Attach(evidence, "full-v32-original-inspector-" + requestID)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "full-v32-original-inspector-" + target.key + "-" + requestID
        image.lifetime = .keepAlways; add(image)
        return checked
    }

    @MainActor private func fullV32CloseOriginalInspector(_ context: FullV32ProductionContext,
                                                         target: FullV32ReaderTarget,
                                                         before: [String: Any]) throws -> FullV32ProductionContext {
        let close = app.buttons.matching(identifier: "torah-inspector-close")
        try fullV32Require(close.count == 1 && close.firstMatch.isHittable,
                           "Use the original unique visible native Inspector close action")
        tap(close.firstMatch)
        let panel = app.descendants(matching: .any)["torah-inspector-panel"]
        try fullV32Require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: panel
        )], timeout: 15) == .completed, "Original Inspector must actually close")
        let afterContext = try fullV32Locate(context.viewportBasename)
        try fullV32Require(afterContext.documentID == context.documentID && afterContext.groupID == context.groupID,
                           "Inspector interaction must preserve the actual Reader document/group")
        let after = try fullV32PostSample(target, context: afterContext, epoch: nil, receipt: nil)
        let left = try XCTUnwrap(before["viewport"] as? [String: Any])
        let right = try XCTUnwrap(after["viewport"] as? [String: Any])
        XCTAssertEqual(left["source"] as? Int, right["source"] as? Int, "Original Inspector must preserve the actual Reader source anchor")
        XCTAssertEqual(try XCTUnwrap(left["offset"] as? Double), try XCTUnwrap(right["offset"] as? Double),
                       accuracy: 1, "Keep the original Reader pixel-anchor preservation contract")
        return afterContext
    }

    @MainActor
    func testOriginalFullV32InspectorRelationshipScalesAndReturn() throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 600
        let catalog = try fullV32Catalog()
        let basename = "full-v32-reader-" + UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        fullV32Launch(basename)
        dismissAlertsIfNeeded()
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        openProductionBook(named: catalog.targets[0].bookTitle, isFirstDocument: true)
        tap(app.buttons["reader-more-menu"]); tap(app.buttons["Display by"]); tap(app.buttons["Chapter"])
        var context = try fullV32Locate(basename)
        var exploration: [[String: Any]] = []
        var observationIDs: [String] = []
        // Explore the exact first/middle/last original Berakhot, Tehillim and
        // Derashot HaRan chapters, retaining empty/over-size outcomes. The
        // 110,196-line stress chapter belongs to the Reader-open case; it is not
        // silently added as an unbounded Inspector relationship workload.
        let inspectorTargets = catalog.targets.filter { [103, 28, 3152].contains($0.bookID) }
        try fullV32Require(inspectorTargets.count == 9, "Require the original nine qualified Inspector chapter identities")
        for target in inspectorTargets {
            let route = try fullV32Open(target, context: context, deadline: deadline, sectionOnly: true)
            context = try fullV32Locate(basename)
            let before = try fullV32PostSample(target, context: context, epoch: nil, receipt: route)
            let action = try originalStudyToolsActionInWindow()
            let epoch = UUID().uuidString
            _ = try fullV32Host("begin", context: context,
                fields: ["epoch": epoch, "targetKey": target.key, "mode": "original-native", "kind": "inspector-open"])
            let began = ProcessInfo.processInfo.systemUptime
            tap(action)
            let panel = try fullV32InspectorPanel()
            try fullV32InspectorTool("commentaries", panel: panel)
            try fullV32WaitForInspectorContent(panel, deadline: deadline)
            let visible = ProcessInfo.processInfo.systemUptime
            let resources = try fullV32Host("end", context: context, fields: ["epoch": epoch])
            let (tool, rows, empty) = try fullV32RevealOriginalRows(panel, deadline: deadline)
            let actual = try fullV32ObserveInspector(target, context: context, epoch: epoch,
                route: route, selectedTool: tool, rows: rows, emptyState: empty)
            let id = try XCTUnwrap(actual["requestID"] as? String)
            observationIDs.append(id)
            exploration.append(["targetKey": target.key, "observationID": id,
                "actualCount": try XCTUnwrap(actual["fullCachedCount"] as? Int), "visibleRows": rows.count,
                "openToOriginalContentUpperBoundSeconds": visible - began, "resources": resources])
            context = try fullV32CloseOriginalInspector(context, target: target, before: before)
        }
        var scales: [[String: Any]] = []
        for required in [100, 500, 2000] {
            let eligible = exploration.filter {
                ($0["actualCount"] as? Int ?? 0) >= required && ($0["visibleRows"] as? Int ?? 0) > 0
            }.sorted {
                let a = $0["actualCount"] as? Int ?? 0, b = $1["actualCount"] as? Int ?? 0
                return a == b ? String(describing: $0["targetKey"]) < String(describing: $1["targetKey"]) : a < b
            }
            guard let chosen = eligible.first, let key = chosen["targetKey"] as? String,
                  let target = catalog.targets.first(where: { $0.key == key }) else {
                let largest = try XCTUnwrap(exploration.max {
                    ($0["actualCount"] as? Int ?? 0) < ($1["actualCount"] as? Int ?? 0)
                })
                scales.append(["requestedCount": required,
                    "actualCount": try XCTUnwrap(largest["actualCount"] as? Int),
                    "observationID": try XCTUnwrap(largest["observationID"] as? String),
                    "status": "REQUIRED_NATURAL_WORKLOAD_NOT_FOUND"])
                continue
            }
            let route = try fullV32Open(target, context: context, deadline: deadline, sectionOnly: true)
            context = try fullV32Locate(basename)
            let before = try fullV32PostSample(target, context: context, epoch: nil, receipt: route)
            let action = try originalStudyToolsActionInWindow()
            let openEpoch = UUID().uuidString
            _ = try fullV32Host("begin", context: context,
                fields: ["epoch": openEpoch, "targetKey": target.key, "mode": "original-native", "kind": "inspector-open"])
            tap(action)
            let panel = try fullV32InspectorPanel()
            try fullV32InspectorTool("commentaries", panel: panel)
            try fullV32WaitForInspectorContent(panel, deadline: deadline)
            _ = try fullV32Host("end", context: context, fields: ["epoch": openEpoch])
            let (tool, initialRows, empty) = try fullV32RevealOriginalRows(panel, deadline: deadline)
            try fullV32Require(!initialRows.isEmpty && empty == nil, "A qualified natural workload requires actual native source rows")
            let reopened = try fullV32ObserveInspector(target, context: context, epoch: openEpoch,
                route: route, selectedTool: tool, rows: initialRows, emptyState: nil)
            observationIDs.append(try XCTUnwrap(reopened["requestID"] as? String))
            let firstIdentifier = try XCTUnwrap(initialRows.first?["identifier"] as? String)
            let firstRow = panel.buttons.matching(identifier: firstIdentifier)
            try fullV32Require(firstRow.count == 1 && firstRow.firstMatch.isHittable,
                               "Expand the actual original row identified by its independently verified source")
            tap(firstRow.firstMatch)
            let sourceID = String(firstIdentifier.dropFirst("torah-inspector-source-".count))
            let expanded = panel.descendants(matching: .any)["torah-inspector-source-expanded-" + sourceID]
            try fullV32Require(expanded.waitForExistence(timeout: 15),
                               "The original source row expansion must produce its real native content marker")
            let expandedImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            expandedImage.name = "full-v32-original-expanded-source-" + key + "-" + String(required)
            expandedImage.lifetime = .keepAlways; add(expandedImage)
            try fullV32Require(firstRow.firstMatch.isHittable, "The original expanded source must remain reachable")
            tap(firstRow.firstMatch)
            try fullV32Require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: expanded
            )], timeout: 15) == .completed, "The same original source row must collapse through its real action")
            // Native scroll interaction, with actual app PID/CPU/RSS/trace
            // accounting. Row content/identity hashing follows the ACK.
            let scroll = panel.scrollViews.firstMatch
            try fullV32Require(scroll.exists && scroll.isHittable, "Use the original Inspector scroll view")
            let scrollEpoch = UUID().uuidString
            _ = try fullV32Host("begin", context: context,
                fields: ["epoch": scrollEpoch, "targetKey": target.key, "mode": "original-native", "kind": "inspector-scroll"])
            let scrollStarted = ProcessInfo.processInfo.systemUptime
            scroll.swipeUp(velocity: .slow)
            scroll.swipeDown(velocity: .slow)
            let scrollEnded = ProcessInfo.processInfo.systemUptime
            let resources = try fullV32Host("end", context: context, fields: ["epoch": scrollEpoch])
            let rows = try fullV32InspectorRows(panel)
            try fullV32Require(!rows.isEmpty, "Original native rows must remain visible and actionable after scrolling")
            let observed = try fullV32ObserveInspector(target, context: context, epoch: scrollEpoch,
                route: route, selectedTool: tool, rows: rows, emptyState: nil)
            let observationID = try XCTUnwrap(observed["requestID"] as? String)
            observationIDs.append(observationID)
            let scale: [String: Any] = [
                "requestedCount": required, "actualCount": try XCTUnwrap(observed["fullCachedCount"] as? Int),
                "observationID": observationID, "targetKey": key,
                "scrollGestureUpperBoundSeconds": scrollEnded - scrollStarted, "resources": resources,
                "expandedOriginalSourceID": sourceID,
                "scope": "natural original full-cache workload and native row/scroll witnesses; exact requested size is separately reported"
            ]
            scales.append(scale)
            try fullV32Attach(scale, "full-v32-inspector-natural-scale-" + String(required))
            context = try fullV32CloseOriginalInspector(context, target: target, before: before)
        }
        _ = try fullV32Host("complete_inspector", context: context,
            fields: ["observationIDs": observationIDs, "exploration": exploration, "scales": scales])
    }

}
// END ADDITIVE FULL-V32 ORIGINAL READER OBSERVATIONS
