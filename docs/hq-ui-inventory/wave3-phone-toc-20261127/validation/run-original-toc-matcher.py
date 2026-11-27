#!/usr/bin/env python3
"""Execute exact original matcher/model/registry/iPad selector on sealed SQL rows.
This is source execution on Oracle, not an Apple SDK or native UI test.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,sqlite3,subprocess
ap=argparse.ArgumentParser()
ap.add_argument("--root",required=True);ap.add_argument("--database",required=True);ap.add_argument("--out",required=True)
a=ap.parse_args();root=Path(a.root);out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
def sha(data):return hashlib.sha256(data).hexdigest()
def read(p):return (root/p).read_text() if (root/p).exists() else subprocess.run(["git","-C",str(root),"show","HEAD:"+p],capture_output=True,text=True,check=True).stdout
def block(s,mark):
 start=s.index(mark);start=s.rfind("\n",0,start)+1
 opening=s.index("{",start);depth=1;i=opening+1
 while depth:
  if s[i]=="{":depth+=1
  elif s[i]=="}":depth-=1
  i+=1
 return s[start:i]
db=Path(a.database)
assert sha(db.read_bytes())=="d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
con=sqlite3.connect("file:"+str(db)+"?mode=ro&immutable=1",uri=True);con.row_factory=sqlite3.Row
all_sql="""SELECT te.id,te.parentId,te.level,te.lineId,COALESCE(ln.lineIndex,0) AS lineIndex,tt.text
FROM tocEntry te JOIN tocText tt ON tt.id=te.textId
LEFT JOIN line ln ON ln.id=te.lineId WHERE te.bookId=3891 ORDER BY lineIndex,te.id"""
ancestor_sql="""WITH RECURSIVE ancestors(id,parentId,level,lineId,textId) AS (
 SELECT t.id,t.parentId,t.level,t.lineId,t.textId FROM tocEntry t
 JOIN line_toc lt ON lt.tocEntryId=t.id JOIN line l ON l.id=lt.lineId
 WHERE l.bookId=3891 AND l.lineIndex=523
 UNION ALL SELECT t.id,t.parentId,t.level,t.lineId,t.textId
 FROM tocEntry t JOIN ancestors a ON a.parentId=t.id)
SELECT a.id,a.parentId,a.level,a.lineId,l.lineIndex,tt.text
FROM ancestors a JOIN tocText tt ON tt.id=a.textId
LEFT JOIN line l ON l.id=a.lineId ORDER BY a.level"""
rows=[dict(x) for x in con.execute(all_sql)]
ancestors=[dict(x) for x in con.execute(ancestor_sql)]
assert [x["id"] for x in ancestors]==[642933,643037]
assert [x["lineIndex"] for x in ancestors]==[0,522]
assert not any(x["lineIndex"]==523 for x in rows)
source={"profileID":"miniTest10","profileVersion":6,"databaseSHA256":sha(db.read_bytes()),
 "bootstrap":{"id":3121121,"bookId":3891,"lineIndex":523},
 "allNodesSQL":all_sql,"selectedPathSQL":ancestor_sql,"path":ancestors,
 "nodes":rows,"scope":"Independent pinned SQL fixture only; not production-v40 acceptance"}
(out/"SQL_SOURCE.json").write_text(json.dumps(source,ensure_ascii=False,indent=2)+"\n")
models=read("Source/LibraryBackend/LibraryBackendModels.swift")
model=read("Source/Features/Reader/ViewModel/BookTOCViewModel.swift")
ipad=read("Source/UI/iOS/Views/iPadLayout.swift")
legacy=subprocess.run(["git","-C",str(root),"show","HEAD:Source/UI/iOS/Views/iPadLayout.swift"],capture_output=True,text=True,check=True).stdout
registry=read("Source/LibraryBackend/LegacyIdentityRegistry.swift")
sources={
 "OriginalModels.swift":"import Foundation\n"+"\n\n".join(block(models,m) for m in ["enum BackendID:","enum TextPosition:","struct TextLocator:"]),
 "OriginalTracker.swift":read("Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift"),
 "OriginalSefariaRef.swift":"import Foundation\n"+block(read("Source/Sefaria/Domain/SefariaModels.swift"),"enum SefariaRef"),
 "OriginalTOCNode.swift":read("Source/Features/Reader/Models/TOCNode.swift"),
 "OriginalRegistry.swift":"import Foundation\n"+block(registry,"final class LegacyIdentityRegistry")+"\n"+block(registry,"private extension NSLock"),
 "OriginalModelMethods.swift":block(model,"struct TOCRange")+"\n@MainActor final class BookTOCViewModel {\n"+r"""
 var tocNodes: [TOCNode]
 var tocRanges: [TOCRange]
 private var nodeIdCache: [Int:TOCNode]
 init(nodes: [TOCNode]) {
   tocNodes = nodes
   let flattened = Self.flattenNodes(nodes)
   tocRanges = flattened.map { TOCRange(start: $0.id, end: $0.id, node: $0) }
   nodeIdCache = Self.buildNodeIdCache(flattened)
 }
 """+"\n".join(block(model,m) for m in ["func findNode(forContentId","func findNodeById","func findNode(for locator","func findMatchingNode","func pathToNode","private func findPath","static func buildNodeIdCache","static func flattenNodes"])+"\n}",
 "ActualIPadSelector.swift":"@MainActor struct ActualIPadHost {\n"+block(ipad,"private func selectedTOCNode")+"\nfunc select(_ reader: ReaderViewModel) -> TOCNode? { selectedTOCNode(for: reader) }\n}",
 "LegacyIPadSelector.swift":"@MainActor struct LegacyIPadHost {\n"+block(legacy,"private func selectedTOCNode")+"\nfunc select(_ reader: ReaderViewModel) -> TOCNode? { selectedTOCNode(for: reader) }\n}"
}
boundary=r"""
import Foundation
// Explicit boundaries only: original legacy initializer is not used.
struct TOC { let bab:String; let level:Int; let sub:Int; let id:Int; let entryId:Int; let parentId:Int? }
extension String { func convertToArabicDigits() -> String { self } }
struct Section { let locator: TextLocator }
@MainActor final class ReaderViewModel {
 let tocViewModel: BookTOCViewModel
 var backendSection: Section?
 var currentContentId: Int
 init(model:BookTOCViewModel,locator:TextLocator,id:Int) {
  tocViewModel=model;backendSection=Section(locator:locator);currentContentId=id
 }
}
"""
controls=r"""
struct SQLNode: Decodable {
 let id:Int; let parentId:Int?; let level:Int; let lineIndex:Int; let text:String
}
struct SQLSource: Decodable { let nodes:[SQLNode]; let path:[SQLNode] }
@main struct Controls {
 @MainActor static func main() throws {
  let sql = try JSONDecoder().decode(SQLSource.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
  let defaults = UserDefaults(suiteName:"toc-original-source-"+UUID().uuidString)!
  let registry = LegacyIdentityRegistry(defaults:defaults,persistenceDelay:60)
  let rows = Dictionary(uniqueKeysWithValues:sql.nodes.map { ($0.id,$0) })
  var actual:[Int:TOCNode] = [:]
  for row in sql.nodes {
   let locator = TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(row.lineIndex))
   let node=TOCNode(backendTitle:row.text,level:row.level+1,sub:0,id:registry.id(for:locator),parentId:row.parentId,entryId:row.id)
   node.backendLocator=locator;actual[row.id]=node
  }
  var roots:[TOCNode]=[]
  for row in sql.nodes {
   let node=actual[row.id]!
   if let parent=row.parentId,let actualParent=actual[parent] {actualParent.children.append(node)}
   else {roots.append(node)}
  }
  let model=BookTOCViewModel(nodes:roots)
  let locator=TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(523))
  let reader=ReaderViewModel(model:model,locator:locator,id:registry.id(for:locator))
  var failed=0,passed=0
  func check(_ name:String,_ value:@autoclosure()->Bool) {
   if value(){passed+=1;print("PASS "+name)}else{failed+=1;print("FAIL "+name)}
  }
  check("exact SQL bootstrap has no TOC heading",model.findNode(for:locator)==nil)
  check("original surrogate one-point ranges have no current-line heading",model.findNode(forContentId:reader.currentContentId)==nil)
  check("unchanged old iPad selector reproduces missing current row",LegacyIPadHost().select(reader)==nil)
  let selected=ActualIPadHost().select(reader)
  check("new iPad original matcher resolves independent SQL entry643037",selected === actual[sql.path.last!.id])
  let path=selected.flatMap { model.pathToNode($0) }
  check("original node object path equals independent SQL ancestry",path?.map(\.entryId)==sql.path.map(\.id))
  check("original selected title equals independent SQL heading",selected?.bab==sql.path.last?.text)
  check("exact heading remains selected",model.findMatchingNode(for:actual[643037]!.backendLocator!) === actual[643037])
  check("another work cannot match this tree",model.findMatchingNode(for:TextLocator(backend:.otzaria,workKey:"book:1",position:.legacyLine(523)))==nil)
  check("position before first heading is unavailable",model.findMatchingNode(for:TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(-1)))==nil)
  check("next heading uses its original node",sql.nodes.filter{$0.lineIndex>523}.first.map{model.findMatchingNode(for:actual[$0.id]!.backendLocator!) === actual[$0.id]} == true)
  check("selection preserves original Reader locator and surrogate",reader.backendSection?.locator==locator && reader.currentContentId==registry.id(for:locator))
  check("actual registry reverse resolves exact selected heading",selected.map{registry.locator(for:$0.id)==actual[643037]!.backendLocator} == true)
  print("RESULT passed=\(passed) failed=\(failed) nodes=\(rows.count)")
  if failed>0 {exit(1)}
 }
}
"""
sources["Boundary.swift"]=boundary;sources["Controls.swift"]=controls
for name,text in sources.items():(out/name).write_text(text+"\n")
combined="import Foundation\n"+"\n".join(sources.values())
(out/"Combined.swift").write_text(combined)
negative=combined.replace(sources["ActualIPadSelector.swift"],sources["LegacyIPadSelector.swift"].replace("LegacyIPadHost","ActualIPadHost"))
(out/"NegativeOriginalSelector.swift").write_text(negative)
records=[]
for variant in ["Combined","NegativeOriginalSelector"]:
 binary=Path("/mnt/development/projects/diagnostics/otzaria-wave3-toc-oracle-20261127")/("matcher-"+variant+"-"+out.name)
 cmd=["/usr/local/bin/swiftc","-swift-version","6","-strict-concurrency=complete","-parse-as-library",str(out/(variant+".swift")),"-o",str(binary)]
 result=subprocess.run(cmd,capture_output=True,text=True)
 (out/(variant+"-compile.log")).write_text(result.stdout+result.stderr)
 run=None
 if result.returncode==0:
  run=subprocess.run([str(binary),str(out/"SQL_SOURCE.json")],capture_output=True,text=True)
  (out/(variant+"-execution.log")).write_text(run.stdout+run.stderr)
 records.append({"variant":variant,"command":cmd,"compileExit":result.returncode,"runExit":None if run is None else run.returncode,"log":"" if run is None else run.stdout})
receipt={"at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"scope":"Actual original source execution; explicit Reader/domain storage boundary; no Apple SDK/native UI/physical claim","databaseSHA256":sha(db.read_bytes()),"source_commit":subprocess.run(["git","-C",str(root),"rev-parse","HEAD"],capture_output=True,text=True,check=True).stdout.strip(),"files":{n:sha((out/n).read_bytes()) for n in sources},"result":records,"nativeUIExecuted":0,"physicalExecuted":0}
(out/"RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n")
print(json.dumps(receipt,ensure_ascii=True))
