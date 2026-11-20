# Use the existing original phone overview action

The actual Release 44665679661 phone overview and feature-setting tests first failed while waiting for reader-book-tabs-overview. That identifier is absent from the current product. The existing iOSReaderView toolbar exposes reader-open-tabs-button and toggles bManager.showingTabsList; CompactStudyWorkspaceHostModifier connects the original binding to StudyGroupsOverview.

The change updates exactly three Faithful phone selectors, including the newly added original one-book fixture preparation. No product code, timeout, test method, assertion, geometry, source identity, viewport, or iPad selector changes. Replacing the three corrected identifiers back reproduces every prior source byte.

The evidence establishes a wrong test selector, not a passed Native test. Apple typecheck and Native execution for this source remain NOT_RUN pending the frozen diagnostic38 run.
