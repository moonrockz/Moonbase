# Spec Delta

## MODIFIED Requirements

### Requirement: Browser filesystem store
The library SHALL ship a document store for the js target that uses the browser File System Access API. It SHALL take a directory handle from the caller, such as a handle that the user selected or the origin private file system root.

#### Scenario: Origin private file system
- **WHEN** a caller in a browser loads a bundle from the origin private file system root
- **THEN** the bundle contains the Markdown files under that root

#### Scenario: No write permission
- **WHEN** the directory handle does not allow writes and a caller applies a plan
- **THEN** the store reports a permission error and writes nothing

#### Scenario: Browser without createWritable
- **WHEN** a caller applies a plan to an origin private file system store in a browser that has no `createWritable()`, such as Safari 18
- **THEN** the store writes each changed document through a dedicated worker, and a later load reads the new content

### Requirement: Provider conformance tests
The library SHALL give a reusable set of conformance tests for each provider trait, so that a new provider, such as a SQLite index provider, can prove that it meets the contract. Every shipped provider SHALL pass them.

#### Scenario: Shipped stores pass
- **WHEN** the store conformance tests run against the in-memory, native, Node.js, browser and IndexedDB stores
- **THEN** all tests pass for each store

#### Scenario: Browser stores in three engines
- **WHEN** the browser checks run in Chromium, WebKit and Firefox
- **THEN** the browser store passes with each available write method, and the IndexedDB store passes, in each engine

## ADDED Requirements

### Requirement: Browser write method
The browser store SHALL write files with the write method that the caller selects: `createWritable()`, a dedicated worker that uses `createSyncAccessHandle()`, or automatic selection. Automatic selection SHALL be the default; it SHALL use `createWritable()` when the browser has it, and the worker otherwise.

#### Scenario: Automatic selection with createWritable
- **WHEN** a caller creates a browser store with the default write method in a browser that has `createWritable()`
- **THEN** the store writes with `createWritable()`

#### Scenario: Worker selected explicitly
- **WHEN** a caller creates an origin private file system store with the worker write method in a browser that has `createWritable()`
- **THEN** the store writes through the worker

### Requirement: Worker scope
The worker write method SHALL apply only to stores on the origin private file system, because a worker can open that root by itself. WHEN a caller selects the worker method for a handle that the user picked, the library SHALL refuse it with an error that names the reason.

#### Scenario: Worker with a picked directory
- **WHEN** a caller selects the worker write method for a store over a handle from `showDirectoryPicker()`
- **THEN** the store refuses the option and names the origin private file system as the requirement

### Requirement: Worker writes keep files whole
The worker SHALL replace the whole content of a file in one sync access handle session: open, truncate, write, flush and close. WHEN a write fails, the worker SHALL close the handle and report the failure to the store as a store error.

#### Scenario: Write replaces content
- **WHEN** the worker writes `# New` to a file that holds a longer text
- **THEN** a later read gives exactly `# New`

#### Scenario: Write failure
- **WHEN** the worker cannot open a sync access handle for a file
- **THEN** the store reports a store error that names the file, and no partial content remains

### Requirement: Packaged worker
The library SHALL build the worker code into the browser store package and start the worker from that code, so that a caller ships and serves no extra file. The store SHALL start at most one worker and SHALL reuse it for later writes.

#### Scenario: No extra file
- **WHEN** a page uses the worker write method
- **THEN** the page loads no worker file from the server

### Requirement: IndexedDB store
The library SHALL ship a document store for the js target that keeps files in IndexedDB. It SHALL keep each file under its store path in one object store of a database that the caller names, and it SHALL work in pages and in workers in every browser that has IndexedDB.

#### Scenario: Load after a write
- **WHEN** a caller writes `kb/index.md` and `kb/a.md` to an IndexedDB store and then loads the bundle at `kb`
- **THEN** the bundle contains both documents

#### Scenario: Separate databases
- **WHEN** two IndexedDB stores use different database names
- **THEN** a write to one store does not appear in the other

### Requirement: IndexedDB directories
The IndexedDB store SHALL derive directories from the paths of the files that it holds. A directory SHALL exist while at least one file is under it, and listing a directory that holds no file SHALL report `NotFound`.

#### Scenario: Directory disappears with its last file
- **WHEN** a caller deletes the only file under `kb/old/`
- **THEN** listing `kb` no longer shows `old`

### Requirement: IndexedDB errors
The IndexedDB store SHALL report a storage quota error, a blocked or failed database open, and a failed transaction as store errors that name the path, and it SHALL write nothing for an operation that fails.

#### Scenario: Quota exceeded
- **WHEN** a write exceeds the storage quota of the browser
- **THEN** the store reports a store error for that path, and the earlier content of the file stays
