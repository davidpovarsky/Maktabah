# miniTest10 data profile

`miniTest10` is an immutable test corpus. Production remains the project default and keeps its existing release discovery and storage paths.

Select it only in debug/acceptance launches:

```text
-OtzariaDataProfile miniTest10
```

or with `OTZARIA_DATA_PROFILE=miniTest10`. A dedicated build can instead embed
`OTZARIA_DEFAULT_DATA_PROFILE=miniTest10` in its Info.plist, which makes a normal
iPad launch select the mini profile without injected process state. Explicit
arguments and environment variables still take precedence. There is intentionally
no production Settings control.

The profile is built from the pinned Otzaria v23 database and pinned lexical
release `v0.3.0`, and retains canonical book, line, category, TOC, link, author,
topic, version, and related IDs. Its database and both Tantivy indexes are
published by the manual `Build miniTest10 Data Profile` workflow in the immutable
`otzaria-miniTest10-v3` release. All three manifests carry `profileID=miniTest10`
and `profileVersion=3`; production metadata without those optional fields is
interpreted as `production/1` for backward compatibility. Historical v1/v2 remain
untouched.

Non-production data is isolated below `Application Support/Otzaria/Profiles/<profile>/` and matching cache namespaces. The shared `lexical.db` remains corpus-independent and is validated by its existing version, size, and SHA-256 contract.

Local database reproduction:

```bash
python3 Scripts/build-otzaria-data-profile.py \
  --source /path/to/seforim.db \
  --seed Scripts/DataProfiles/miniTest10.seed.json \
  --output /tmp/miniTest10-seforim.db \
  --compress
```

Generated databases, archives, and indexes are never committed.
