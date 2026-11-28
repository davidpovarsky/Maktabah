# Exact retained untracked archive restoration

This documentation-only checkpoint preserves the complete16-file restoration
closure for one existing691,303,419-byte archive. The original archive is private:
repository1474927804, draft461337522, immutable archive asset803430120. Its exact
SHA256 is e7783edfe09c044fb8b13f398604b35011a987970495c47d52a3306a15b8b100.
Manifest asset803430071 contains all85 original metadata/hash rows.

Both assets received full authenticated byte/size/SHA256 readbacks. Publication
job_ed3c7570ae45 finished with exit0; the exact outer result, receipt, marker and
terminal are preserved. Root's separate retirement preparation job_57b52caad25e
revalidated85 entries, all73 regular-file hashes, fresh private identities, and
387 processes with no active archive FD/mapping/cwd/exe and no inspection errors.
That preparation did not remove anything.

The actual pointer is RESTORATION_POINTER.json; its SHA256 is
c7c944a1f5d742d30d644acf525bfa68aefecdd755ceb8139bd815603c676c78.
SOURCE_SEAL.json SHA256 is
b3fb30020b2bafffd741829e78974f1fa088e20c70d5291d8d35648463ab0e1e.
The four exact Python sources and all other sealed inputs are adjacent.

A separate retirement commit still requires full remote Git-blob readback of
all16 required files, exact PREDELETE acknowledgement, fresh private identities,
all85 source hashes, fresh no-use and final descriptor/name joins. It can unlink
only the pinned untracked.tar.gz. The84 other contents/identities/modes/xattrs
remain protected; the immediate parent directory's namespace timestamps must
change and are explicitly recorded.

Future restoration uses restore_untracked_leaf.py with python3 -I -B as Root,
the exact source seal, pointer path/SHA, --restore-one-leaf, and a new canonical
UUID supplied to --attempt. It downloads only the immutable opaque archive to an
exclusive temporary sibling, verifies full disk bytes, restores the supported
metadata, and exclusively publishes the absent leaf. It never extracts the
archive or replaces another file. It retains failed partials. Original inode
and ctime cannot be recreated; historical metadata remains in the snapshot.
The original Data floor plus the complete payload is still required.

REVIEW1/REVIEW2 packets preserve the initial source findings and correction.
The initial unresolved restore aliases and missing outer-job-output join have
not been erased. This is evidence preservation only: no new product, SDK,
native, production, owner-signature, TestFlight or physical acceptance is claimed.
