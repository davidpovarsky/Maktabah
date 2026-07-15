# Upstream tracking

The Rust implementation keeps function names and module boundaries close to the Kotlin source so upstream changes can be reviewed mechanically.

Run:

```bash
python3 Scripts/sync-zayit-upstream.py --check
```

This fetches only source files listed in `UPSTREAM_MANIFEST.json` and reports changes. The script does not overwrite the Rust port.
