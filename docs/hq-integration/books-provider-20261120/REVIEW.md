# Configured Books Updates provider — current read-only verification

Checked at 00:07 UTC on 20 November 2026 (02:07 Asia/Hebron).

The original configured `BookUpdateViewModel.mainCSVURL` returned HTTP 200. Its 792 response bytes have SHA256 `99c2cf2fb5e4d5c9f30d2d0016cd769eef2b0953642e3464619310da4710c293`. The response contains seven book entries and the six semicolon-delimited fields `bkid;cat;verName;link;size;bk`.

This is a fresh observation of the configured original catalog, not proof of a signed provider identity. The catalog provides no backend identifier, target schema, source-database hash or migration manifest. It therefore does not establish a compatible updater contract for the installed Otzaria v32 database. No book payload was downloaded, no updater was invoked and no user database was opened.

The source-bound fail-closed safety remains appropriate: current product backends are not a native Maktabah updater owner. A download link and book version must not be interpreted as permission to run legacy Maktabah SQL against an Otzaria or Sefaria database. No provider, migration, alternate database or successful update is fabricated.

The actual historical Apple safety run is [44190056702](https://github.com/davidpovarsky/Maktabah/actions/runs/44190056702), source `837497a0666b01979715e3d0a81a983259ac8537`, with60 core and37 adapter fixture checks and an actual Apple SDK check using explicit compiler doubles. The specific guard/updater/VM/model/backend/fixture paths compared in `SOURCE_COMPARISON.json` have no diff at the current reviewed source. That preserves source evidence; it is not a new execution on a user installation.

The fixture source test does not prove an original application update, multi-file DB/WAL/SHM recovery, or physical-device safety. The original task remains open until an authentic compatible distribution/migration contract and actual native recovery acceptance exist. Previous successful safety fixtures are not rerun merely to repeat an unchanged result.

Exact downloaded bytes are retained in `main-catalog.raw.csv.gz`. The first metadata parsing attempt used the generic comma separator and therefore reported one column; `provider-parser-attempt1.json` retains that mistake. The corrected semicolon parsing uses the same downloaded bytes, reports six columns, and does not repeat the network request.
