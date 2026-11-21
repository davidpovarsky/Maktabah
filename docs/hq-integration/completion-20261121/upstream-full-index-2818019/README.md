# Current unsigned upstream review, full-index format

This package binds all 49 changed protected files on application source
2818019c7dcecda953c74caa4f38823fb97cf70f to policy baseline
031df35710ab2c6015efb1acd1e65154dbcd3f24 and pinned upstream
a0ed0df908a6cb38bc459d4baaeb400f447b2fc4.

manifest.json names each complete base/head Git blob, canonical full-index patch
SHA-256 and byte length. unsigned-full-index-patches.zip contains that same
manifest and all 49 exact patch files. Every member hash and ZIP CRC was checked.
The generator was reviewed and tested in commit 978db8b3; full object IDs avoid
the historical abbreviation-width drift.

This is an unsigned review package. It does not change the exception register,
supply an owner private key, configure a verification key, grant approval status,
or satisfy the existing cryptographic gate. It also grants no Native or release
acceptance. The original historical package and archives remain intact in Git.

The operational authorization in the current conversation is recorded in Asana.
The remaining cryptographic prerequisite is authentic owner signing material for
the exact reviewed records, with the independently pinned verification key. A key
was not invented or substituted. The signing preflight rejects mismatched IDs,
blob aliases, digest aliases and archived bytes before reading private material.
The CI guard retains its trusted-base record admission route; no unsafe override
is part of this package.

Tracked Source, Vendor, Xcode project and UI-test trees are unchanged by this
documentation commit. Subsequent CI-only commits may reuse this package only if
the exact protected blob closure remains identical.
