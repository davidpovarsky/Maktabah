# Mach-O scanner on original Anytype SDK292 binaries

Scaleway Mac ran the original consumer scanner from Maktabah `865e0ca39019d8b29d40263ae30b314d260a9a9a` on two actual arm64 simulator framework binaries from Anytype SDK Debug `8ae85a6490c4fb763fcd01d5f93345f7e071db92`. Xcode 27.0 (27A266a) enumerated the native load commands, full nlist and native export trie for each image. The checkpoints' scanner bytes match MiniApps commit `31fcb33747780c68e5e53b8aeeaa6d58ade1745b`. Both files retained their original SHA-256.

| Framework | nlist bytes | Export definitions | nlist elapsed |
| --- | ---: | ---: | ---: |
| ProtobufMessages | 133,040,377 | 116,131 | 2.774 s |
| AnytypeOriginalEditor | 230,773,689 | 173,067 | 4.717 s |

The exact machine receipt records binary, distribution, scanner and log digests. The 17 original evidence files are retained on Oracle at `/mnt/development/projects/evidence/otzaria-shared-agent1-20261126/sdk292-scanner-raw.tar.gz` (35,082,240 bytes, SHA-256 `3e20140bf6dae4c6f25992dbdb103d486188c267dda66ea54e46ca875cb4b7a4`) and the source copies remain on Scaleway at `/Users/m1/builds/otzaria-shared-agent1-20261126/sdk292-scanner/`.

This verifies the image parser and command deadlines on SDK artifacts. Whole-app image ownership and MiniApps UI acceptance still require the built Maktabah consumer.
