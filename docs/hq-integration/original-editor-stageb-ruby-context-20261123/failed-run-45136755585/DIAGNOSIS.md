# Stage B 45136755585 — authenticated pre-build Ruby dependency failure

The exact push run at 8e9dac2d9585dd482e9ab784a65c5517b6847648 completed FAILURE. The owned observer exited 1 and reaped its child without timeout. The only evidence artifact, 14802911519, is 31,173,031 bytes, SHA256 58a809905472f70664c7e077918ee4909fb96d5e18169ca25bafe16e8bccb130. All 221 unique safe regular ZIP members passed CRC and have locally indexed size/digest records. The producer did not include a per-member digest index; no upstream index claim is made.

## Completed evidence

The original SDK's full 2,528-file distribution, 15 dynamic frameworks and 37 resource bundles were admitted. Actual retained command receipts show 17 Mach-O header, 15 dynamic CPU, 15 dynamic platform and 15 signature checks, all exit zero; 51 SwiftSyntax SDK inspection commands also exited zero. The actual exported API typecheck exited zero on Xcode 27.0/27A266a. This is compiler/distribution admission, not UI execution. Original signed EN/HE consumer qualification remains separately bound to run 45123300449.

## Exact failing boundary

The existing `pod install` completed. The later command `ruby Scripts/CI/hq-original-editor-app-target.rb ...` used the PATH-selected Ruby 3.3.14 and failed at line 6, `require 'xcodeproj'`, with LoadError. That line precedes argument parsing and all project opening or mutation. The authenticated generated project snapshot and the app-target plan agree on SHA256 155bda110d9eec18b1b88e00c07df70bf5d18bb25000678d8468c20a877892ec. No post-mutation project is claimed.

The report contains package resolution but no `xcodebuild build-for-testing` command. The subsequent collector failure, `No matching original SDK/app/runner build`, follows from this earlier boundary. Zero mounted editor test executions, edit/reopen outcomes or device outcomes are credited.

The Pod lock records CocoaPods 1.17.0. Existing logs do not record the actual Ruby executable, Gem.path, or loaded Xcodeproj version used by successful CocoaPods. Those values must be observed from that same original invocation; they must not be guessed from runner paths or replaced by an unpinned gem installation.

## Preservation

INTAKE.json binds original API metadata, watch closure, the complete local ZIP admission, selected original members and exact command families. No retry, build, producer rebuild, source test replay or installation was performed during this intake.
