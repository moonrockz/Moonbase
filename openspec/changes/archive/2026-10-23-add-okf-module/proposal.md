# Proposal

## Why

Teams keep knowledge bases in the Open Knowledge Format (OKF v0.2): directories of Markdown concepts with YAML frontmatter. finos/morphir processes its OKF knowledge base with Rust crates (`morphir-okf`, `morphir-kb`) and a `kb` agent skill. No MoonBit library can read, query or edit OKF. `moonrockz/mdc` gives the syntax layer, but it has no OKF rules. A MoonBit OKF library lets MoonBit tools and finos/morphir-moonbit do every OKF task that morphir does today, on all four MoonBit targets.

The OKF specification does not define how to store, index, search or extend a knowledge base. The library must therefore expose these concerns as trait-based providers, so that later work can add storage providers such as SQLite and RocksDB without changes to the core.

## What Changes

- Add a new published module, `moonrockz/okf`, in `pkgs/okf`, built on `moonrockz/mdc`.
- Model OKF v0.2 bundles: concepts, Concept IDs, reserved `index.md` and `log.md` files, typed frontmatter (provenance, trust, lifecycle, Attested Computation), unknown keys kept in order, derived trust tier and staleness.
- Extract, classify and resolve body links. Build a link graph with outbound links, backlinks, orphans, broken links and cross-bundle links.
- Parse and generate `index.md` and `log.md`. Check index coverage and description drift.
- Query and search concepts with facets.
- Report validation results as findings with severity, rule, path and line. Ship the OKF v0.2 conformance rules.
- Edit documents as pure text transformations that keep all other bytes: set and remove frontmatter keys, insert and refresh index entries, add log entries, regenerate marked regions and create concepts from templates.
- Define providers as traits. Storage, index and search providers are async, so that they can do I/O on native, wasm and js. The link resolver, clock and profile are synchronous. Ship in-memory providers on all targets.
- Ship filesystem storage providers: one for native and wasm, and two for js, one for Node.js (`node:fs/promises`) and one for browsers (the File System Access API, including the origin private file system).
- Keep the core pure and synchronous over loaded documents, so that it works on all four targets, including wasm-gc, which has no async runtime.
- Define a profile API. A profile adds vocabulary, document classification, metadata derivation, typed registers (record IDs, states, transitions, supersession) and check rules.
- Ship an OpenSpec profile. It reads an `openspec/` tree as an OKF bundle, defines native OKF types for OpenSpec artifacts, and imports from and exports to OpenSpec.
- Make the differences between the OKF v0.2 specification and existing tools configurable. The default follows the specification.
- Add acceptance suites and property laws under `tests/`. A morphir reference profile exists only in the tests, and checks the profile API against morphir's scenarios.

### Out of scope

- A shipped morphir profile. morphir defines its own profile with the profile API.
- Storage providers for SQLite, RocksDB or other databases. This change defines the traits that they implement.
- Synchronization of mirrored upstream documents (morphir `kb sync`: byte-exact injection and projection, lockfile, upstream states). A later change adds it.
- Commands in `apps/cli` and views in `apps/web` or `apps/desktop`.
- Git operations, such as provenance checks against `git rev-parse` output. A provider can add them later.
- LLM-based enrichment, Attested Computation execution and attester sandboxes.
- OKF specification changes. Open OKF issues (typed relations, wiki links) stay out until the specification accepts them.

## Capabilities

### New Capabilities

- `okf/documents`: Bundle discovery, document kinds, Concept IDs, typed frontmatter, unknown keys, trust tier, staleness and specification options.
- `okf/relationships`: Link extraction, classification and resolution, typed frontmatter references, and the link graph.
- `okf/indexes`: `index.md` and `log.md` models, index coverage and drift, and generated index content.
- `okf/queries`: Concept lookup, filters, facets and search through a search provider.
- `okf/validation`: Findings, rule sets and the OKF v0.2 conformance rules.
- `okf/editing`: Byte-preserving text edits to frontmatter, indexes, logs and generated regions, and concept creation.
- `okf/providers`: Provider traits for storage, indexes, search, link resolution and clocks, with in-memory providers and filesystem providers for native, wasm, Node.js and browsers.
- `okf/profiles`: The profile API: vocabulary, classification, metadata derivation, registers and profile rules.
- `okf/openspec`: The OpenSpec profile, native OpenSpec types, and import from and export to OpenSpec.

### Modified Capabilities

None.

## Impact

- **New published module:** `moonrockz/okf`. It depends on `moonrockz/mdc`, `moonbit-community/yaml` and `moonbitlang/async`. The js filesystem providers call Node.js and browser APIs through JavaScript FFI.
- **Affected published modules:** none change behavior. `moonrockz/mdc` gets a new dependent. If the OKF parser needs a change in `moonrockz/mdc` (for example, frontmatter errors as data), that change is a separate, compatible addition to `moonrockz/mdc`.
- **Workspace:** `moon.work`, both publish lists (`scripts/publish.mbtx`, `scripts/release.mbtx`), the Release workflow paths, `tests/moon.mod`, `README.md` and `AGENTS.md`.
- **Tests:** new suites `tests/okf-acceptance`, `tests/okf-laws` and `tests/okf-openspec-acceptance`, with fixtures from the OKF sample bundles and from the finos/morphir knowledge base (both Apache-2.0).
- **Consumers:** finos/morphir-moonbit can use the module, with its own morphir profile, in place of the Rust `morphir-okf` crate.
