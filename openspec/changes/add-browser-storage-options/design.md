# Design

## Context

See `proposal.md` for the motivation. The delta in `specs/okf/providers/spec.md` gives the required behavior.

Current state and constraints:

- `moonrockz/okf/fs/browser` (`BrowserStore`) does every operation on the main thread through JavaScript FFI. Each call returns a settled `{ok, code, message, value}` object, and `settle` maps error names to `StoreError` values. Writes call `getFileHandle(name, {create: true})`, then `createWritable()`, `write` and `close`.
- Safari 15.2 to 18 can read, list and delete in the origin private file system on the main thread, but can write only with `FileSystemFileHandle.createSyncAccessHandle()`, which exists only in dedicated workers. Safari 26 adds `createWritable()`. One report says that Safari 26.5 keeps a temporary copy of each file that `createWritable()` writes; it is not confirmed.
- A worker can open the origin private file system root by itself with `navigator.storage.getDirectory()`. Whether every browser can send a `FileSystemDirectoryHandle` to a worker with `postMessage` is less certain, so the design does not depend on it.
- `moonbitlang/async` gives `@js_async.Promise::wait`, which the stores already use to wait on JavaScript promises.
- The browser checks (`tests/okf-browser`, `mise run test:browser`) run the store conformance checks in headless Chromium against the origin private file system.

## Goals / Non-Goals

**Goals:**

- Writes that work in every Safari version that has the origin private file system, with no change for callers who use the default.
- An IndexedDB store with the same `DocumentStore` contract, tested in three browser engines.
- Fallback behavior that is tested on every CI run, not only in a real browser.

**Non-Goals:**

- Worker-based reads, listings or deletes.
- Transactions over several files. Each `DocumentStore` operation stays independent, as it is in the other stores.

## Decisions

### D1. A write method option on `BrowserStore`

`BrowserStore::BrowserStore(handle, writes? : WriteMethod = Auto)` with `pub(all) enum WriteMethod { Auto; Writable; SyncAccessWorker }`. `Auto` checks once, at the first write, whether `FileSystemFileHandle.prototype.createWritable` exists, and keeps the answer for the life of the store.

Alternative: a separate `SafariStore` type. Rejected: it would duplicate reads, listings and deletes, and callers would have to detect the browser themselves.

### D2. The worker knows its root by path, not by handle

A store that can use the worker needs the path of its root below the origin private file system root. `BrowserStore::origin_private(path? : @okf.StoreDir = @okf.StoreDir::root(), writes?)` opens the root with `navigator.storage.getDirectory()`, walks `path` with `getDirectoryHandle(..., {create: true})`, and records the path. The worker receives the path segments of each write, opens the origin private root itself, and walks the same segments.

A store created from a caller's handle has no known path. With `SyncAccessWorker`, its first write raises `InvalidPath` with a message that names the origin private file system. With `Auto`, it uses `createWritable()` when it exists; a picked handle exists only in browsers that have `showDirectoryPicker()`, and those browsers have `createWritable()`.

Alternative: send the handle to the worker with `postMessage`. Rejected for now: support for serializable handles differs between engines, and the path approach works everywhere.

### D3. One packaged worker per page

The worker code is a JavaScript string in the browser package. The first worker write creates it with `new Worker(URL.createObjectURL(new Blob([code], {type: "text/javascript"})))` and keeps it in a module-level variable, so all stores of the page share one worker. Requests carry an ID; the worker answers with the same settled result objects as the main-thread calls, so `settle` and the error mapping do not change.

The worker writes a file in one session: `getFileHandle(name, {create: true})`, `createSyncAccessHandle()`, `truncate(0)`, `write(bytes, {at: 0})`, `flush()` and `close()`. Text is encoded with `TextEncoder`. A `finally` block closes the handle when any step fails.

A page with a strict Content Security Policy that forbids `blob:` workers cannot use the worker. The store then reports the `SecurityError` as a store error; the README states the `worker-src blob:` requirement.

Alternative: a separate worker file. Rejected: callers would have to serve it at a known URL, which breaks bundlers and static hosting.

### D4. The IndexedDB store keeps one record per file

New package `moonrockz/okf/idb`, js only. `IdbStore::open(database? : DatabaseName = DatabaseName::default(), object_store? : ObjectStoreName = ObjectStoreName::default()) -> IdbStore raise StoreError` opens or creates the database at version 1 and creates the object store with out-of-line keys. Each record has the key `<store path>` and the value `{kind: "text" | "bytes", data, modified}`, where `modified` is milliseconds from `Date.now()`.

- `list(dir)` reads the keys in the key range `[dir + "/", dir + "/￿")` (all keys for the root), takes the next path segment of each key, and marks a segment as a directory when the key continues after it. An empty result for a non-root directory raises `NotFound`.
- `read_text`, `read_bytes` and `modified` read one record; a missing record raises `NotFound`. `read_text` decodes a bytes record as UTF-8, and `read_bytes` encodes a text record, as `MemoryStore` does.
- `write_text`, `write_bytes` and `delete` each use one `readwrite` transaction, so a failed operation writes nothing. Deleting a missing key is not an error.
- Error names map to store errors: `QuotaExceededError` and `AbortError` to `Failed` with the path, a blocked or failed open to `Failed` for the database name.

The JavaScript code talks to IndexedDB through a small key-value adapter (`get`, `put`, `delete`, `keys`). The package ships two adapters: the IndexedDB one, and an in-memory one for tests outside a browser, so the listing and error logic is tested on every run under Node.js. The IndexedDB adapter itself is tested only in the Playwright checks.

Alternative: one record per directory with child lists. Rejected: every write would update several records, and key ranges already give listings.

### D5. Tests in three engines

- The stand-in handle (`memory_directory_handle`) gets a third argument, `with_writable : Bool`. Without `createWritable`, the store must use the worker; under Node.js there is no worker, so the stand-in also gets a `sync_writer` hook that the store uses in place of the worker. This tests the `Auto` selection and the worker protocol logic on every run.
- `tests/okf-browser` runs four checks: the browser store with `Writable` (where it exists), the browser store with `SyncAccessWorker`, the browser store with `Auto`, and the IndexedDB store. Each check uses its own directory or database name.
- `playwright.config.cjs` adds the `webkit` and `firefox` projects. `--install` installs `chromium webkit firefox` with their system libraries. A check that needs `createWritable` is skipped, not failed, in an engine that does not have it, and the report names the skip.

### D6. Domain types for the new values

Following the Domain types section of `AGENTS.md`:

- `@okf.StoreDir` is a directory path below a store root, with the same rules as `StorePath` (no escape, `/` and `\` as separators) but allowed to be the root. Its constructor `StoreDir::StoreDir(text) -> StoreDir raise PathError` parses once; `StoreDir::root()` cannot fail. It replaces the raw `ArrayView[String]` directory arguments where the browser store needs one. (A later change can use it in `DocumentStore::list`.)
- `DatabaseName` and `ObjectStoreName` are non-empty names. Their constructors raise `IdbNameError::Empty`; `default()` gives `okf` and `files` and cannot fail.
- `WriteMethod` is an enum, not a string option.
- The worker protocol keeps its operation as an enum on the MoonBit side and converts it to its JavaScript tag at the FFI boundary only.
- Each constructor has tests on each side of each rule.


## Risks / Trade-offs

- [WebKit in Playwright differs from Safari] → The README states that the WebKit check is an approximation; the fallback logic is also covered by the stand-in tests.
- [The Safari 26.5 temporary-copy report is unconfirmed] → `SyncAccessWorker` lets a caller avoid `createWritable()` without a library change.
- [Strict CSP pages cannot start a `blob:` worker] → Clear store error and a documented `worker-src blob:` requirement.
- [IndexedDB eviction under storage pressure] → The README recommends `navigator.storage.persist()` for data that must stay; the library does not call it, because it can show a prompt.
- [Three browsers make the CI job slower] → The job installs browsers once, caches `~/.cache/ms-playwright`, and runs the checks with one worker.

## Migration Plan

The default write method keeps the current behavior in browsers that have `createWritable()`, so no caller change is needed. The new package and constructor are additions. Rollback is a revert of the pull request.
