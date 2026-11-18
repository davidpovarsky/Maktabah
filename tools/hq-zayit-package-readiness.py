#!/usr/bin/env python3
"""Exact production readiness-method tests, real official miniature index files.

These are source-method/filesystem checks, not engine, app or Native acceptance.
Explicit boundaries cover storage root/lock, backup flag, DB compatibility and
network discovery only. Actual method bytes are retained and never rewritten.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,shutil,subprocess,sys,urllib.request,uuid
ROOT=Path(__file__).resolve().parents[1]
MANIFEST_SHA="3c7dd1358954ac8a026dcdb575b404afe1ea2d37a6aebe0523cc5617fc47bc7d"
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def method(source,marker):
    start=source.index(marker)
    # These selected original methods contain no Swift string with unmatched braces.
    opening=source.index("{",start);depth=1;end=opening+1
    while depth:
        depth+=(source[end]=="{")-(source[end]=="}");end+=1
    return source[start:end]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir",type=Path,required=True)
    parser.add_argument("--baseline",help="Exact immutable source ref for RED reproduction")
    args=parser.parse_args();out=args.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    fixture=ROOT/"build/hq-zayit-official-mini-v6";fixture.mkdir(parents=True,exist_ok=True)
    profile=json.loads((ROOT/"Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text(encoding="utf-8"))
    base=profile["releaseBaseURL"]
    manifest_path=fixture/"zayit-search-manifest.json"
    def fetch(url,p,expected):
        if p.exists():
            if digest(p)!=expected:raise RuntimeError("Existing owned fixture hash mismatch: "+p.name)
            return
        with urllib.request.urlopen(url,timeout=90) as response:data=response.read()
        if hashlib.sha256(data).hexdigest()!=expected:raise RuntimeError("Official artifact hash mismatch")
        p.write_bytes(data)
    fetch(base+"/"+profile["zayitManifestAssetName"],manifest_path,MANIFEST_SHA)
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    index=fixture/"index";index.mkdir(exist_ok=True)
    paths={}
    for part in manifest["parts"]:
        rel=Path(part["destinationPath"])
        if rel.is_absolute() or ".." in rel.parts or "\\" in part["destinationPath"] or ":" in part["destinationPath"]:
            raise RuntimeError("Unsafe provider path")
        archive=fixture/part["assetName"];fetch(base+"/"+part["assetName"],archive,part["sha256"])
        if archive.stat().st_size!=part["packagedBytes"]:raise RuntimeError("Actual part size mismatch")
        dest=index/rel;dest.parent.mkdir(parents=True,exist_ok=True)
        import zstandard
        with archive.open("rb") as compressed,zstandard.ZstdDecompressor().stream_reader(compressed) as reader:
            data=reader.read()
        if len(data)!=part["uncompressedBytes"]:raise RuntimeError("Actual extracted part size mismatch")
        paths.setdefault(str(dest),[]).append((part["destinationOffset"],data))
    for name,chunks in paths.items():
        p=Path(name);expected=b"";position=0
        for offset,data in sorted(chunks):
            if offset!=position:raise RuntimeError("Official part offsets are not contiguous")
            expected+=data;position+=len(data)
        if p.exists():
            if p.read_bytes()!=expected:raise RuntimeError("Existing owned index differs from official bytes")
        else:p.write_bytes(expected)
    source_path="Source/ZayitSearch/ZayitSearchDistribution.swift"
    raw=subprocess.check_output(["git","show",args.baseline+":"+source_path],cwd=ROOT) if args.baseline else (ROOT/source_path).read_bytes()
    source=raw.decode("utf-8-sig")
    policy=(ROOT/"Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift").read_text(encoding="utf-8")
    blocks={
      "models":source[source.index("struct ZayitSearchArtifactManifest:"):source.index("extension ZayitSearchDistributionError:")],
      "storage":source[source.index("struct ZayitSearchArtifactStorage:"):source.index("    func availableCapacity()")],
    }
    snippets={name:method(source,"    func "+name+"(") for name in ["status","discover","installedManifest","validateStaging"]}
    safe=method(policy,"    static func validateSafeRelativePath(")
    owned=ROOT/"build"/("zrf-"+uuid.uuid4().hex[:12]);owned.mkdir()
    generated=owned/"ActualReadinessMethods.swift"
    generated.write_text("import Foundation\n"+blocks["models"]+"\n"+blocks["storage"]+
       "\n    private func exclude(_ url: URL) throws {}\n}\n"+
       "enum OtzariaSearchArtifactPolicy {\n"+safe+"\n}\n"+
       "actor ZayitSearchArtifactService {\nlet fixtureManifest: ZayitSearchArtifactManifest\n"+
       "init(_ manifest: ZayitSearchArtifactManifest) {fixtureManifest=manifest}\n"+
       "\n".join(snippets.values())+"\n"+
       "func resolveArtifact(matching databaseURL: URL?) async throws -> FixtureResolvedArtifact { .init(manifest: fixtureManifest) }\n"+
       "func validateCompatibility(_ manifest: ZayitSearchArtifactManifest, databaseURL: URL) throws { guard manifest.profileID == \"miniTest10\", manifest.profileVersion == 6 else { throw ZayitSearchDistributionError.incompatible(\"fixture profile boundary\") } }\n}\n",
       encoding="utf-8")
    executable=owned/("readiness.exe" if os.name=="nt" else "readiness")
    command=["swiftc","-parse-as-library","-swift-version","6","-strict-concurrency=complete",str(generated),
             str(ROOT/"Tests/HQ/search/ZayitPackageReadinessFixtures.swift"),"-o",str(executable)]
    compile_result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=120)
    (out/"compile.log").write_text(compile_result.stdout+compile_result.stderr,encoding="utf-8")
    report={"observed_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "source_ref":args.baseline or subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
            "source_file_sha256":hashlib.sha256(raw).hexdigest(),
            "exact_method_sha256":{k:hashlib.sha256(v.encode()).hexdigest() for k,v in snippets.items()},
            "test_source_sha256":digest(ROOT/"Tests/HQ/search/ZayitPackageReadinessFixtures.swift"),
            "official_manifest_sha256":digest(manifest_path),"actual_index_files":{str(Path(n).relative_to(index)):digest(Path(n)) for n in paths},
            "owned_fixture":str(owned),"compile_exit":compile_result.returncode,"native_ui_executed":0,"real_engine_queries_executed":0,
            "boundaries":["Exact unmodified production status/discover/installedManifest/validateStaging method bodies",
                          "Exact production manifest/state/error declarations and storage prepare/cleanup methods",
                          "Fixture roots/lock/backup attribute, DB compatibility and network discovery are explicit doubles",
                          "Real official hashed miniTest10-v6 index bytes copied into unique owned test directories"]}
    code=compile_result.returncode
    if code==0:
        run=subprocess.run([str(executable),str(owned),str(index),str(manifest_path)],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=90)
        (out/"tests.log").write_text(run.stdout+run.stderr,encoding="utf-8")
        print(run.stdout);code=run.returncode
        report["execute_exit"]=code
        if (owned/"RESULT.json").is_file():report["cases"]=json.loads((owned/"RESULT.json").read_text(encoding="utf-8"))
    else:print(compile_result.stderr[-6000:])
    report["status"]="METHOD_FILESYSTEM_PASS_NOT_NATIVE" if code==0 else "FAILED"
    (out/"RESULT.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":report["status"],"compile_exit":compile_result.returncode,"cases":report.get("cases",{})},ensure_ascii=False))
    return code
if __name__=="__main__":raise SystemExit(main())
