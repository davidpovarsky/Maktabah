import pathlib,subprocess,hashlib,json,datetime,shutil
root=pathlib.Path("/Users/m1/builds/otzaria-wave3-inspector-repository-identity-20261127")
base=root.parent/"otzaria-wave2-library-controls-20261127/inspector-generation-attempt-2"
retained=base.parent/"inspector-mode-attempt-1"
sdk="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk"
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not root.exists()
root.mkdir()
old=retained/"OtzariaReaderSourcesInspectorHost.swift"
assert sha(old)=="b5166743145329783d5650aed8caffeb6fc755b599987ae7629cb75893a6d006"
text=old.read_text();needle="                showsCloseButton: showsCloseButton\n            )\n            #if DEBUG"
assert text.count(needle)==1
candidate=text.replace(needle,"                showsCloseButton: showsCloseButton\n            )\n            .id(ObjectIdentifier(repository))\n            #if DEBUG",1)
host=root/"OtzariaReaderSourcesInspectorHost.swift";host.write_text(candidate)
assert sha(host)=="1fb9c8c8db81b50f86541dd970e22bca8da934434c4c4990d47926f0f710ebb2"
models=[
 "Source/LibraryBackend/LibraryBackendModels.swift",
 "Source/Otzaria/Reading/OtzariaLineAnchor.swift",
 "Source/Otzaria/Reading/OtzariaReadingUnit.swift",
 "Source/Otzaria/Reading/OtzariaReadingUnitDescriptor.swift"]
model_hashes=[
 "b05a2e40eca5577441992d6fa1648ec7ae9ef617a23d52ef8a7f1e46e2c9d14d",
 "46c7282330eba729c77ddfbf732582bdcbfef2fcc7473b455cc5061bdd3931a6",
 "a7468b783f530958641918c23e3d654a31938446f9de0bdbb7211dfc5ab39cfb",
 "9c01b971ef6093fc7f9a2ea9680353aa9ad9f6b3bb87f7eefd4ac9a6780a4b02"]
for name,h in zip(models,model_hashes):assert sha(base/name)==h
adapter=retained/"MaktabahTorahInspectorAdapter.swift";boundary=retained/"InspectorModeBoundaries.swift"
assert sha(adapter)=="722c3e6dae328a217944d5298f60a2d6afc5125fdced02821cf34f2621d3b9e4"
assert sha(boundary)=="42da64e104ddfeb0273d2b731c364fcd3ad8b918d4da3539b9fdb0b082776912"
modules={base/"TorahInspectorCore.swiftmodule":"9eae6e9f285ba2212fab0d6c11b38a391367a3383b7e8ad5e7f70e53a2fa8393",base/"TorahInspectorUI.swiftmodule":"b9db06d331d130b3a5af3217d7f3c750d0a1ea0117ca8a65b027d600bc441f17",base/"libTorahInspectorCore.dylib":"303d83c27dc9255e8381f825276b62e8c0261806630cfe057552ce769dcd670f"}
assert all(sha(p)==h for p,h in modules.items())
cache=base/"module-cache";assert cache.is_dir()
inputs=[base/p for p in models]+[boundary,adapter,host]
before={str(p):sha(p) for p in inputs}
command=["xcrun","swiftc","-parse-as-library","-swift-version","6","-D","DEBUG","-Xfrontend","-strict-concurrency=complete","-sdk",sdk,"-target","arm64-apple-ios27.0-macabi","-F",sdk+"/System/iOSSupport/System/Library/Frameworks","-module-cache-path",str(cache),"-typecheck","-D","INSPECTOR_HOST_TYPECHECK","-I",str(base)]+[str(p) for p in inputs]
result={"schema":1,"scope":"WHOLE_CANDIDATE_HOST_AND_ADAPTER_TYPECHECK_WITH_DECLARED_BOUNDARIES_CATALYST27_NOT_NATIVE_UI","productBase":"f000c095cea53945eba3859eb8a25c0f60906970","candidateHostSHA256":sha(host),"retainedHostSHA256":sha(old),"startedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),"freeBytesBefore":shutil.disk_usage("/System/Volumes/Data").free,"inputsBefore":before,"modulesBefore":{str(p):h for p,h in modules.items()},"command":command,"existingModuleCache":str(cache),"newModuleCacheCreated":False,"sdkRebuilds":0,"modelControlsRerun":0,"nativeUIRuns":0,"physicalRuns":0}
(root/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
with (root/"typecheck.stdout.log").open("wb") as out,(root/"typecheck.stderr.log").open("wb") as err:
 completed=subprocess.run(command,stdout=out,stderr=err,cwd=root,timeout=40)
result.update({"exitCode":completed.returncode,"inputsAfter":{str(p):sha(p) for p in inputs},"modulesAfter":{str(p):sha(p) for p in modules},"stdoutSHA256":sha(root/"typecheck.stdout.log"),"stderrSHA256":sha(root/"typecheck.stderr.log"),"finishedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),"freeBytesAfter":shutil.disk_usage("/System/Volumes/Data").free})
result["inputsUnchanged"]=result["inputsAfter"]==result["inputsBefore"];result["modulesUnchanged"]=result["modulesAfter"]==result["modulesBefore"]
result["status"]="TYPECHECK_PASSED" if completed.returncode==0 and result["inputsUnchanged"] and result["modulesUnchanged"] else "FAILED"
(root/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({"status":result["status"],"exit":completed.returncode,"result":str(root/"RESULT.json"),"receiptSHA256":sha(root/"RESULT.json"),"inputsUnchanged":result["inputsUnchanged"],"modulesUnchanged":result["modulesUnchanged"],"freeBytesBefore":result["freeBytesBefore"],"freeBytesAfter":result["freeBytesAfter"],"stderr":(root/"typecheck.stderr.log").read_text()[:5000]}))
