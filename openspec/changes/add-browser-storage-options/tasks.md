# Tasks

Each group is one story-sized slice. Each group names its beads issue ID once one exists.

## 1. Browser write method and worker fallback

Beads: none yet.

- [ ] 1.0 Add `@okf.StoreDir`, `DatabaseName` and `ObjectStoreName` with smart constructors and tests on each side of each rule (design D6); verify the unit tests
- [ ] 1.1 Add `WriteMethod` (`Auto`, `Writable`, `SyncAccessWorker`) and the `writes` option to `BrowserStore::BrowserStore`, with `Auto` as the default and the selection cached at the first write (design D1); verify unit tests for the selection with the stand-in handle with and without `createWritable`
- [ ] 1.2 Add `BrowserStore::origin_private(path, writes)`, which records its path below the origin private file system root, and refuse `SyncAccessWorker` for a store without a known path with `InvalidPath` (design D2); verify a unit test for the refusal and its message
- [ ] 1.3 Implement the packaged worker: a JavaScript string started from a `blob:` URL once per page, with request IDs, the settled result objects, and one sync access handle session per write that closes the handle on failure (design D3); verify the stand-in `sync_writer` tests for replace-whole-content and write failure
- [ ] 1.4 Run the store conformance checks against the browser store with each write method on the stand-in handle; verify they pass under Node.js
- [ ] 1.5 Document the write methods, the Safari versions, and the `worker-src blob:` requirement in `pkgs/okf/README.md`; verify `mise run lint` passes

## 2. IndexedDB store

Beads: none yet.

- [ ] 2.1 Create `pkgs/okf/idb` (`moonrockz/okf/idb`, js only) with the key-value adapter interface, the IndexedDB adapter and the in-memory adapter (design D4); verify `moon check --deny-warn --target js`
- [ ] 2.2 Implement `IdbStore` over the adapter: listings from key ranges, derived directories, reads, writes and deletes in single transactions, and the error mapping; verify unit tests with the in-memory adapter for listings, a directory that disappears with its last file, separate databases and a failed write that keeps the earlier content
- [ ] 2.3 Run the store conformance checks against `IdbStore` with the in-memory adapter; verify they pass under Node.js
- [ ] 2.4 Add the IndexedDB store to the store table and the README of `moonrockz/okf`, with the advice on `navigator.storage.persist()`; verify `mise run lint` passes

## 3. Browser checks in three engines

Beads: none yet.

- [ ] 3.1 Extend `tests/okf-browser` to run four checks (browser store with `Writable`, `SyncAccessWorker` and `Auto`, and the IndexedDB store), each in its own directory or database, and to report a check that needs a missing API as skipped; verify `mise run test:browser` passes in Chromium
- [ ] 3.2 Add the `webkit` and `firefox` projects to `tests/okf-browser/playwright.config.cjs`, and install all three browsers with `--install`; verify `mise run test:browser -- --install` passes in all three engines locally
- [ ] 3.3 Update the `Test browser` CI job name and cache for three engines; verify the job passes on the pull request

## 4. Integration

Beads: none yet.

- [ ] 4.1 Run `mise run check`, `mise run test:scripts` and `openspec validate --all --strict`; verify all pass
- [ ] 4.2 Check every scenario of the delta spec against a test that covers it; verify that no scenario lacks a test

## Workflow follow-up

- Archive the change after the pull request merges.
