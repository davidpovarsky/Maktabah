
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

