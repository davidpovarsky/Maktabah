# Original app build: pinned compiler macro authorization

The integrated native build run [44459534291](https://github.com/davidpovarsky/Maktabah/actions/runs/44459534291) used checkout f423a0d51c5a2d9bd87a533c48b57f9e395ac168 and application source e75f88b9b03e3ec3835f618e2f43539f6f0b3f67. Xcode 27.1 (27A9275) and Simulator SDK 27.1 completed the immutable input preparations, then failed in ComputeTargetDependencyGraph because EquatableMacros was not enabled. Application compilation and native UI did not start.

The actual graph contains one package macro target: EquatableMacros, package identity equatable, version 1.4.1, existing revision 597c2bb34af0c51331eb3b5e705f942d8ee20daa. The original Hanlin snapshot at 873607e45e021b40fe5b940c836d398c329f95c8 verified all 421 package files; all 17 resolved revisions and original app/vendor/project trees were retained.

The focused driver now records that exact package/target/revision in the normal SwiftPM macro authorization file after its original actual-checkout and lock verification. Existing entries are preserved. Invalid or unreadable JSON is an error, source drift is rejected before a write, the update is atomic with a preceding content recheck, and an existing identical authorization is reused. The original Xcode fingerprint validation remains enabled; no skip-macro, skip-plugin or global-disable option is added.

Four portable tests exercise real temporary files: existing-entry preservation/idempotence, changed or unverified package rejection, malformed existing JSON preservation, and actual read failure (a directory at the file path) rather than treating it as missing. These tests are policy/file tests; they are not Apple compiler or native app acceptance. The existing immutable input preflight also passes.

## Retained evidence

- Artifact 14500649880: official full ZIP SHA256 5eb71a1aeb28e2e4ca27dcb03ce41ab9d03b572df3d9e4ca2768e02df33dd69e, 38,476,084 bytes. At this source commit, exact authenticated range reads and selected member CRCs are verified; full ZIP download verification is recorded separately when completed.
- Original unsigned-app-build.log: 165,856 bytes, SHA256 50649094b65010a6cd6bf46857aa50e69cabc81b5cf0a52aa2bece75d529187f.
- Original result.json: 80,577 bytes, SHA256 d5c537582a0c431a2b508237bb46eb0291f3465d7932cf3fe8082495d3413d65.
- Retained workspace: C:/Users/DAVID/Code/Hanlin-Continuation-Evidence-20261119/otzaria-consumer-20261119/app-build-44459534291/.

A new original unsigned build is required to establish that this Xcode runner consumes the exact fingerprint and compiles the app. SDK/compiler run 44459541882 remains separately attributed to f423; it is not replaced by these portable checks. Real native history/provider/navigation acceptance remains open.
