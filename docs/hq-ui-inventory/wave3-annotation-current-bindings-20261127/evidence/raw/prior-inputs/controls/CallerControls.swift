import Foundation

@main struct CallerControls {
    @MainActor static func main() {
        var cases: [[String: Any]] = []
        func run(_ name: String, _ body: () throws -> Void) {
            UIView.holdAnimation = false; UIView.heldAnimation = nil
            do { try body(); cases.append(["name":name,"passed":true]) }
            catch { cases.append(["name":name,"passed":false,"error":String(describing:error)]) }
            UIView.heldAnimation = nil
        }
        func group(_ f: Fixture) throws -> UICollectionViewCell {
            guard let cell=f.controller.collectionView.cells[IndexPath(indexes:[0,0])] else { throw OwnerFailure(message:"group fixture absent") }
            return cell
        }
        run("actual binding calls full original reveal helper then canonical selected-cell observation") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            try f.apply()
            try check(cell.configurationWrites==writes+1,"one original group configuration")
            try check(f.controller.collectionView.selections==1,"one original selection")
            try f.complete()
        }
        run("actual diffable callback publication refuses before later cell writes or selection") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            f.controller.controlOnExpansion { f.controller.nativeRoutingPublication.willPublish() }
            try refusal { try f.apply() }
            try check(cell.configurationWrites==writes && f.controller.collectionView.selections==0,"stale body did not continue")
        }
        run("actual binding release during expansion retires its weak captured Pending") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            f.controller.controlOnExpansion { f.binding.releaseSource(requestID:f.request) }
            try refusal { try f.apply() }
            try check(cell.configurationWrites==writes && f.controller.collectionView.selections==0,"released request continued")
        }
        run("escaping animation cannot write once the same pending phase is applied") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            UIView.holdAnimation=true;try f.apply()
            guard let callback=UIView.heldAnimation else { throw OwnerFailure(message:"actual helper did not register original animation") }
            callback()
            try check(cell.configurationWrites==writes,"post-apply callback wrote")
            try f.complete()
        }
        run("escaping animation cannot write after successful finish and exact source release") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            UIView.holdAnimation=true;try f.apply()
            guard let callback=UIView.heldAnimation else { throw OwnerFailure(message:"no held callback") }
            try f.complete();callback()
            try check(cell.configurationWrites==writes,"completed weak Pending was reused")
        }
        run("escaping animation cannot write after binding unmount") {
            let f=Fixture();try f.retain();try f.begin();let cell=try group(f),writes=cell.configurationWrites
            UIView.holdAnimation=true;try f.apply()
            guard let callback=UIView.heldAnimation else { throw OwnerFailure(message:"no held callback") }
            f.binding.unmount();callback()
            try check(cell.configurationWrites==writes,"unmounted request was reused")
        }
        let passed=cases.filter{$0["passed"] as? Bool == true}.count
        let value:[String:Any] = ["passed":passed,"failed":cases.count-passed,"cases":cases,
            "scope":"Actual full binding/caller/helper over explicit UIKit/domain boundaries; no app/native execution"]
        let data=try! JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys])
        print(String(decoding:data,as:UTF8.self));exit(passed==cases.count ? 0:1)
    }
}
