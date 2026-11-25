# Explicit prepared MiniApps producer admission

The actual local e1a25038 producer was built after canonical Expo bundle and source-audit generation. Its committed Git tree is 692525c6b9bb02b5cfe7a00c07c408feb11e26c2; the exact reconstructed prepared tree is 8f37cfcddc17e24aa5887969499e91d4fbc96eac.

The separate committed review binds the original 300,113-byte binary patch (fa2f08f039e2be2ed09252cb61a48596fcf37743aca67a65f8d406bade70e32a), the exact ten modified paths, raw/produced modes, blob identifiers, lengths and SHA256 values, and the unchanged working-tree-only modification status. No Swift, Objective-C, runtime implementation or consumer package source changes are admitted by this generated delta.

The six original Expo archive copies keep exactly bundle.js, package.json, script.json and widget.tsx. Independent member comparison found only bundle.js bytes changed. The four remaining files are canonical source-audit documents; their incomplete/native/signing boundaries remain explicit.

The consumer verifier reconstructs the prepared tree itself using a temporary Git index, checks every reviewed before/after object, rejects additional paths, index changes, permission changes and uncommitted review files, then validates the producer's recorded source-file inventory against that exact tree. Ordinary unprepared-source admission remains strict. The actual SDK worktree and real Git index are not modified.

The included preparation commands and hashes are copied from the real Mac attempt. The portable controls are synthetic artifact-integrity controls only. This review does not establish standalone native test success, consumer UI behavior, device signing or TestFlight delivery. At preparation review time, the e1a 23-case native run was still in progress.
