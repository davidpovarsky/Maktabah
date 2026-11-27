# Bounded natural Inspector targets on recovered full v40

The single read-only run completed with exit 0 in 10.080108589492738 seconds. It examined 287 candidate Chapter units in the original three books. It did not find a natural raw relationship count of exactly 100, 500 or 2000 in this bounded set.

| Book | Units | Resolved anchor rows | Minimum / maximum deduplicated unit count | First / middle / last original positions |
| --- | ---: | ---: | --- | --- |
| Berakhot (103) | 125 | 59648 | 203 / 1027 | 336 / 677 / 407 |
| Tehillim (28) | 150 | 107236 | 94 / 4496 | 738 / 2056 / 357 |
| Derashot HaRan (3152) | 12 | 1427 | 55 / 232 | 55 / 146 / 68 |

These are candidate raw relationship counts guided by the recorded original source, including both matched sides, coverage, suppression/classification rules and the original link/book/line dedup key. The original Swift service/adapter must independently verify every selected unit. No Swift adapter or UI case ran, no content rows were decoded, and no larger result was truncated to create an exact workload. Exact-scale target discovery remains open.

## Recovered source identity

The integration owner released the freshly recovered database at:

`/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127/seforim.db`

It is 4355063808 bytes with the original full v40 SHA256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`. This discovery reuses the completed recovery audit (result hash `768d333cceb7e9d5e05bcb299f1ee579c8acd5174c5aec54c3afe76e0c074afb`; read-only SQL audit hash `369499a583771ee5f5316444b476705f100b56935b2c402146bf58b16b54e28d`). It verifies the current dev 2064 / inode 5946339, size, mtime, ctime and mode 0444 against that exact receipt before reading, and unchanged identity afterwards. It does not repeat the full hash or global counts, claim old deleted-inode continuity, or claim in-app installation.

The connection uses `mode=ro&immutable=1` plus `PRAGMA query_only=ON`. Each of three books has a 60-second SQL progress-handler deadline, at most 10000 source lines, and a 500000 matched-anchor-row ceiling. Each unit retains its exact source indices and membership hash. No reindex, schema mutation or DB write occurred.

The source guide is commit `a1e12fd377c0909df535c96d1a61f54bef5001a7`; all four recorded Swift files remain byte-identical at this branch's parent `422c21b0eebbe45a1d3b1c8beea0113ecb0c53c4`. The final integrated catalog must bind its own actual source independently.

## Retained evidence

- `DISCOVERY.json`: 276956 bytes; SHA256 `2a9172d6297fd491cb263179495da1b6b427b50e2e1616d0027e196312735ace`.
- Exact script: SHA256 `ef881c729c815c93a0c65cb960f000ea38b221d1cd51c8202a1f04f467a956af`.
- Exact query: SHA256 `fe63c0822221128463ff13b375653b32b95a2f391d91da7549a11999cf67e48a`.
- `RUN_RESULT.json` retains exit/timing; `stdout.log` retains the original emitted summary.

The initial larger Sentinel command returned an internal error. Readback proved that the destination did not exist, so the compressed retry launched exactly one process (launcher PID 3282002). Its retained result records exit 0. This was not an approval rejection.
