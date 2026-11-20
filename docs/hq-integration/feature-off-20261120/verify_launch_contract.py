#!/usr/bin/env python3
"""Compile exact original UI-test launch methods with explicit application doubles."""
import argparse, hashlib, json, os, pathlib, re, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
FILES={
 "base":"Maktabah-iOSUITests/MaktabahUITestBase.swift",
 "faithful":"Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift",
 "r27":"Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift",
}
def block(text,start):
 opening=text.index("{",start)
 depth=1; end=opening+1
 while depth:
  if text[end]=="{": depth+=1
  elif text[end]=="}": depth-=1
  end+=1
 return text[start:end]
def main():
 p=argparse.ArgumentParser()
 p.add_argument("--source-ref")
 p.add_argument("--out",type=pathlib.Path,required=True)
 a=p.parse_args()
 a.out.mkdir(parents=True,exist_ok=True)
 sources={}
 for k,path in FILES.items():
  raw=subprocess.check_output(["git","show",a.source_ref+":"+path],cwd=ROOT) if a.source_ref else (ROOT/path).read_bytes()
  sources[k]=raw.decode().replace("\r\n","\n")
 tier=block(sources["base"],sources["base"].index("public enum TestTier"))
 launch=block(sources["base"],sources["base"].index("func launchWithTier("))
 methods=[block(sources["faithful"],m.start()) for m in re.finditer(r"func launchReader\(",sources["faithful"])]
 override=block(sources["r27"],sources["r27"].index("override func launchReader("))
 swift=r"""
import Foundation
// Only the launch argument construction and Swift override dispatch are exercised.
// No XCTest, UIKit, process bootstrap or rendering is simulated as an acceptance pass.
__TIER__
@MainActor final class XCUIApplication {
 let bundleIdentifier:String
 var launchArguments:[String]=[]
 var launchEnvironment:[String:String]=[:]
 var launched=false
 init(bundleIdentifier:String) { self.bundleIdentifier=bundleIdentifier }
 func launch() { launched=true }
}
@MainActor enum Observations {
 static var checks:[[String:Any]]=[]
 static var sourceAssertionFailures:[String]=[]
 static func check(_ name:String,_ passed:Bool) { checks.append(["name":name,"passed":passed]) }
}
@MainActor func XCTAssertFalse(_ value:Bool,_ message:String="") {
 if value { Observations.sourceAssertionFailures.append(message) }
}
@MainActor class MaktabahUITestBase {
 var app:XCUIApplication!
 private let workspaceTestNamespace=UUID().uuidString
 private func recordRuntime27Configuration(stage:String) {}
 func dismissAlertsIfNeeded() {}
 @discardableResult __LAUNCH__
}
@MainActor class FaithfulReaderUIBase:MaktabahUITestBase {
 let workspaceNamespace=UUID().uuidString
 private var viewportURL:URL?
 var readerTestTier:TestTier { .smoke }
 var readerAdditionalLaunchArguments:[String] { [] }
 __FAITHFUL__
}
@MainActor class R27NativeUIBase:FaithfulReaderUIBase {
 __OVERRIDE__
}
@MainActor final class ExistingRealUITier:FaithfulReaderUIBase {
 override var readerTestTier:TestTier { .realUI }
 override var readerAdditionalLaunchArguments:[String] {
  ["-preferredBackend","otzaria","-smokeBackend","otzaria","-libraryViewMode","0"]
 }
}
@main struct LaunchContract {
 @MainActor static func main() throws {
  func argument(_ app:XCUIApplication,_ key:String)->String? {
   guard let i=app.launchArguments.firstIndex(of:key),app.launchArguments.indices.contains(i+1) else { return nil }
   return app.launchArguments[i+1]
  }
  let smoke=FaithfulReaderUIBase()
  smoke.launchReader(backend:"sefariaEmbedded")
  Observations.check("Original default still uses smoke bypass",smoke.app.launchArguments.contains("-smokeBypassBootstrap"))
  Observations.check("Original smoke backend argument is preserved",argument(smoke.app,"-smokeBackend")=="sefariaEmbedded")
  Observations.check("Original default profile stays miniTest10",argument(smoke.app,"-OtzariaDataProfile")=="miniTest10")
  let explicit=FaithfulReaderUIBase()
  explicit.launchReader(backend:"sefariaEmbedded",tier:.realUI)
  Observations.check("Required realUI overload emits no bypass",!explicit.app.launchArguments.contains("-smokeBypassBootstrap"))
  Observations.check("Required realUI overload pins requested preferred backend",argument(explicit.app,"-preferredBackend")=="sefariaEmbedded")
  Observations.check("Required realUI overload pins requested scenario backend",argument(explicit.app,"-smokeBackend")=="sefariaEmbedded")
  Observations.check("Exact base launch method invokes the application seam",explicit.app.launched)
  let inherited:FaithfulReaderUIBase=R27NativeUIBase()
  inherited.launchReader(backend:"sefariaEmbedded")
  Observations.check("Original R27 override remains dynamically dispatched",!inherited.app.launchArguments.contains("-smokeBypassBootstrap"))
  Observations.check("Original R27 override preserves requested preferred backend",argument(inherited.app,"-preferredBackend")=="sefariaEmbedded")
  Observations.check("Original R27 override preserves scenario backend",argument(inherited.app,"-smokeBackend")=="sefariaEmbedded")
  let existing=ExistingRealUITier()
  existing.launchReader()
  Observations.check("Existing realUI tier property remains honored",!existing.app.launchArguments.contains("-smokeBypassBootstrap"))
  Observations.check("Existing realUI additional arguments remain preserved",argument(existing.app,"-preferredBackend")=="otzaria" && argument(existing.app,"-libraryViewMode")=="0")
  let failed=Observations.checks.filter { ($0["passed"] as? Bool) != true }.count
  let report:[String:Any]=["checks":Observations.checks,"checks_count":Observations.checks.count,"failed":failed,"source_assertion_failures":Observations.sourceAssertionFailures,"native_cases_executed":0]
  print(String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
 }
}
"""
 swift=swift.replace("__TIER__",tier).replace("__LAUNCH__",launch).replace("__FAITHFUL__","\n".join(methods)).replace("__OVERRIDE__",override)
 source=a.out/"ExactLaunchContract.swift"
 source.write_text(swift,encoding="utf-8")
 executable=a.out/("launch.exe" if os.name=="nt" else "launch")
 command=[os.environ.get("OTZARIA_TEST_SWIFTC","swiftc"),"-swift-version","6","-strict-concurrency=complete","-parse-as-library",str(source),"-o",str(executable)]
 proc=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=120)
 report={"source_ref":a.source_ref,"sources_lf_sha256":{FILES[k]:hashlib.sha256(v.encode()).hexdigest() for k,v in sources.items()},"generated_lf_sha256":hashlib.sha256(swift.encode()).hexdigest(),"compile_exit":proc.returncode,"compiler_output":proc.stdout+proc.stderr,"native_cases_executed":0,"apple_sdk_typecheck":"NOT_RUN","boundary":"Exact original TestTier, launchWithTier, Faithful launch methods and R27 override compiled with explicit application/XCTest assertion seams; this verifies Swift inheritance, dispatch and argument construction only."}
 if proc.returncode==0:
  ran=subprocess.run([str(executable)],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=30)
  report["execute_exit"]=ran.returncode
  report["actual"]=json.loads(ran.stdout)
  report["execute_stderr"]=ran.stderr
 code=proc.returncode if proc.returncode else (1 if report["actual"]["failed"] or report["actual"]["source_assertion_failures"] else report["execute_exit"])
 (a.out/"RESULT.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
 print(json.dumps(report,ensure_ascii=False))
 raise SystemExit(code)
if __name__=="__main__":main()
