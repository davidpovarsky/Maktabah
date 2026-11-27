# Dedicated continuous-pull host contract

## Integration API

Import `Scripts/CI/reader-continuous-pull-host.py` with `runpy.run_path` or
`importlib.util`; importing it has no device, network, or process side effects.

```python
def resolve_owned_installation():
    container = Path(core.command([
        "xcrun", "simctl", "get_app_container", udid, core.BUNDLE, "data"
    ], timeout=8).stdout.strip())
    database, relocation = owner.current_database(udid)
    return {
        "container": str(container),
        "database": str(database),
        "manifest": core.witness(database.parent / "seforim-installation.json"),
    }

host = ContinuousPullHost(
    udid=udid,
    app_container=container,          # observed initial path, not assumed final
    artifacts=case_output / "continuous-pull-host",
    tools_root=retained_pinned_idb_root,
    container_resolver=resolve_owned_installation,
)
extra_environment = host.start()
try:
    case_result = run_original_case(
        core, test_run, udid, case, allowance, case_output,
        {**environment, **extra_environment},
    )
finally:
    host_result = host.stop()
```

The integration controller must retain both failures if the case and cleanup
fail. `start()` returns `TEST_RUNNER_READER_CONTINUOUS_PULL_TOKEN` for direct
merge into the xcodebuild environment. The actual test runner receives
`READER_CONTINUOUS_PULL_TOKEN`. Do not add a second `TEST_RUNNER_` prefix.
The existing F08 production oracle/container environment remains required.
No launch argument may override the original Reader unit preference.

The callback is mandatory. It runs on the host's owned background thread about
once per second and must be read-only and bounded. It calls the original
`RetainedV40Installation.current_database` so the small current manifest stays
bound to the previously accepted original installation. It does not hash the
4.35-GB database on each call. Callback results must contain exactly
`container`, `database`, and `manifest`; the latter is the original
`{path, bytes, sha256}` witness. The host independently checks the actual simctl
data container, database placement/size and exact manifest release/tag/digest.

XCTest may relocate data before the first request. The host waits for the
owner's current matching admission and reads only that explicitly admitted
container. It never searches other containers. After the first request,
container/database/manifest are fixed for both mode operations. Fresh admission,
manifest, actual PID and executable path are checked at the held samples too.

## Contact ownership and observations

The integration owner must serialize all other UI/HID input on this UDID.
The host also holds a dedicated per-UDID advisory lock for this protocol. It
starts the existing pinned companion with an explicit UDID and its own private
domain socket, verifies the companion UDID, and never consults the global idb
registry. No tool installation, package update or download is performed.

The original test writes a fresh nonce request and then an exact pending
pointer inside `Documents` of the admitted app container. Each request binds
the token, UDID, actual original app PID, native UITextView identity, canonical
locator, render generation, document ID, original viewport basename, window/
Reader frames, portrait orientation and the three point-space waypoints.
The host rejects stale, malformed, wrong-mode or repeated operation requests.

There is one original async `Client.hid` RPC per successful mode. The iterator
suspends after the outgoing leg while the original passive observer proves
overscroll >=80, and after the return leg while it proves 0<=overscroll<80.
Every native request uses a new UUID, reads a bounded regular response and
checks PID/locator/generation/owner/source identity. The iterator yields one
`UP` after both observations. No XCTest action or competing viewport writer
runs while that contact is active. A final original sample checks restoration
to the native top edge. The test then checks the actual document and original
selected TOC via existing UI and canonical SQL metadata.

## Evidence and qualification

`RESULT.json` has host status
`HOST_CONTINUOUS_CONTACT_OBSERVATIONS_COMPLETE_UI_VERIFICATION_REQUIRED`
only if both paragraph and chapter operations completed. It deliberately
retains `uiAcceptance: false`. The controller must separately require the
exact XCTest selector to execute/pass with zero skips, with its existing
source/build/SDK/corpus/image checks before and after.

For each operation, `<nonce>-operation.json` includes the actual idb screen
dimensions, process/executable SHA before/after, current installation admission,
each real streamed touch position, both held phase boundaries, and all four
selected original native samples. Each raw sampled response is also retained
in its own nonce/phase/request-ID JSON. The corresponding UI attachments are:

- `reader-v40-original-continuous-pull-paragraph` / `...-chapter`: host receipt
  checked against the independent original source oracle.
- `reader-v40-continuous-pull-native-completion-paragraph` / `...-chapter`:
  exact canonical document/TOC completion after real release.

The private token must not enter exported logs or attachments. Its request and
pending IPC filenames remain private inside the actual owned app container.
The host preserves its unique private socket directory and never deletes a
simulator. The existing integration owner remains responsible for retention,
post hashes and source-qualified evidence collection.

Native execution has not yet occurred. The included component controls use
the real pinned idb encoder/protobuf with explicitly synthetic client/probe
doubles, and report zero simulator connections and zero touches.
