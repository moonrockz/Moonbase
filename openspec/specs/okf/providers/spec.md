# okf/providers Specification

## Purpose
Keep storage, indexing, search, link resolution and time out of the OKF core. Callers plug these in as providers, so that later work can add providers such as SQLite or RocksDB without changes to the core.

## Requirements

### Requirement: Pure synchronous core
The library SHALL do all parsing, modeling, linking, querying, validation and editing as pure, synchronous operations over documents that are already in memory. These operations SHALL work on the wasm, wasm-gc, js and native targets.

#### Scenario: wasm-gc without providers
- **WHEN** a caller on wasm-gc builds an in-memory document set and loads it
- **THEN** the caller can query, validate and edit the bundle with no async call

### Requirement: Async document store
The library SHALL read and write documents through an async document store provider. A store SHALL list the entries under a path, each marked as a file or a directory, in a stable order; read the text or bytes of a file; write text or bytes and create missing parent directories; delete a file; and report the modification time of a file.

#### Scenario: Stable listing
- **WHEN** a caller loads the same store two times
- **THEN** both loads see the files in the same order

#### Scenario: Read failure
- **WHEN** a store cannot read a file
- **THEN** loading reports a store error that names the file

#### Scenario: Delete a missing file
- **WHEN** a caller deletes a file that does not exist
- **THEN** the store reports no error

### Requirement: Loading and applying through a store
WHEN a caller loads from a store, the library SHALL read the documents into memory first and then run the pure core. WHEN a caller applies an edit plan, the library SHALL write each changed document and SHALL write no unchanged document.

#### Scenario: Apply a plan
- **WHEN** a caller applies a plan that changes two documents and leaves a third unchanged
- **THEN** the store receives two writes

### Requirement: Path safety
The library SHALL refuse a path that escapes the root of a store. It SHALL treat `/` and `\` as the same separator when it checks a path.

#### Scenario: Escape with backslash
- **WHEN** a caller writes to `..\outside.md`
- **THEN** the library refuses the write

### Requirement: Async index provider
The library SHALL define an async index provider that builds a derived index from loaded bundles, reports whether the index is fresh, and answers queries about documents, frontmatter values, tags, links, backlinks, headings and sources.

#### Scenario: Stale index
- **WHEN** a document changes after the index was built
- **THEN** the index provider reports the index as stale

#### Scenario: Backlinks from the index
- **WHEN** a caller asks the index provider for the backlinks of a concept
- **THEN** the result equals the backlinks of the link graph for the same bundles

### Requirement: Index metadata
An index provider SHALL record the schema version, the build instant from the clock provider, and the document count, and SHALL report them on request.

#### Scenario: Metadata
- **WHEN** a caller builds an index with a clock fixed at `2026-10-23T00:00:00Z`
- **THEN** the index reports that build instant and the number of documents

### Requirement: Async search provider
The library SHALL define an async search provider that takes a search request and returns ranked results. The same request SHALL give the same results from the same index.

#### Scenario: Repeat search
- **WHEN** a caller sends the same request two times to the same provider
- **THEN** both results are equal

### Requirement: Synchronous providers
The link resolver and the clock SHALL be synchronous providers, so that the pure core can use them on every target. The library SHALL ship a default link resolver and a fixed clock for tests.

#### Scenario: Fixed clock
- **WHEN** a caller uses a fixed clock at `2026-10-23T00:00:00Z`
- **THEN** every staleness result uses that instant

### Requirement: In-memory providers
The library SHALL ship an in-memory document store, index provider and search provider. Their async interfaces SHALL work on the wasm, js and native targets, and their contents SHALL be available to the synchronous core on every target.

#### Scenario: In-memory round trip
- **WHEN** a caller writes a document to the in-memory store and loads the store
- **THEN** the loaded bundle contains that document

### Requirement: Native and wasm filesystem store
The library SHALL ship a filesystem document store for the native and wasm targets.

#### Scenario: Load a directory
- **WHEN** a caller on native loads a bundle directory through the filesystem store
- **THEN** the bundle contains the Markdown files of that directory

### Requirement: Node.js filesystem store
The library SHALL ship a filesystem document store for the js target that uses the Node.js file system API. It SHALL work in Node.js and in runtimes that give the same API.

#### Scenario: Load in Node.js
- **WHEN** a caller in Node.js loads a bundle directory through the Node.js store
- **THEN** the bundle contains the Markdown files of that directory

### Requirement: Browser filesystem store
The library SHALL ship a document store for the js target that uses the browser File System Access API. It SHALL take a directory handle from the caller, such as a handle that the user selected or the origin private file system root.

#### Scenario: Origin private file system
- **WHEN** a caller in a browser loads a bundle from the origin private file system root
- **THEN** the bundle contains the Markdown files under that root

#### Scenario: No write permission
- **WHEN** the directory handle does not allow writes and a caller applies a plan
- **THEN** the store reports a permission error and writes nothing

### Requirement: Provider conformance tests
The library SHALL give a reusable set of conformance tests for each provider trait, so that a new provider, such as a SQLite index provider, can prove that it meets the contract. Every shipped provider SHALL pass them.

#### Scenario: Shipped stores pass
- **WHEN** the store conformance tests run against the in-memory, native, Node.js and browser stores
- **THEN** all tests pass for each store
