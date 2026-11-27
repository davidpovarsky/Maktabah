    /// The original list's existing modal State owner, not a second UI model.
    /// Equal modal writes and owner A-B-A all invalidate retained sources.
    func observeAnnotationPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        if annotationPresentationOwner != owner {
            advanceOriginalAnnotationPresentationPublication()
            annotationPresentationOwner = owner; annotationPresentationBlocked = isBlocked
            annotationSelectionBinding?.retire()
        } else { annotationPresentationBlocked = isBlocked }
    }
    func originalAnnotationPresentationWillChange(owner: UUID) {
        guard mounted, annotationPresentationOwner == owner else { return }
        advanceOriginalAnnotationPresentationPublication()
        annotationSelectionBinding?.originalModalWillChange(owner: owner)
    }
    func removeAnnotationPresentation(owner: UUID) {
        guard annotationPresentationOwner == owner else { return }
        advanceOriginalAnnotationPresentationPublication()
        let revision = annotationPresentationPublicationRevision
        annotationSelectionBinding?.retire()
        // The original list can be covered by its own editor/import/export
        // presentation. Preserve its blocker until that actual owner clears it.
        guard annotationPresentationBlocked?() != true,
              annotationPresentationOwner == owner,
              annotationPresentationPublicationRevision == revision else { return }
        annotationPresentationOwner = nil; annotationPresentationBlocked = nil
    }
    private func advanceOriginalAnnotationPresentationPublication() {
        // Fixed weak one-way latches only. No user/State callback runs under a
        // source lock; RN claims can be refused before the original setter.
        originalAnnotationPresentationPublication.invalidateRetainedSources()
        guard let revision = annotationPresentationPublicationRevision, revision < .max else {
            annotationPresentationPublicationRevision = nil
            return
        }
        annotationPresentationPublicationRevision = revision + 1
    }
    private var hasOriginalAnnotationPresentation: Bool {
        guard let revision = annotationPresentationPublicationRevision else { return true }
        let owner = annotationPresentationOwner
        let blocked = annotationPresentationBlocked?() == true
        return blocked || annotationPresentationPublicationRevision != revision || annotationPresentationOwner != owner
    }
    /// Retain before foreground activation. The caller must register the fixed
    /// originalAnnotationPresentationPublication BEFORE this first getter if it
    /// needs a synchronous off-MainActor claim (RN); this closure is no grant.
    func retainOriginalAnnotationPresentationObservation() throws -> @MainActor () throws -> Void {
        guard mounted, let revision = annotationPresentationPublicationRevision else {
            throw UIRouteError(.unavailable, "original_annotation_presentation_unavailable")
        }
        let owner = annotationPresentationOwner
        let validate: @MainActor () throws -> Void = { [weak self] in
            guard let self, self.mounted,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  self.annotationPresentationBlocked?() != true else {
                throw UIRouteError(.staleState, "original_annotation_presentation_changed")
            }
            // The original blocker is a getter callback. It may publish a new
            // owner/state; final equality alone cannot restore that source.
            guard self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner else {
                throw UIRouteError(.staleState, "original_annotation_presentation_changed")
            }
        }
        try validate()
        return validate
    }

