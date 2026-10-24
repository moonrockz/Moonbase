# Proposal

## Why

The browser store of `moonrockz/okf` (`moonrockz/okf/fs/browser`) writes files with `FileSystemFileHandle.createWritable()`. Safari added that method only in Safari 26. Safari 15.2 to 18 can write to the origin private file system only through `createSyncAccessHandle()`, which works only in a dedicated worker. One report also says that Safari 26.5 keeps a temporary copy of each file that `createWritable()` writes. So the browser store cannot write in most Safari versions in use today.

Some applications also need browser storage that does not depend on the File System Access API at all, and that works the same way in every browser and in workers. IndexedDB gives that.

## What Changes

- The browser store gets a write method option: `createWritable()`, a dedicated worker that writes with `createSyncAccessHandle()`, or automatic selection. Automatic selection uses `createWritable()` when it exists and the worker otherwise. Reads, listings and deletes do not change.
- The worker method applies to stores on the origin private file system. The library builds the worker code into the package, so callers ship no extra file.
- Add an IndexedDB document store, `moonrockz/okf/idb`, for the js target. It keeps each file under its store path in one IndexedDB object store, and it works in every browser and in workers.
- The stand-in File System Access API handle gets a mode without `createWritable()`, so the fallback is tested on every run.
- The Playwright browser checks run in Chromium, WebKit and Firefox, for the browser store with each write method and for the IndexedDB store.

### Out of scope

- A Safari replacement for `showDirectoryPicker()`. Safari has none, so a Safari user can use only the origin private file system or the IndexedDB store.
- Moving reads, listings or deletes into the worker.
- Migration of data between the browser store and the IndexedDB store.
- Testing on a real Safari browser. WebKit in Playwright is close to Safari, but it is not the same browser.
- Changes to the native, wasm and Node.js stores.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `okf/providers`: The browser store requirement adds the write method option and the worker fallback. A new requirement adds the IndexedDB store, and the conformance requirement adds it to the stores that must pass.

## Impact

- **Affected published module:** `moonrockz/okf` only. The packages `moonrockz/okf/fs/browser` (new option, compatible default) and the new `moonrockz/okf/idb` change. No other published module changes.
- **API:** `BrowserStore::BrowserStore(handle, writes?)` keeps its current behavior when the caller gives no option, except that it now writes through the worker when `createWritable()` is missing. A new constructor creates an origin private store with a path from the root.
- **Tests:** `tests/okf-browser` runs in three browsers. CI installs WebKit and Firefox for Playwright in addition to Chromium.
- **Dependencies:** none new.
