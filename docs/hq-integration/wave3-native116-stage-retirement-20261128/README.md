# Actual retirement of the closed Native116 stage archive

The one closed stage archive was actually retired after the full 1,272,863,810-byte remote archive readback and durable preservation commit ae225aef1c4bfbc891a79085d40564254460d39b. The original Native116 evidence tree and its five external references remain protected.

Preparation job 38079a35e83b and independent review d042b64339c9 bound PREDELETE SHA256 104ee91e1c1bbe4756a0e5976849ba0a61e07c6b7f361b1dbcf1b7b3e3fe5ad3. Commit job 695b4bbc5941 repeated the full content hash and two privileged exact-file consumer checks before one fixed descriptor-relative unlink. The retained original descriptor had link count zero; the parent directory was fsynced and its namespace changes were reported. The original terminal retained its complete bytes and immutable metadata.

Independent job 15daf663d116 read the complete commit evidence and made a fresh pinned SSH observation: the archive was absent, only the original STAGE_TERMINAL.json remained, and its full 65,536-byte SHA256 was f60435ce1d4ada723f3afe44ca17fd006564c02cbbee74e48c2ab34368f9db35. Three nonfatal SyntaxWarnings from compact numeric-token spacing are preserved together with the exact verifier source and original output.

PRESERVED_RETIREMENT_EVIDENCE.zip contains all six sealed source files, the durable admission, all eight preparation files, all eight commit files, the independent proof, its complete job output, its exact verifier and the inventory. The lossless bundle preserves original source whitespace and all raw evidence. No original transcript was rewritten or omitted.

This operation does not change the Native116 result. Its historical baseline remains 82 passes and 34 failures; the final candidate has not run. The qualified restoration source and complete remote archive remain preserved, but restoration was not executed. Shared free-space observations do not establish an exclusive APFS reclaim amount, and the original full-app resource gate remains unchanged.
