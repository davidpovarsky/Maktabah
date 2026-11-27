@MainActor final class OriginalController {
    var expandedGroups: Set<String> = []
    let dataSource = OriginalDataSource()
    let collectionView = OriginalCollection()
    func setOriginalGroupExpanded(_ node: SwiftUIAnnotationNode, willExpand: Bool, animated: Bool) {
        let id = node.id

        if willExpand {
            expandedGroups.insert(id)
        } else {
            expandedGroups.remove(id)
        }

        let groupItem = AnnotationItem.group(node)
        var sectionSnapshot = dataSource.snapshot(for: id)

        if willExpand {
            sectionSnapshot.expand([groupItem])
        } else {
            sectionSnapshot.collapse([groupItem])
        }

        dataSource.apply(sectionSnapshot, to: id, animatingDifferences: animated)
        if let indexPath = dataSource.indexPath(for: groupItem),
           let cell = collectionView.cellForItem(at: indexPath)
        {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                if var config = cell.contentConfiguration as? ListContentConfiguration {
                    config.isExpanded = willExpand
                    cell.contentConfiguration = config
                }
            }
        }
    }
}
extension OriginalController {
    func invoke(_ node: SwiftUIAnnotationNode, native: Bool, validating: @escaping @MainActor () -> Bool) {
        setOriginalGroupExpanded(node, willExpand: true, animated: !native)
    }
}
