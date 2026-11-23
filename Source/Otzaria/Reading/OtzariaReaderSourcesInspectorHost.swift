#if os(iOS)
import SwiftUI
import TorahInspectorCore
import TorahInspectorUI
#if DEBUG
import CryptoKit
import Darwin
import notify
import UIKit
#endif

struct OtzariaReaderSourcesInspectorHost: View {
    var viewModel: ReaderViewModel
    var navigationManager: iOSNavigationManager
    @Binding var inspectorSession: MaktabahTorahInspectorSession
    @Binding var selectedTool: TorahStudyTool
    let showsCloseButton: Bool
    let chrome: TorahInspectorChrome
    var contentID: UUID = UUID()
    let onAddNote: ((TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    var nativeSheet: NativeStudySheetContent? = nil
    @ObservedObject private var backendCoordinator = BackendCoordinator.shared

    var body: some View {
        @Bindable var viewModel = viewModel

        if viewModel.readerInspectorVisible,
           let selection = inspectorSession.selection(
                sefariaLocator: viewModel.selectedSegmentLocator,
                otzariaLine: viewModel.otzariaSelectedLineAnchor
           ) {
            presentedInspector(selection: selection)
            .id("\(backendCoordinator.generation):\(viewModel.currentReaderTextMode.rawValue):\(contentID)")
            .modifier(MaktabahNativeRoutingSurface(kind: .inspector, inspectorReader: viewModel))
            .onChange(of: backendCoordinator.generation) { _, _ in
                inspectorSession = MaktabahTorahInspectorSession(viewModel: viewModel)
                viewModel.closeReaderInspector()
            }
            .onChange(of: viewModel.currentReaderTextMode) { _, mode in
                inspectorSession = MaktabahTorahInspectorSession(
                    viewModel: viewModel,
                    preferredMode: mode
                )
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func presentedInspector(selection: TorahInspectorSelection) -> some View {
        if let nativeSheet {
            ZStack(alignment: .top) {
                // Never remove/recreate the Kit at a detent boundary. Its
                // private NavigationStack and expanded source state stay owned
                // by this exact Reader/session/contentID.
                originalInspector(selection: selection)
                    .opacity(nativeSheet.isPeek ? 0 : 1)
                    .allowsHitTesting(!nativeSheet.isPeek)
                    .accessibilityHidden(nativeSheet.isPeek)
                if nativeSheet.isPeek {
                    NativeStudySheetPeek(content: nativeSheet, selectedTool: selectedTool,
                        close: closeOriginalInspector)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            originalInspector(selection: selection)
        }
    }

    private func originalInspector(selection: TorahInspectorSelection) -> some View {
        let repository = inspectorSession.repository
        return TorahInspectorUI.TorahInspectorView(
                repository: repository,
                selection: selection,
                entryMode: .relationships,
                chrome: chrome,
                selectedTool: $selectedTool,
                presentationOptions: nativeSheet != nil
                    ? .init(showsStudyToolsTitle: false, showsSelectedSegmentTitle: false, usesMinimalChrome: true)
                    : (ChavrusaTextReaderUI.isEnabled
                        ? .init(showsStudyToolsTitle: false, showsSelectedSegmentTitle: false)
                        : .init()),
                onClose: closeOriginalInspector,
                onOpenInNewTab: { selection in
                    guard let locator = inspectorSession.locator(for: selection) else { return }
                    navigationManager.openTorahInspectorLocationInNewTab(locator)
                },
                onAddNote: onAddNote,
                onOpenNote: onOpenNote,
                onDeleteNote: onDeleteNote,
                showsCloseButton: showsCloseButton
            )
            #if DEBUG
            .background {
                if FullV32InspectorCacheObservation.enabled {
                    let session = inspectorSession
                    let reader = viewModel
                    let generation = backendCoordinator.generation
                    let source = reader.backendSection?.locator.persistenceKey
                    let segment = reader.selectedSegmentLocator?.persistenceKey
                    let lineID = reader.otzariaSelectedLineAnchor?.id
                    let textMode = reader.currentReaderTextMode
                    FullV32InspectorCacheObservation {
                        guard inspectorSession === session, viewModel === reader,
                              backendCoordinator.activeBackendID == .otzaria,
                              backendCoordinator.generation == generation,
                              reader.readerInspectorVisible,
                              reader.currentReaderTextMode == textMode,
                              reader.backendSection?.locator.persistenceKey == source,
                              reader.selectedSegmentLocator?.persistenceKey == segment,
                              reader.otzariaSelectedLineAnchor?.id == lineID,
                              let source else { return nil }
                        return FullV32InspectorObservationContext(
                            repository: repository, selection: selection, sourceLocator: source,
                            backendGeneration: String(generation),
                            readerIdentity: String(describing: ObjectIdentifier(reader)),
                            sessionIdentity: String(describing: ObjectIdentifier(session)),
                            contentID: contentID, selectedTool: String(describing: selectedTool),
                            isPeek: nativeSheet?.isPeek ?? false)
                    }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            #endif
    }

    private func closeOriginalInspector() {
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeInspector] originalClose invoked visible=\(viewModel.readerInspectorVisible)")
        #endif
        viewModel.closeReaderInspector()
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeInspector] originalClose returned visible=\(viewModel.readerInspectorVisible)")
        #endif
    }
}

#if DEBUG
/// Request-only observation of the repository already used by the mounted
/// original Inspector. cachedLinks is a pure dictionary read in pinned Kit
/// 23db0f84; this observer never calls a fetcher or changes selection/cache state.
@MainActor
private struct FullV32InspectorObservationContext {
    let repository: TorahInspectorRepository
    let selection: TorahInspectorSelection
    let sourceLocator: String
    let backendGeneration: String
    let readerIdentity: String
    let sessionIdentity: String
    let contentID: UUID
    let selectedTool: String
    let isPeek: Bool
}

@MainActor
private struct FullV32InspectorCacheObservation: UIViewRepresentable {
    let current: @MainActor () -> FullV32InspectorObservationContext?

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["CHAVRUSA_FULL_V32_SOURCE_OBSERVATION"] == "1"
            && ProcessInfo.processInfo.environment["CHAVRUSA_FULL_V32_INSPECTOR_OBSERVATION"] != nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        context.coordinator.start(view, current: current)
        return view
    }
    func updateUIView(_ view: UIView, context: Context) { context.coordinator.current = current }
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator {
        struct Request: Decodable {
            let schema: Int
            let requestID: String
            let processID: Int32
            let sourceLocator: String
            let relationshipRef: String
            let backendGeneration: String
            let afterResourceEpoch: Bool
            let visibleSourceIDs: [String]
        }
        var current: (@MainActor () -> FullV32InspectorObservationContext?)?
        private weak var view: UIView?
        private var notificationToken: Int32?
        private var prefix: URL?
        private var lastRequest: String?
        private let ownerID = UUID()

        func start(_ view: UIView, current: @escaping @MainActor () -> FullV32InspectorObservationContext?) {
            guard FullV32InspectorCacheObservation.enabled,
                  let name = ProcessInfo.processInfo.environment["CHAVRUSA_FULL_V32_INSPECTOR_OBSERVATION"],
                  name.hasPrefix("full-v32-inspector-"), name.utf8.count <= 80,
                  UUID(uuidString: String(name.dropFirst("full-v32-inspector-".count))) != nil,
                  URL(fileURLWithPath: name).lastPathComponent == name,
                  ProcessInfo.processInfo.environment["MAKTABAH_SMOKE_READY_FILE"] == nil else { return }
            self.view = view
            self.current = current
            // XCTest may reinstall into another container. The unique basename
            // is resolved inside the application's actual current Documents.
            prefix = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            // Registration does not stat/open/read a request. The original
            // mounted Inspector stays passive until the XCTest, after the
            // collector's resource-epoch ACK, posts this unique Darwin event.
            // Apple's notify_register_dispatch delivers on the specified queue.
            var token: Int32 = 0
            let notification = "com.davidpovarsky.chavrusatext." + name
            let status = notify_register_dispatch(notification, &token, DispatchQueue.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.observeIfRequested() }
            }
            guard status == NOTIFY_STATUS_OK else { stop(); return }
            notificationToken = token
        }
        func stop() {
            if let notificationToken { _ = notify_cancel(notificationToken) }
            notificationToken = nil
            current = nil; view = nil; prefix = nil
        }

        private func observeIfRequested() {
            guard let prefix, let window = view?.window,
                  window.windowScene?.activationState == .foregroundActive else { return }
            let input = URL(fileURLWithPath: prefix.path + ".request.json")
            guard let data = Self.boundedRequest(input),
                  let request = try? JSONDecoder().decode(Request.self, from: data),
                  request.schema == 1, UUID(uuidString: request.requestID) != nil,
                  request.requestID != lastRequest, request.afterResourceEpoch,
                  request.processID == ProcessInfo.processInfo.processIdentifier,
                  request.sourceLocator.utf8.count <= 512,
                  request.relationshipRef.utf8.count <= 512,
                  request.backendGeneration.utf8.count <= 32,
                  request.visibleSourceIDs.count <= 12,
                  Set(request.visibleSourceIDs).count == request.visibleSourceIDs.count,
                  request.visibleSourceIDs.allSatisfy({ $0.utf8.prefix(4097).count <= 4096 })
            else { return }
            let observedUptime = ProcessInfo.processInfo.systemUptime
            var report: [String: Any] = [
                "schema": 1, "requestID": request.requestID, "status": "UNAVAILABLE",
                "processID": ProcessInfo.processInfo.processIdentifier,
                "observedUptime": observedUptime, "ownerID": ownerID.uuidString,
                "delivery": "UUID-scoped Darwin event after collector resource-epoch ACK",
                "scope": "passive full cached membership and bounded identities after resource epochs; not row rendering or first-pixel proof"
            ]
            if let context = current?(),
               context.selection.providerID == "otzaria",
               context.selection.scope == .section,
               context.selection.preferredSegmentRef == nil,
               context.selection.relationshipRef == request.relationshipRef,
               context.sourceLocator == request.sourceLocator,
               context.backendGeneration == request.backendGeneration,
               !context.isPeek {
                report["selectionID"] = context.selection.id
                report["relationshipRef"] = context.selection.relationshipRef
                report["sourceLocator"] = context.sourceLocator
                report["backendGeneration"] = context.backendGeneration
                report["readerIdentity"] = context.readerIdentity
                report["sessionIdentity"] = context.sessionIdentity
                report["contentID"] = context.contentID.uuidString
                report["selectedTool"] = context.selectedTool
                report["isPeek"] = context.isPeek
                // Pinned TorahInspectorRepository.cachedLinks only reads
                // linksCache[normalizedKey(...)]. In particular, it does not
                // perform the LRU touch made by repository.links or cachedDocument.
                if let links = context.repository.cachedLinks(
                    for: context.selection.relationshipRef, providerID: context.selection.providerID
                ) {
                    report["fullCachedCount"] = links.count
                    if let observation = Self.membership(links, requested: Set(request.visibleSourceIDs)) {
                        report.merge(observation) { _, new in new }
                        report["status"] = "AVAILABLE"
                    } else { report["reason"] = "bounded-membership-or-visible-identity-unavailable" }
                } else { report["reason"] = "original-cache-not-populated" }
            } else { report["reason"] = "current-original-reader-session-or-section-mismatch" }
            // Re-read only current identity; the synchronous cached read/hash
            // cannot introduce an actor suspension or mutate the original state.
            if let context = current?(),
               report["readerIdentity"] as? String == context.readerIdentity,
               report["sessionIdentity"] as? String == context.sessionIdentity,
               report["contentID"] as? String == context.contentID.uuidString,
               report["selectionID"] as? String == context.selection.id,
               report["selectedTool"] as? String == context.selectedTool,
               context.sourceLocator == request.sourceLocator,
               context.selection.relationshipRef == request.relationshipRef,
               context.backendGeneration == request.backendGeneration,
               !context.isPeek {
                report["currentnessRechecked"] = true
            } else {
                report["status"] = "UNAVAILABLE"
                report["reason"] = "current-context-no-longer-matches"
            }
            guard let bytes = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
                  bytes.count <= 65536 else { return }
            do {
                try bytes.write(to: URL(fileURLWithPath: prefix.path + ".observation.json"), options: .atomic)
                lastRequest = request.requestID
            } catch {
                // Missing evidence fails the test; observation never alters UI.
            }
        }

        private static func boundedRequest(_ input: URL) -> Data? {
            // A stat followed by unbounded Data(contentsOf:) would race a
            // growing/replaced file. The descriptor is no-follow, regular,
            // capped before allocation and checked against its current path.
            let descriptor = open(input.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            guard descriptor >= 0 else { return nil }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var before = stat()
            guard fstat(descriptor, &before) == 0,
                  before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  before.st_size > 0, before.st_size <= 16384,
                  let bytes = try? handle.read(upToCount: 16385),
                  bytes.count > 0, bytes.count <= 16384 else { return nil }
            var after = stat()
            var atPath = stat()
            guard fstat(descriptor, &after) == 0, lstat(input.path, &atPath) == 0,
                  after.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  atPath.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  before.st_dev == after.st_dev, before.st_ino == after.st_ino,
                  after.st_dev == atPath.st_dev, after.st_ino == atPath.st_ino,
                  before.st_size == after.st_size, after.st_size == atPath.st_size,
                  after.st_size == bytes.count,
                  before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
                  before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
                  after.st_mtimespec.tv_sec == atPath.st_mtimespec.tv_sec,
                  after.st_mtimespec.tv_nsec == atPath.st_mtimespec.tv_nsec else { return nil }
            return bytes
        }

        private static func membership(_ links: [TorahLinkedSource], requested: Set<String>) -> [String: Any]? {
            guard links.count <= 100000 else { return nil }
            var hash = SHA256()
            var hashedBytes = 0
            func append(_ value: String) -> Bool {
                // Bound before Data/String copies. A long metadata field is
                // unavailable evidence, never a silently truncated identity.
                guard value.utf8.prefix(8193).count <= 8192 else { return false }
                let bytes = Data(value.utf8)
                guard hashedBytes <= 32 * 1024 * 1024 - bytes.count - 8 else { return false }
                var length = UInt64(bytes.count).bigEndian
                withUnsafeBytes(of: &length) { hash.update(data: Data($0)) }
                hash.update(data: bytes)
                hashedBytes += bytes.count + 8
                return true
            }
            guard append("otzaria.original-inspector-membership/1"), append(String(links.count)) else { return nil }
            let fixed = Set([0, links.count / 2, max(0, links.count - 1)])
            var samples: [[String: Any]] = []
            var found = Set<String>()
            for (ordinal, link) in links.enumerated() {
                // TorahLinkedSource.id joins these six original fields. Check
                // every input before invoking that computed identity.
                let values = [link.canonicalBookID, link.sourceRef, link.type, link.category, link.versionTitle ?? ""]
                guard link.anchorRefs.count <= 32,
                      values.allSatisfy({ $0.utf8.prefix(1025).count <= 1024 }),
                      link.anchorRefs.allSatisfy({ $0.utf8.prefix(1025).count <= 1024 }),
                      values.reduce(0, { $0 + $1.utf8.count })
                        + link.anchorRefs.reduce(0, { $0 + $1.utf8.count }) + link.anchorRefs.count + 6 <= 4096,
                      link.rawProviderPayload.utf8.prefix(1025).count <= 1024,
                      (link.sourceHebrewRef?.utf8.prefix(2049).count ?? 0) <= 2048 else { return nil }
                let identity = link.id
                guard append(String(ordinal)), append(identity), append(link.sourceRef),
                      append(link.rawProviderPayload) else { return nil }
                let wanted = requested.contains(identity)
                if wanted { found.insert(identity) }
                if fixed.contains(ordinal) || wanted {
                    guard samples.count < 15 else { return nil }
                    samples.append([
                        "ordinal": ordinal, "id": identity, "sourceRef": link.sourceRef,
                        "sourceHebrewRef": link.sourceHebrewRef as Any? ?? NSNull(),
                        "canonicalBookID": link.canonicalBookID, "category": link.category, "type": link.type,
                        "anchorRefs": link.anchorRefs, "rawProviderPayload": link.rawProviderPayload
                    ])
                }
            }
            guard found == requested, samples.count <= 15 else { return nil }
            return [
                "orderedIdentitySHA256": hash.finalize().map { String(format: "%02x", $0) }.joined(),
                "identityDigestEncoding": "SHA256 of eight-byte unsigned big-endian UTF8 byte lengths then exact UTF8; header,count,then original array ordinal,id,sourceRef,rawProviderPayload",
                "hashedBytes": hashedBytes, "identitySamples": samples,
                "requestedVisibleIdentitiesMatched": found.count,
                "readOnlyCacheMethod": "TorahInspectorRepository.cachedLinks(for:providerID:)"
            ]
        }
    }
}
#endif

#endif
