# Otzaria prebuilt search artifacts

Maktabah keeps its native Swift/SwiftUI interface and SQLite library lifecycle. The
search package contains only data produced by the exact upstream Otzaria engine pinned
in `Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_COMMIT`.

The managed-corpus production path is:

1. the manual `otzaria-search-artifacts.yml` workflow resolves the official
   `Otzaria/SeforimLibrary` release;
2. the existing, accepted Swift corpus feeder sends that database to the pinned upstream
   Rust engine once on a macOS build machine;
3. upstream Tantivy commit/optimize/compatibility APIs finalize the index;
4. every index file is split into deterministic 512 MiB source chunks and independently
   zstd-compressed, hashed, measured, and described by a versioned manifest;
5. the public development-data release is selected by manifest compatibility, never by
   an unqualified "newest" rule;
6. iOS downloads resumable SHA-addressed parts, verifies all parts, streams them into an
   isolated staging directory, opens the staged index with the pinned upstream engine,
   and atomically promotes it while retaining the previous index for rollback.

Ordinary launch checks trusted local identity metadata, required file presence, and a
lightweight upstream open/document-count operation. It does not hash the database,
index, semantic artifact, or model and does not run SQLite `quick_check`.

External/custom databases retain the local builder as a developer fallback. A missing
official managed-corpus package is an explicit unavailable state and never triggers a
multi-hour local build.

## Audited upstream identity (2026-08-24)

- engine: `Otzaria/otzaria_search_engine` `refactor` at
  `265a14ea54f959a3e266d6e8acfa3a3b98101d68` (also current branch HEAD);
- Tantivy: `0.26.1`; schema: `4`; default generation order: `5`;
- semantic sidecar pinned by that engine:
  `e836ea6cac05e695efdb03ef227e78cd1a624149`;
- semantic builder: upstream `TantivyCorpus` plus `build_semantic_artifact`;
- model contract: `EMD123/Otzaria-Embedding-V1-Flash-0.6B`,
  `Otzaria-Embedding-V1-Flash-0.6B-Q4_K_M.gguf`, 396,474,560 bytes,
  SHA-256 `a1a89520be990087b0a54cc2635513e6eddbfae598fe979b44c52c6bd224b064`,
  1024 dimensions, last-token pooling, 512 tokens, backend
  `llama-cpp-qwen3-last-v1`.

No official upstream Tantivy lexical package exists for the current SeforimLibrary
release, so the manual workflow builds it with the pinned engine. The official semantic
release currently describes library v20, not current v22, and contains a 23.5 GB f32
vector payload (5,731,616 vectors) before installation overhead. It cannot fit the
target device's approximately 11.8 GB available storage, and the authoritative GGUF is
still Hugging Face `gated: manual`, so a shipped app cannot download it without embedding
user credentials. Semantic installation/runtime therefore remains disabled at the
full-scale gate; lexical search remains independent and fully usable.
