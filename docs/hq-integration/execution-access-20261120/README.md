# Actual execution access and immutable Apple dispatch

The connected SentinelX host used for this work is Windows. Apple SDK/Simulator checks are executed through the existing Xcode27 GitHub workflows. This report does not infer physical-device acceptance from a compiler, source inventory or Simulator.

## Physical device observation

The read-only Windows PnP query returned seven currently-present **interface entries** whose friendly names matched iPad. Their classes are System, Bluetooth and MEDIA. These are not seven iPads and do not establish an active XCTest, USB or trusted development connection. No device identifier, serial number or friendly device name is retained.

The subsequent bounded query found no matching Apple Mobile Device/usbmux service. No idevice_id, ideviceinfo, idevicescreenshot, ideviceinstaller, iproxy, tidevice, ios, xcodebuild or xcrun command was on PATH. The ordinary Mobile Device Support directory was absent; an iTunes directory existed. No pairing, installation, provisioning change, network scan or device interaction was attempted. This is a precisely scoped access observation, not proof that the user owns no iPad or that no other configuration could support testing.

A usable physical iPad test connection and signed test application are not established in the available execution path. Physical UI, VoiceOver review, memory/thermal traces and full-corpus performance remain NOT_RUN on hardware. Existing physical task conditions are retained.

## Apple dispatch

Both workflows were actually dispatched on immutable checkout83bc48f7b27e41d5580124a974d78bfad6ace50c, application/test sourceca314e7cc5d5cdde2bb15a54a79c92541296349f, branch codex/otzaria-phase2-apple88-20261120. The initial run-list calls were briefly empty; the dispatch commands returned concrete URLs and a subsequent GitHub API read confirmed queued state and the exact branch/SHA. The initial outputs are retained unchanged.

- Apple SDK: https://github.com/davidpovarsky/Maktabah/actions/runs/44648487731
- Original full-v32 install/query/resume/relaunch: https://github.com/davidpovarsky/Maktabah/actions/runs/44648492504

These are dispatch facts, not completion or PASS. A single bounded watcher owns each run: SDK job_ae3485ac342e and v32 job_c5984f0c9608. The previous Native78 run44633736259 remains separately owned; no new Native88 or full Release was dispatched at this checkpoint. Later source work uses isolated worktrees and does not move the immutable dispatch branch.
