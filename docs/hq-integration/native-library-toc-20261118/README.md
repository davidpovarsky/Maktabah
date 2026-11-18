# Original Library and TOC public roots

Status: source implemented; four actual Native cases NOT_RUN. Apple SDK and complete app validation for this new source remain pending. Historical passes are not reused.

The original ReaderSidebarPageCoordinator now lives in iOSMainView and is shared with the same iPadLayout and native routing host. The pager, Library, TOC, reader, filters, manager and workspace remain their original instances. Scene projections read that actual coordinator instead of a nil sidebar.

The existing registry exposes native.library and native.reader.toc using the frozen public currentTab root shape. No public schema extension or private query/tab/profile/scene fields are introduced. Core remains the authority and the original orchestrator guards each native mutation. App Intent discovery uses the same runtime availability and original service.

Library selects the original page on iPad, or pops the original compact NavigationStack to its Library on iPhone, without closing the original Reader tab. TOC requires the exact selected original iPad Reader, matching active backend/book section, and a nonempty original loaded TOC without a failure. There is no first-tab substitution, new renderer, book resolution, draft creation or saved-note mutation.

Completion requires that exact original page plus its independent visible UIKit witness. No desired sidebar visibility is represented as a pre-existing observation. Private original filters are retained and never submitted or serialized into URLs.

## Native acceptance cases (not yet executed)

- iPad Library: private query survives History/back, original Reader/tab/group/profile and rendered locator preserved.
- iPad TOC: actual rows and receipt, private filter survives Library/back, original Reader/locator retained.
- iPad TOC without an original Reader: explicit refusal and no receipt; original Library retained.
- iPhone Library: actual NavigationStack root and preserved original workspace Reader owner/book.

The owned simulator system-URL transport adds only these exact root paths. Original credential, UUID target, freshness, replay, size and mutation/path rejection checks remain.

Local Swift parse and14 portable URL-transport checks passed. These do not establish app/Native acceptance. No user database or old worktree was changed.
