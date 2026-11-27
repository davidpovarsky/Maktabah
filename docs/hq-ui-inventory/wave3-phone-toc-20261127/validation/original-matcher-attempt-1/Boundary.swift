
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

