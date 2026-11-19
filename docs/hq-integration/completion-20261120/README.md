# Otzaria execution recovery — 20 November 2026

Current source repair: 440f7e43af9fa49b67613685566fbb9b6bbc9248.
Base: 508d15149b5c1ba0d9949279755ba286fd57a138. Full-v32 prior run44593126391 failed before download because the acceptance loader substituted the pinned v32 manifest for every candidate URL, including newer v36 metadata. Native75 prior run44559352638 recorded52 PASS/21 FAIL/0 SKIP, plus2 window cases NOT_RUN after DNS fixture failure. Historical outcomes are retained.

The repair factors the existing URLSession manifest transport into an overload shared by production and native acceptance. Every candidate is fetched by its real URL and validated by the original policy; expected tag/manifest equality and full native installation/query/restart assertions are unchanged. Four synthetic transport regression scenarios cover incompatible newer release, malformed manifest, HTTP404 and all-incompatible failure. Their Apple execution is pending.

Local Windows Swift parser passed for the two changed source files and regression test. All14 original wrapper controls passed. The first local wrapper run exposed checkout CRLF conversion of the digest-pinned7032-byte manifest; its working bytes were restored from the exact Git blob and a specific -text attribute added. The original SHA25634319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57 is unchanged. These local checks do not establish Apple SDK or Native/UI acceptance.

## Ownership and preservation

Live upstream HEAD is d46af139b3a265399c16d87f5923acd8e3444024. Its history has no merge base with this existing downstream lineage, so no upstream sync/reset was attempted. Both Source/Otzaria/Search/Distribution files are downstream-owned and absent from the upstream tree. No original Maktabah Source/UI, Reader, navigation, engine binary, database or user state was edited. The workflow, source pins and .gitattributes are downstream integration/test seams; the two new test files are downstream-only. Standing owner authorization covers the changes. Exact source trees are repinned after the reviewed source commit, preserving independent evidence from earlier candidates.

No task completion or release acceptance is asserted. Physical iPad, full UI, Zayit and genuine model journeys remain separate gates.
