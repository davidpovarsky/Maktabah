import Foundation

// Explicit compiler/authority boundaries. These do not grant app or engine acceptance.
enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static let activeProfileID = "miniTest10"
}
enum FixtureWorld { nonisolated(unsafe) static var root = URL(fileURLWithPath: "") }
enum ITorahSharedContainer {
    static var sharedRootURL: URL { FixtureWorld.root }
    static var downloadsRootURL: URL { FixtureWorld.root.appendingPathComponent("downloads") }
}
enum OtzariaProfileStorage {
    enum Component { case zayitSearch }
    static func applicationSupportRoot(base: URL, component: Component) -> URL { base }
    static func downloadsRoot(base: URL, component: Component) -> URL { base }
}
enum ITorahStorageLock {
    static func withLock<T>(name: String, _ body: () throws -> T) rethrows -> T { try body() }
}
struct FixtureResolvedArtifact { let manifest: ZayitSearchArtifactManifest }

@main struct RunReadiness {
    @MainActor static func main() async throws {
        let arguments=CommandLine.arguments
        let owned=URL(fileURLWithPath: arguments[1],isDirectory:true)
        let originalIndex=URL(fileURLWithPath: arguments[2],isDirectory:true)
        let manifestData=try Data(contentsOf: URL(fileURLWithPath: arguments[3]))
        let original=try JSONDecoder().decode(ZayitSearchArtifactManifest.self,from:manifestData)
        var results: [[String:String]]=[]
        func record(_ name:String,_ pass:Bool) {
            print((pass ? "PASS " : "FAIL ")+name)
            results.append(["name":name,"status":pass ? "PASS" : "FAIL"])
        }
        func setup(_ name:String, installed:Bool=true) throws -> ZayitSearchArtifactStorage {
            FixtureWorld.root=owned.appendingPathComponent(name,isDirectory:true)
            let storage=try ZayitSearchArtifactStorage()
            if installed {
                try FileManager.default.createDirectory(at:storage.root,withIntermediateDirectories:true)
                try FileManager.default.copyItem(at:originalIndex,to:storage.finalIndex)
                try manifestData.write(to:storage.installedManifest)
            }
            return storage
        }
        func isRepair(_ state:ZayitSearchPackageState)->Bool {
            if case .repairRequired=state { return true };return false
        }
        func alterManifest(_ storage:ZayitSearchArtifactStorage,
                           _ body:(inout [String:Any])throws->Void) throws -> ZayitSearchArtifactManifest {
            var object=try JSONSerialization.jsonObject(with:manifestData) as! [String:Any]
            try body(&object)
            let bytes=try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
            try bytes.write(to:storage.installedManifest)
            return try JSONDecoder().decode(ZayitSearchArtifactManifest.self,from:bytes)
        }
        let database=owned.appendingPathComponent("readonly-source-not-opened-by-this-boundary")
        let absent=try setup("absent",installed:false)
        let absentState=await ZayitSearchArtifactService(original).status(databaseURL:database)
        if case .notInstalled=absentState { record("absent package is not installed",true) }
        else { record("absent package is not installed",false) }
        record("status creates no installation directories",
               !FileManager.default.fileExists(atPath:absent.root.path))
        let active=try setup("active-staging")
        try FileManager.default.createDirectory(at:active.installingIndex,withIntermediateDirectories:true)
        let marker=active.installingIndex.appendingPathComponent("owned-in-progress")
        try Data("in-progress".utf8).write(to:marker)
        _=await ZayitSearchArtifactService(original).status(databaseURL:database)
        record("status preserves in-progress staging",FileManager.default.fileExists(atPath:marker.path))
        _=try setup("valid-status")
        let valid=await ZayitSearchArtifactService(original).status(databaseURL:database)
        record("official valid package passes status",valid.isReady)
        _=try setup("valid-discovery")
        let discovered=try await ZayitSearchArtifactService(original).discover(databaseURL:database)
        record("official valid package passes discovery",discovered.isReady)
        for kind in ["corrupt-metadata","missing-index","missing-segment","truncated-segment","malformed-tantivy-meta","offset-gap","unsafe-part-path"] {
            let storage=try setup(kind)
            var manifest=original
            switch kind {
            case "corrupt-metadata":
                try Data("{}".utf8).write(to:storage.finalIndex.appendingPathComponent("zayit-index-metadata.json"))
            case "missing-index":
                try FileManager.default.moveItem(at:storage.finalIndex,to:storage.root.appendingPathComponent("owned-index-retained"))
            case "missing-segment":
                let part=original.parts.first { !["meta.json","zayit-index-metadata.json"].contains($0.destinationPath) }!
                try FileManager.default.removeItem(at:storage.finalIndex.appendingPathComponent(part.destinationPath))
            case "truncated-segment":
                let part=original.parts.first { !["meta.json","zayit-index-metadata.json"].contains($0.destinationPath) }!
                let handle=try FileHandle(forWritingTo:storage.finalIndex.appendingPathComponent(part.destinationPath))
                try handle.truncate(atOffset:1);try handle.close()
            case "malformed-tantivy-meta":
                let path=storage.finalIndex.appendingPathComponent("meta.json")
                let length=try Data(contentsOf:path).count
                try Data(repeating:0x20,count:length).write(to:path)
            case "offset-gap":
                manifest=try alterManifest(storage) { object in
                    var parts=object["parts"] as! [[String:Any]]
                    parts[0]["destinationOffset"]=1;object["parts"]=parts
                }
            default:
                manifest=try alterManifest(storage) { object in
                    var parts=object["parts"] as! [[String:Any]]
                    parts[0]["destinationPath"]="../escaped";object["parts"]=parts
                }
            }
            let service=ZayitSearchArtifactService(manifest)
            let status=await service.status(databaseURL:database)
            record(kind+" status rejects damaged package",isRepair(status))
            let discovery=try await service.discover(databaseURL:database)
            record(kind+" discovery rejects damaged package",isRepair(discovery))
        }
        let failed=results.filter{$0["status"]=="FAIL"}.count
        let value:[String:Any]=["total":results.count,"passed":results.count-failed,"failed":failed,"cases":results,
                               "native_ui_executed":0,"engine_query_executed":0]
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys,.prettyPrinted])
            .write(to:owned.appendingPathComponent("RESULT.json"))
        if failed>0 { exit(1) }
    }
}
