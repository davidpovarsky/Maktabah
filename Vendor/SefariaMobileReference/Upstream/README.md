# Sefaria Mobile provenance

- Audited upstream: `Sefaria/Sefaria-Mobile`
- Commit: `77eb30f66ea71a0af6638c3b5c03a4624f68da8f`
- Audit date: 2026-09-08
- Mobile export schema: `7`
- Distribution root: `https://readonly.sefaria.org/static/ios-export/7`

The native implementation depends on the observed contracts in `DownloadControl.js`,
`offline.js`, `offlineOnline.js`, `api.js`, `sefaria.js`, search integration, and their
tests: `packages.json`, `last_updated.json`, `packageData`, `makeBundle`, outer bundle
ZIPs, per-book ZIPs, index JSON, section metadata, and version-title MD5 filenames.

No Sefaria Mobile source code is vendored or copied. Its GPL-3.0 implementation was
used as behavioral reference; Maktabah independently reimplements the public data and
API contracts in Swift. Compact JSON fixtures are format-derived test data, not corpus
content. ZIPFoundation 0.9.20 is an MIT-licensed extraction dependency. Text version
license/source metadata is decoded and retained because licenses vary by version.

See `docs/sefaria-native-backend-architecture-audit.md` for the integration audit.
