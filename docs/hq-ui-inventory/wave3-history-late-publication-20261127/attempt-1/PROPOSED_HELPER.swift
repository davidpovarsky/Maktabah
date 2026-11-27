    func isCurrentQualifiedLoad(_ load: HistoryQualifiedPublication.Load) -> Bool {
        guard let revision = load.revision else { return false }
        return qualifiedLoadRevision == revision && load.isCurrent
    }
