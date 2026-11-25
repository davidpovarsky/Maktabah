# File Workshop / סדנת קבצים

An installable MiniApp for the standalone Hanlin MiniApps application. It uses the original NativeScript 9.1.1 runtime and @nativescript/core 9.1.4 already shipped by that application. No engine or duplicate host implementation is included.

## Use

Import FileWorkshop.hanlinNativeScript using the original Add / Import interface in Hanlin MiniApps. Open the source document or note in Maktabah or Anytype, choose MiniApps, then File Workshop.

Choose a supplied attachment to read its actual bytes. UTF-8 text files can be edited. Other files can be renamed and returned without changing their bytes. **New text file** starts from the source selection or supplied text. **Return file** writes the chosen bytes through the shared Bridge and completes the actual request. **Cancel** cancels only this request. Each open native window captures its own host services and document context.

The result operation is insert. A source app that supports native file blocks inserts an attachment using its own editor services. The MiniApp does not write the source document, fabricate callback records, or acknowledge results. The source app remains responsible for its durable save and replay handling.

## Build and evidence

Run python3 build.py to create the deterministic installable archive and its PACKAGE.json hashes. Run node --check source/nativescript/app/bundle.mjs to validate JavaScript syntax.

Native runtime execution, two-app byte round trips, Hebrew/English layout, cold reopen, and duplicate callbacks require the actual applications. PACKAGE.json deliberately says NOT_RUN until separate native evidence is recorded; packaging is not acceptance.

The original Bridge and source editor byte/archive limits remain in force. This package adds no independent attachment count limit. Invalid UTF-8 is kept as an unchanged binary attachment.
