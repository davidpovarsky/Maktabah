# v40 production search release assets

These manifests and build metrics are the original release asset bytes. The inventories cover all 93 assets and 7,310,276,993 upload bytes. Each inventory lists the exact expected filename, byte count, SHA-256 and download URL. Part digests come from the verified packaging receipts. The handoff also checked the manifest digests, the local size of each part and the complete asset inventory.

| Engine | Planned GitHub release tag | Assets to stage | Upload bytes | Manifest SHA-256 |
| --- | --- | ---: | ---: | --- |
| Otzaria | `otzaria-search-data-v40-20261123094345-f8fea8efcac5` | 17 | 4,150,333,471 | `c10824ac3cc38514b64cb59e0c588c8b56d5d86ac3213bcd56bd75048cfb2b8b` |
| Zayit | `zayit-search-data-v40-20261123094345-17cabb80e86a` | 76 | 3,159,943,522 | `577176375f735af240d8a1e84f0a1ad23bf18018ae4c0f716e8acb142d8d8691` |

- Otzaria has 15 index parts, one manifest and one build metrics file. The source directory is `/Users/m1/builds/otzaria-core-20261126/otzaria-lexical-producer/attempt-20261126T021159-23772/package-v40/artifact` on Scaleway Mac. [Asset inventory](otzaria/RELEASE_ASSETS.json) · [Original asset manifest](otzaria/otzaria-search-manifest.json) · [Checksums](otzaria/SHA256SUMS)
- Zayit has 74 index parts, one manifest and one build metrics file. The source directory is `/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source/artifact-v40` on Oracle. Peak workspace usage for the Zayit build was unmeasured. [Asset inventory](zayit/RELEASE_ASSETS.json) · [Original asset manifest](zayit/zayit-search-manifest.json) · [Checksums](zayit/SHA256SUMS)

Both releases bind to the SeforimLibrary production release 455390662 and its 589-byte `seforim-schema7.db.zst.manifest.json`, asset 782942035, SHA-256 `ab51577bad2f457e24ab5f28082ba830597951ab5738a39652dec821e1dff2e3`. The raw 4,355,063,808-byte database SHA-256 is `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`. [Official v40 library release](https://github.com/Otzaria/SeforimLibrary/releases/tag/v40-20261123094345)

The Otzaria release manifest has the same artifact identity and bytes recorded by the packaging receipt and the app's verified local install and cold reopen. The Zayit manifest identifies the same archive tested by the real Swift installer, the offline readiness process and the independent comparison of all 74 installed files. Both acceptance scopes are recorded with their original receipts. [Otzaria native receipts](../native-v40-otzaria) · [Component evidence](../COMPONENT_ACCEPTANCE.md)

The original packaging records and the Zayit Swift install, offline and file parity receipts are available in the per-engine acceptance directories. The Zayit folder also contains the full-corpus pagination receipt. [Otzaria packaging receipt](otzaria/acceptance/OTZARIA_V40_PACKAGE_RECEIPT.json) · [Zayit lab receipts](zayit/acceptance)

Agent 3 owns both draft releases in `davidpovarsky/Maktabah`. Stage the files named in each inventory from its source directory. `RELEASE_ASSETS.json` and `SHA256SUMS` are handoff files. For each draft, compare the complete paginated GitHub asset list against the inventory by filename, uploaded state, size and SHA-256 digest. With each release ID, `GET /repos/davidpovarsky/Maktabah/releases/{release_id}/assets` returns the asset metadata. Production discovery uses the public release list and requires a manifest compatible with the installed database. Draft staging and production discovery have separate acceptance.

GitHub authenticated readback confirmed draft IDs 458964363 for Otzaria and 458964380 for Zayit against the exact tags above. Asset upload verification remains with the release writer.
