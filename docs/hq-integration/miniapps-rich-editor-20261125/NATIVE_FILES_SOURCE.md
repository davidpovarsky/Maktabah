# Original native MiniApps files — source integration

Status: source integration only; the original Maktabah build and native file journey have not run.

The rich annotation editor now exports selected original native file blocks (or the document's file blocks when there is no selection) through the OriginalEditor facade. It first saves and reopens the complete launch baseline. The shared HanlinMiniAppsBridge writes the actual file bytes, name and type; request metadata binds each attachment to its original native block ID. Source-book text stays read-only.

Returned file items remain attachments. The coordinator reads bounded bytes through a no-follow regular-file descriptor, rejects changed/truncated input, retains the bytes in the original application's per-request document folder, and calls the original native file import API. It does not convert a rich-editor file result into an app-private URL string. Text and URL content retain their existing text semantics. The quick plain-note path still uses its existing persisted file-link representation and is not claimed to have native file blocks.

Limits: 32 files and 8 MiB aggregate file bytes. The original canonical native archive still has its own compressed/expanded bounds; satisfying the input byte cap does not guarantee that the complete rich archive fits. A failed native import or save leaves the shared callback pending.

## Replay and cancellation boundary

The original native file upload and the host SQLite commit are separate transactions. No cross-engine atomicity is claimed.

Before applying a callback, Maktabah checks its exact durable MiniAppResult receipt. The full native archive, canonical annotation revision CAS and exact result receipt commit together on the captured original SQLite handle. Transport acknowledgement follows only that commit.

The OriginalEditor facade retires a native draft after any attempted native mutation fails or is cancelled. An uncertain draft cannot resume editing or receive another apply call. On reopening, the original local-annotation runtime starts a new journal draft UUID and private native Space from the unchanged canonical SQLite archive; it does not reattach the uncertain object. The native file block markers bind request UUID and file index. Until a successful canonical commit, the callback and retained source bytes remain recoverable. Old private native drafts may remain recovery evidence; their existence is not a duplicate canonical note.

## Admission still required

The new API compiler probe calls the real Attachment initializer, export and file-aware apply overload. It is not a runtime test. A newly qualified OriginalEditor SDK containing the native file facade is required before the Maktabah build can pass this probe. Historical e791/282-member qualification does not cover the new file APIs or the current corrected HanlinPlatform.

The actual two-app acceptance must demonstrate native block/file upload and byte readback, cold reopen of the saved archive, callback replay without duplicate canonical files, changed-content preservation and cancellation/failure recovery. The existing text-only journey and portable file checks do not provide this evidence.
