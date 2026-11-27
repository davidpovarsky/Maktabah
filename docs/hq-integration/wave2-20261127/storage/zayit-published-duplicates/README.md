# Verified removal of published Zayit compressed duplicates

The user authorized cleanup of reproducible inactive outputs after verification. Only the 74 named `zayit-index-*.zst` files were removed from the old core worktree's `build/zayit-v40-source/artifact-v40`. They occupied 3,159,917,458 logical bytes. This operation removed no source, receipt, log, manifest, build metrics, unpacked qualified index, lexical database, production database, or Mac output.

The actual GitHub release 458964380 was read immediately before verification. All 74 assets were uploaded with the exact manifest sizes and SHA-256 digests. The public manifest asset 794374545 matches local SHA-256 `577176375f735af240d8a1e84f0a1ad23bf18018ae4c0f716e8acb142d8d8691`. These originals remain at https://github.com/davidpovarsky/Maktabah/releases/tag/zayit-search-data-v40-20261123094345-17cabb80e86a .

Every local compressed part was hashed in full, with unchanged device/inode/size/mtime/ctime before and after reading. Open file descriptors and mapped-file references were empty before and after verification and immediately before removal. None of the payloads was tracked by Git. The search worker explicitly confirmed that neither these parts nor the qualified index was in use or scheduled for its current work. All 74 identities were rechecked before the first unlink. The exact permitted basenames, local hashes, public asset IDs/digests and stat witnesses are preserved in the JSON receipts.

The first read-only verifier reached its 50-second timeout. It produced no receipt and no surviving process; no deletion occurred. The second verifier ran as a bounded background job and completed all 74 hashes. The first cleanup transport returned a generic MCP Internal error; readback confirmed all 74 parts still present and no cleanup receipt. The one effective cleanup then completed through Sentinel script_run.

Filesystem available bytes immediately before/after the effective removal were 483,524,608 and 3,643,650,048. This is the observed filesystem delta, not a prediction about other agents' future writes. Metadata files in the target directory have identical hashes before and after; the parent directory entry list is unchanged.

Restore only when needed: download the same 74 named assets from that exact release, verify each expected compressed size and SHA-256 against PUBLIC_ASSETS.json, and place them in the recorded directory. The still-retained manifest and qualified index need no reconstruction. This receipt proves safe duplicate cleanup, not new index correctness or app/UI acceptance.
