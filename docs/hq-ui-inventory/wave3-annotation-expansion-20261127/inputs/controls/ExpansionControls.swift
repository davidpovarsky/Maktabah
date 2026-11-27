import Foundation

@main enum Controls {
    @MainActor static func main() {
        var results: [[String: Any]] = []
        func run(_ name: String, _ body: () -> Bool) {
            Boundary.reset()
            results.append(["name": name, "passed": body(), "trace": Boundary.trace])
        }
        let node = SwiftUIAnnotationNode(id: "original-section")
        run("ordinary nil route preserves all original effects and order") {
            let value = OriginalController(); var called = false
            value.invoke(node, native: false) { called = true; return false }
            return !called && value.expandedGroups == [node.id]
                && value.collectionView.cell.writes == 1 && value.collectionView.cell.expanded
                && Boundary.trace == ["snapshot", "apply", "indexPath", "cell", "animate", "config.get", "config.set"]
        }
        run("current native source expands and configures the original cell") {
            let value = OriginalController()
            value.invoke(node, native: true) { true }
            return value.expandedGroups == [node.id] && value.collectionView.cell.writes == 1
                && value.collectionView.cell.expanded
        }
        run("source retired in actual diffable apply stops later configuration") {
            let value = OriginalController(); var valid = true
            Boundary.hooks["apply"] = { valid = false }
            value.invoke(node, native: true) { valid }
            return value.collectionView.cell.writes == 0 && !Boundary.trace.contains("animate")
        }
        run("apply A B A publication cannot rearm original source") {
            let value = OriginalController(); var revision = 7
            Boundary.hooks["apply"] = { revision += 1; revision += 1 }
            value.invoke(node, native: true) { revision == 7 }
            return value.collectionView.cell.writes == 0
        }
        run("apply replacement cannot configure the replacement cell") {
            let value = OriginalController(); let old = value.collectionView.cell; var valid = true
            Boundary.hooks["apply"] = { valid = false; value.collectionView.cell = OriginalCell() }
            value.invoke(node, native: true) { valid }
            return old.writes == 0 && value.collectionView.cell.writes == 0
        }
        for stage in ["indexPath", "cell", "animate", "config.get"] {
            run("retirement during " + stage + " stops original configuration write") {
                let value = OriginalController(); var valid = true
                Boundary.hooks[stage] = { valid = false }
                value.invoke(node, native: true) { valid }
                return value.collectionView.cell.writes == 0
            }
        }
        run("retained animation closure refuses source retired after helper returns") {
            let value = OriginalController(); var valid = true
            Boundary.holdAnimation = true
            value.invoke(node, native: true) { valid }
            guard let callback = Boundary.heldAnimation else { return false }
            valid = false; callback()
            return value.collectionView.cell.writes == 0
        }
        run("ordinary route still executes original configuration after callback") {
            let value = OriginalController(); var valid = true; var checks = 0
            Boundary.hooks["apply"] = { valid = false }
            value.invoke(node, native: false) { checks += 1; return valid }
            return checks == 0 && value.collectionView.cell.writes == 1
        }
        let passed = results.filter { $0["passed"] as? Bool == true }.count
        let output: [String: Any] = ["scope": "actual extracted expansion helper; explicit UIKit callback boundary; native NOT_RUN",
            "passed": passed, "failed": results.count - passed, "cases": results]
        let raw = try! JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: raw, as: UTF8.self))
        exit(passed == results.count ? 0 : 1)
    }
}
