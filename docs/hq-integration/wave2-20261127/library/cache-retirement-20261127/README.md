# Retirement of three released compiler caches

The integration owner explicitly authorized retirement of these three inactive,
reproducible directories only. The actual successful operation ran on Scaleway
Mac from 2026-11-27 06:04:49 through 06:04:50 UTC. No SDK, source, application,
corpus, evidence, adjacent module or executable was removed.

| Cache under the owned library-controls root | Original inode | Allocated KiB | Inventoried members |
|---|---:|---:|---:|
| `inspector-generation-attempt-1/module-cache` | 69059376 | 78,936 | 127 |
| `inspector-generation-attempt-2/module-cache` | 69162831 | 188,496 | 262 |
| `ui-attempt-1/module-cache` | 67222188 | 97,020 | 168 |

The root is `/Users/m1/builds/otzaria-wave2-library-controls-20261127`.
The total observed allocated size was **373,198,848 bytes**. Actual host free
space changed from 11,301,457,920 to 12,020,314,112 bytes during this operation.
That larger free-space delta includes concurrent host activity and is not
attributed wholly to these cache removals.

The operation required the expected canonical root inode/device and the current
`m1` owner, recursively inventoried only these caches, rejected symlinks,
nonregular members and shared file hardlinks, and bounded member counts. An
actual process inventory found no command referencing the owned artifact root.
Each `lsof +D` returned exit 1 with empty stdout/stderr, proving no observed open
FD reference in that check. A second unchanged inventory followed those checks.
Removal addressed only the original recorded members, checking identity again
and using `rmdir` on directories; a new/unrecognized member would stop removal.
Adjacent regular source/input/log/binary/module/receipt files were hashed before
and after; adjacent directory/link metadata was retained and compared unchanged.

`before-inventory.json.gz` is the losslessly compressed actual native
`cache-retirement-20261127T060449Z/BEFORE.json`, including all 557 member records,
the adjacent-artifact witnesses and the actual process/FD checks. `RAW_INPUTS.json`
binds its compressed and original decoded bytes. The successful original result
is `attempt-2-RESULT.json`, SHA-256
`6081f0cd111c1fd023f580f209ea1298eeba243069ecdebd534d9b8ff6a92e24`.

The first attempt at 06:02:46 UTC failed before any deletion because the SSH
default Python 3.9.6 has no `hashlib.file_digest`. Its actual result and exact
runner are retained. A separate read-only check confirmed all three original
inodes still existed before the second attempt. The second runner changes only
that hashing call to bounded streaming SHA-256 and repeats all admission checks;
it does not bypass ownership or active-use checks. Runner SHA-256 values are
`c471b3d4019c5f7a391253f4ef5f9396fca7aab6179a8f9ca45944d369761a52`
for attempt 1 and
`33f6e1bbd264fd4ce505aa1def387d221238d252345074a9066d24259ec80503`
for attempt 2.

This is a storage operation receipt only. It is neither a new compiler/control
run nor production installation, native UI, corpus or performance acceptance.
The SQLite companion helper work in progress was not included in this checkpoint.
