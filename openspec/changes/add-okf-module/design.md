# Design

## Context

See `proposal.md` for the motivation and the scope. The specs under `specs/okf/` give the required behavior.

These facts from the current code and from research shape the approach:

- `moonrockz/mdc` parses Markdown with YAML frontmatter into an immutable `Document` with cursors, folds and source positions. `parse` raises `ParseError` for invalid frontmatter. It requires a closing delimiter after a first-line `---`.
- `moonbit-community/yaml` rejects duplicate keys. It reads unquoted scalars as `String`, `Integer`, `Real` or `Boolean`, and an `Integer` loses its source text (for example `007`). OKF needs scalar text as written.
- `moonbitlang/async` 0.22.5 runs its event loop on `native`, `wasm` and `js`, not on `wasm-gc`. Its `fs` package covers `native` and `wasm` only. Its `js_async` package wraps JavaScript promises (`run_promise`, `Promise::wait`). A probe showed that `async` trait methods work through trait objects on `native`, `wasm` and `js`.
- MoonBit has one `js` target. Node.js and browsers give different file APIs (`node:fs/promises` versus the File System Access API), so the library must select the runtime by package, not by target.
- The OKF v0.2 specification (`GoogleCloudPlatform/open-knowledge-format`, `SPEC.md`) does not define storage, indexing, search or extension. It leaves open the relative link base (issue #29), date-only timestamps (#24) and typed relations (#16).
- finos/morphir implements OKF in `morphir-okf` (model, frontmatter, filesystem loading) and `morphir-kb` (checks, indexes, SQLite index, scaffolding, registers, sync). Its storage is a set of filesystem functions, not an abstraction. All its writes are line-level text edits that keep CRLF. Its current time is always a parameter.

## Goals / Non-Goals

**Goals:**

- A pure, synchronous core that works on all four targets and reads no clock, file or environment.
- Async storage, index and search providers on `native`, `wasm` and `js`, including Node.js and browsers on `js`.
- Every extension point as a trait, with in-memory implementations, so that tests need no I/O and later providers plug in without core changes.
- Coverage of each morphir scenario in the specs, proven by a morphir reference profile in the tests.
- Edits that change only the intended bytes.

**Non-Goals:**

- Byte-for-byte equality with the morphir CLI text or JSON output. The library gives values; renderers belong to tools.
- Async providers on `wasm-gc`. It has no async runtime; `wasm-gc` callers use the synchronous core with in-memory documents.
- A query language. Queries are typed API calls; an index provider can add its own query language later.

## Decisions

### D1. One module, several packages

`moonrockz/okf` in `pkgs/okf`, version equal to the workspace version, with these packages:

| Package | Contents | Targets |
| --- | --- | --- |
| `moonrockz/okf` | Model, frontmatter, options, links, graph, index and log models, queries, validation, provider and profile traits | all |
| `moonrockz/okf/edit` | Text edits and edit plans | all |
| `moonrockz/okf/provider` | Async provider traits, store loading and plan application | native, wasm, js |
| `moonrockz/okf/memory` | In-memory document store, index provider and search provider | all (async parts: native, wasm, js) |
| `moonrockz/okf/conformance` | Reusable provider conformance tests | native, wasm, js |
| `moonrockz/okf/fs` | Filesystem store over `moonbitlang/async/fs` | native, wasm |
| `moonrockz/okf/fs/node` | Filesystem store over `node:fs/promises` | js |
| `moonrockz/okf/fs/browser` | Store over the File System Access API | js |
| `moonrockz/okf/openspec` | OpenSpec profile, import and export | all |

The synchronous traits (`LinkResolver`, `Clock`, `Profile`) and the `FixedClock` live in the core package. The async traits live in `moonrockz/okf/provider`, so that the core keeps no dependency on the async runtime and builds on `wasm-gc`. Alternative: one package per concern (`okf/links`, `okf/graph`). Rejected for now: these concerns share the document model closely, and splitting them adds public surface without a consumer. Alternative: several modules. Rejected: one version and one publish entry are simpler, and consumers import packages selectively.

### D2. Build on `moonrockz/mdc`, with a frontmatter span scanner

The core uses `moonrockz/mdc` for the Markdown tree, headings, links and positions. It catches `ParseError` and stores it as document data. A small scanner over the raw frontmatter text finds each top-level key with its value span, line and source text. Typed access uses the YAML mapping; raw scalar text and all frontmatter edits use the spans.

Alternative: change the YAML library to keep scalar text. Rejected: it is an upstream dependency, and the spans are needed for byte-preserving edits anyway. If the OKF work needs a change in `moonrockz/mdc`, it is a separate, compatible addition there.

### D3. Pure synchronous core, async providers

The core is pure and synchronous. It works on an in-memory document set and takes only synchronous providers (`LinkResolver`, `Clock`, `Profile`), so it builds and runs on all four targets.

The I/O providers are async traits in `moonrockz/okf/provider`: `DocumentStore` (list, read, write, delete, modification time), `IndexProvider` and `SearchProvider`. Callers pass them as trait objects (`&DocumentStore`). `load(store, ...)` reads the documents into memory and then calls the core. `apply(plan, store)` writes the changed documents. This keeps the functional core and the imperative shell apart, as `AGENTS.md` requires.

Alternative: synchronous provider traits with async loading only at the edge. Rejected: SQLite, RocksDB, Node.js and browser storage all do I/O, and synchronous traits would force each of them to buffer everything first. Alternative: an async core. Rejected: it removes `wasm-gc` and makes pure functions harder to test.

### D3a. One package per js runtime

MoonBit has one `js` target, so the runtime is a package choice:

- `moonrockz/okf/fs/node` calls `node:fs/promises` through JavaScript FFI. It gets the module with `process.getBuiltinModule("node:fs/promises")`, so that it works in CommonJS and ESM output, and in Bun and Deno, which give the same API. It waits on each promise with `@js_async.Promise::wait`.
- `moonrockz/okf/fs/browser` takes a `FileSystemDirectoryHandle` from the caller: a handle from `showDirectoryPicker()` or the origin private file system root from `navigator.storage.getDirectory()`. It maps permission and missing-entry errors to store errors.
- `moonrockz/okf/fs` uses `moonbitlang/async/fs` on `native` and `wasm`.

All three stores pass the same conformance tests. The Node.js store is tested under Node.js in CI. The browser store is tested under Node.js with a small JavaScript fake of the File System Access API, and in headless Chromium with Playwright against the origin private file system.

Alternative: one `fs` package that detects the runtime on `js`. Rejected: the browser store needs a handle and a user permission that only the caller can get, and detection would hide which APIs a bundle needs.

### D4. Options record with specification defaults

An immutable `Options` value holds each configurable difference (relative link base, status default, nested logs, date-only timestamps, v0.1 field forms, whether index links count as backlinks). `Options::default()` follows OKF v0.2. A profile can supply its own options; the caller's options win over the profile's options.

### D5. Immutable bundle and graph values

Loading produces an immutable `Bundle`; discovery produces a `Knowledge` value with bundles, groups and strays. `Graph::build(knowledge, resolver, options)` computes all links, targets and backlinks once. Queries read these values. The in-memory index provider stores the same graph, so backlinks agree by construction, and the conformance tests check that other index providers agree too.

### D6. Profiles as trait implementations with data-driven registers

`Profile` is a trait whose methods all have defaults (no vocabulary, no classification, no registers, no rules). A register is a data value: type, ID rule (leading digits, width), states, transitions with obligation predicates, supersession fields and typed fields. Generic register code handles IDs, duplicates, ambiguity, transitions and supersession chains, so each profile adds data, not algorithms. Composition merges vocabularies and registers and reports conflicts.

Alternative: one fixed Intent and Decision model in the core. Rejected by the scope: morphir conventions belong in a morphir profile.

### D7. Validation as composable rule sets

A `Rule` has a name, a default severity and a check function over the knowledge, the graph and a clock. A `RuleSet` groups rules. The core ships `okf_v02_conformance()` and `advisory()` rule sets; profiles add theirs. The caller supplies severity overrides and turned-off rule names. Findings sort by severity, path and line.

### D8. Edits as pure text functions and plans

Each edit is `(text, arguments) -> EditResult { text, changed }`. Edits work on line spans, detect the line ending of the file, and reuse it. YAML quoting follows the morphir rules (`kb/util.rs`): quote when the plain scalar would read as another type or contains `: `, `#` or leading indicators. An `EditPlan` is an ordered list of file changes (create, update with old and new text, delete). Applying a plan to a store writes only changed files. A dry run renders the plan without a store.

### D9. In-memory search

The in-memory search provider ranks with BM25 over title, description, tags and body, with higher weights for title and description, as morphir's FTS5 ranking does. It breaks ties by bundle label and path, so results are deterministic. Snippets are the best-scoring body window with the matched terms marked.

### D10. OpenSpec profile and conversion

The profile classifies paths (`specs/**/spec.md`, `changes/<name>/{proposal,design,tasks}.md`, `changes/<name>/specs/**/spec.md`, `changes/archive/**`) and derives type, title and capability from them. It parses requirements, scenarios, delta operations and tasks from the Markdown headings and lists.

Import keeps each OpenSpec file body unchanged and adds frontmatter (`type`, `title`, `capability`, `change`), so that export can restore the original text. The native types `Requirement` and `Scenario` let authors write one concept per requirement; export merges them into the capability spec in order. The round-trip guarantee is on structured content, not on bytes, because a native bundle can hold content that OpenSpec formats differently.

### D11. Fixtures and the morphir reference profile

Fixtures come from the OKF sample bundles (`acme_retail`, `ga4`) and from a copy of the finos/morphir `kb/` tree, both Apache-2.0, with a README that names the source commit and license. The morphir reference profile lives in the `tests` module, uses only the public API, and defines the Intent and Decision Record registers and the morphir check rules. Its golden results come from the morphir CLI JSON output (`kb decision list --json`, `kb check --json`), recorded once at the fixture commit.

### D12. Workspace and release

Add `pkgs/okf` to `moon.work`, to both publish lists and to the Release workflow paths. Set its version with `scripts/versions.mbtx`. Add the test suites to `tests/moon.mod`. Update `README.md` and `AGENTS.md`.

## Risks / Trade-offs

- [The scope is large] → Deliver in vertical slices, one pull request each: documents, relationships, indexes and queries, validation, editing, providers, profiles, OpenSpec. Each slice has its own acceptance tests.
- [`moonrockz/mdc` requires a closing delimiter; morphir treats an unterminated block as no frontmatter] → Report an unterminated block as a frontmatter error, which the specification requires. A profile can lower the severity.
- [The YAML library types scalars and drops integer text] → The span scanner (D2) gives the source text; typed access is a view over it.
- [In-memory search and index do not scale to very large bundles] → The traits allow SQLite or RocksDB providers later, and the conformance tests define their contract.
- [OKF v0.2 will change (v0.3, typed relations)] → Options (D4) and version reporting isolate the differences; new fields arrive as profile vocabulary first.
- [The morphir golden files go stale when morphir changes] → Pin the fixture to one morphir commit, and update the fixture and the golden files together.
- [Trait objects cost a dynamic call per provider operation] → Provider calls happen at load and query boundaries, not in inner loops.
- [`process.getBuiltinModule` needs Node.js 20.16 or later] → mise pins Node.js 24; the store reports a clear error on older runtimes.
- [Browser tests need a real browser] → The JavaScript fake covers the contract on every CI run; the Playwright test covers the real API.

## Migration Plan

This change adds a new module and changes no existing behavior, so no migration is needed. The first release that contains `moonrockz/okf` publishes it to mooncakes.io; that version is permanent. To roll back before a release, revert the pull requests. After a release, fix forward with a new version.

## Open Questions

- Should the in-memory search provider support phrase and prefix queries in this change, or only terms? Terms are enough for the morphir scenarios; phrases can come with the SQLite provider.
