import Foundation
import CryptoKit
func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
@main struct SefariaContextSourceOracle {
 static func main() throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  var oracle=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("source-page-oracle.json"))) as! [String:Any]
  oracle["schema"]=1;oracle["status"]="ACTUAL_SOURCE_ORACLE_ONLY_NOT_UI";oracle["uiExecuted"]=false
  var sections:[[String:Any]]=[]
  for stem in ["psalms35-jps1917","psalms35-rashi","psalms35-koren"] {
   let raw=try Data(contentsOf:root.appendingPathComponent(stem+".json"))
   let receipt=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent(stem+"-receipt.json"))) as! [String:Any]
   precondition(digest(raw)==receipt["sha256"] as? String)
   let dto=try JSONDecoder().decode(SefariaTextsV3DTO.self,from:raw)
   let title=receipt["versionTitle"] as! String
   let selected=dto.versions.filter{$0.versionTitle==title && $0.language=="en"}
   let source=dto.versions.filter{$0.isSource==true}
   precondition(selected.count==1 && selected[0].isSource==false && source.count==1)
   let primary=source[0].text!.segmentStrings,translated=selected[0].text!.segmentStrings
   let mapped=SefariaSection(ref:dto.ref,heRef:dto.heRef,sectionRef:dto.sectionRef,indexTitle:dto.indexTitle,next:dto.next,prev:dto.prev,versions:dto.versions,linksBySegment:[],origin:.remote).asLibrarySection()
   precondition(mapped.segments.count==28 && primary.count==28 && translated.count==28)
   var rows:[[String:Any]]=[]
   for (index,segment) in mapped.segments.enumerated() {
    precondition(segment.primaryText==primary[index] && segment.translation==translated[index])
    let hebrew=segment.primaryText.readerPlainText,english=segment.translation!.readerPlainText
    precondition(!hebrew.isEmpty && !english.isEmpty)
    rows.append(["locator":segment.locator.persistenceKey,"sourceSHA256":digest(Data(hebrew.utf8)),"translationSHA256":digest(Data(english.utf8)),"sourceUTF8Bytes":hebrew.utf8.count,"translationUTF8Bytes":english.utf8.count])
   }
   sections.append(["versionTitle":title,"language":"en","reference":"Psalms 35","stableID":"sefaria|Psalms|ref:Psalms 35:17|"+title+"|en","sourceReceipt":receipt,"segments":rows])
  }
  oracle["sections"]=sections
  let bytes=try JSONSerialization.data(withJSONObject:oracle,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
  try bytes.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
  print("ORACLE_BYTES",bytes.count,"SHA256",digest(bytes))
 }
}
