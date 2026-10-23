# Tasks

Each group is one story-sized slice and one pull request. Each group names its beads issue ID once one exists.

## 1. Module scaffold and fixtures

Beads: none yet.

- [x] 1.1 Create `pkgs/okf` with `moon.mod` (`moonrockz/okf`, workspace version, imports `moonrockz/mdc`, `moonbit-community/yaml` and `moonbitlang/async`) and the packages from design D1; verify `moon check --deny-warn` passes on all four targets, the core package has no `moonbitlang/async` import, and each package declares the targets from D1
- [x] 1.2 Add `pkgs/okf` to `moon.work`, both publish lists, the Release workflow paths and `scripts/versions.mbtx` tracking; verify `mise run validate` and `mise run test:scripts` pass
- [x] 1.3 Add fixtures under `tests/okf-fixtures/`: the OKF `acme_retail` and `ga4` sample bundles and a copy of the finos/morphir `kb/` tree, with a README that names each source commit and license; verify the files match the pinned commits
- [x] 1.4 Record the morphir golden files (`kb decision list --json`, `kb check --json`, `kb list --json`) at the fixture commit; verify they parse as JSON
- [x] 1.5 Add `pkgs/okf/README.md` and the `AGENTS.md` and `README.md` entries for the module; verify `mise run lint` passes

## 2. Documents (`okf/documents`)

Beads: none yet.

- [x] 2.1 Implement the frontmatter span scanner (design D2) with unit tests for top-level keys, value spans, lines, CRLF and comments; verify the package tests pass
- [x] 2.2 Implement the document model, document kinds, Concept IDs, assets and frontmatter errors as data; verify unit tests for reserved files at any depth and invalid YAML
- [x] 2.3 Implement typed OKF fields, lenient accessors, unknown keys in order, scalar source text, trust tier, status and staleness with a clock; verify unit tests for each field in the spec
- [x] 2.4 Implement `Options` with specification defaults and each option from the spec; verify unit tests for the status default and date-only `stale_after`
- [x] 2.5 Implement bundle loading from an in-memory document set, bundle discovery, groups, strays and OKF version reporting; verify against the `acme_retail` fixture and the morphir `kb list` golden file
- [x] 2.6 Add `tests/okf-acceptance` with the `okf/documents` scenarios and `tests/okf-laws` with laws for frontmatter (unknown keys and scalar text survive loading) and Concept IDs; verify `mise run test` passes on all four targets

## 3. Relationships (`okf/relationships`)

Beads: none yet.

- [x] 3.1 Implement link extraction (inline, reference, autolinks; no images; no code) with file line numbers, and link classification; verify unit tests from the spec
- [x] 3.2 Implement link resolution with the relative base option, fragments and escape detection, and the `LinkResolver` trait with the default resolver; verify unit tests for both bases
- [x] 3.3 Implement the link graph with outbound links, backlinks (relative and cross-bundle), broken links and orphans with the index-link choice; verify graph laws in `tests/okf-laws` (each resolved link has exactly one matching backlink)
- [x] 3.4 Implement typed references for `sources[].resource` and GitHub URL parts; verify unit tests
- [x] 3.5 Add the `okf/relationships` scenarios to `tests/okf-acceptance`; verify they pass

## 4. Indexes and queries (`okf/indexes`, `okf/queries`)

Beads: none yet.

- [x] 4.1 Implement the index model, the sub-index frontmatter rule, coverage and description drift; verify against the morphir fixture, where the golden `kb check` coverage and drift findings must match
- [x] 4.2 Implement index generation grouped by type with a subdirectory section, keeping `okf_version`; verify unit tests and a law that a generated index covers every concept
- [x] 4.3 Implement the log model, newest-first check, nested logs option and marked regions; verify unit tests
- [x] 4.4 Implement lookup by path, Concept ID, bundle label (with ambiguity) and path suffix; verify unit tests
- [x] 4.5 Implement filters, facets, text scan, outlines, body sections, code blocks and footnote citations, with one file line base; verify unit tests from the spec
- [x] 4.6 Add the `okf/indexes` and `okf/queries` scenarios to `tests/okf-acceptance`; verify they pass

## 5. Validation (`okf/validation`)

Beads: none yet.

- [x] 5.1 Implement findings, severity order, rules, rule sets, severity overrides, turned-off rules and the summary with strict mode; verify unit tests
- [x] 5.2 Implement the `okf_v02_conformance` rule set and the tolerated content rules; verify that the `acme_retail` and `ga4` fixtures report no conformance error
- [x] 5.3 Implement the advisory rule set; verify its findings for the morphir fixture match the matching findings in the golden `kb check` file
- [x] 5.4 Add the `okf/validation` scenarios to `tests/okf-acceptance`; verify they pass

## 6. Editing (`okf/editing`)

Beads: none yet.

- [x] 6.1 Implement edit results, line-ending detection and YAML scalar quoting (design D8); verify unit tests for LF, CRLF and each quoting case
- [x] 6.2 Implement frontmatter key set and remove; verify a law in `tests/okf-laws` that an edit changes only the target key line on generated documents
- [x] 6.3 Implement index entry add and refresh, target index selection, log entry add and region regeneration; verify unit tests and a law that a repeated edit reports no change
- [x] 6.4 Implement concept creation from templates with reserved, escaping and existing path refusal; verify unit tests
- [x] 6.5 Implement edit plans with dry-run rendering; verify a plan to add a concept contains the concept, the index entry and the log entry
- [x] 6.6 Add the `okf/editing` scenarios to `tests/okf-acceptance`; verify they pass

## 7. Providers (`okf/providers`)

Beads: none yet.

- [x] 7.1 Define the async `DocumentStore`, `IndexProvider` and `SearchProvider` traits in `moonrockz/okf/provider`, the synchronous `LinkResolver` and `Clock` traits in the core, store loading, plan application and path safety for both separators; verify unit tests for escaping paths and for a plan that writes only changed documents
- [x] 7.2 Implement the in-memory store in `moonrockz/okf/memory` and the fixed clock in the core, with synchronous access for `wasm-gc`; verify the in-memory round trip on `native`, `wasm` and `js`, and synchronous use on `wasm-gc`
- [x] 7.3 Implement the in-memory index provider (graph-backed, metadata, staleness) and the in-memory BM25 search provider with deterministic ties and snippets (design D9); verify unit tests
- [x] 7.4 Implement `moonrockz/okf/conformance` test suites for each async provider trait and run them against the in-memory providers; verify all pass on `native`, `wasm` and `js`
- [x] 7.5 Implement `moonrockz/okf/fs` over `moonbitlang/async/fs`; verify the store conformance tests on a temporary directory on `native` and `wasm`
- [x] 7.6 Implement `moonrockz/okf/fs/node` over `node:fs/promises` (design D3a); verify the store conformance tests under Node.js on a temporary directory
- [x] 7.7 Implement `moonrockz/okf/fs/browser` over the File System Access API with a caller-supplied directory handle; verify the store conformance tests under Node.js with a JavaScript fake of the API, including the permission error case
- [x] 7.8 Add a Playwright test that runs the browser store conformance tests in headless Chromium against the origin private file system, pin Playwright in `.config/mise/config.toml` and add the test to CI; verify the CI job passes
- [x] 7.9 Add the `okf/providers` scenarios to `tests/okf-acceptance` and document the stores and how to choose one in `pkgs/okf/README.md`; verify they pass

## 8. Profiles (`okf/profiles`)

Beads: none yet.

- [x] 8.1 Define the `Profile` trait with default methods, profile composition and conflict reports; verify unit tests for an empty profile and a conflicting key
- [x] 8.2 Implement vocabulary, classification, derived metadata and bundle configuration keys; verify unit tests
- [x] 8.3 Implement generic registers: record IDs with padding, duplicates, ambiguity, states, transitions with obligations, supersession chains and typed document references; verify unit tests and a law that supersession checks are symmetric
- [x] 8.4 Write the morphir reference profile in `tests/okf-acceptance` with the public API only (Intent and Decision Record registers and morphir check rules); verify its decision list and findings match the golden files
- [x] 8.5 Add the `okf/profiles` scenarios to `tests/okf-acceptance` and document the profile API in `pkgs/okf/README.md`; verify they pass

## 9. OpenSpec profile (`okf/openspec`)

Beads: none yet.

- [x] 9.1 Implement path classification and derived metadata for `openspec/` trees, including archived changes; verify against the `openspec/` tree of this repository
- [x] 9.2 Implement parsing of requirements, scenarios, delta operations and tasks, and the OpenSpec relationships; verify unit tests from the spec
- [x] 9.3 Implement the native OpenSpec types and the equal structured view; verify a law that both forms give equal views
- [x] 9.4 Implement the OpenSpec checks; verify that they report no finding for this repository's `openspec/` tree and match `openspec validate --strict` on crafted failures (the CLI defers the unknown-requirement and unknown-capability checks to archive time)
- [x] 9.5 Implement import and export as edit plans and the round trip (design D10); verify a law in `tests/okf-laws` and the round trip of this repository's `openspec/` tree, with the exported tree passing `openspec validate --all --strict`
- [x] 9.6 Add `tests/okf-openspec-acceptance` with the `okf/openspec` scenarios and document the profile in `pkgs/okf/README.md`; verify they pass

## 10. Integration

Beads: none yet.

- [x] 10.1 Run `mise run check` and `mise run test:scripts`; verify both pass with the module in the workspace
- [x] 10.2 Check every scenario in `specs/okf/` against a test that covers it; verify that no scenario lacks a test

## Workflow follow-up

- Archive the change after the pull requests merge and the review requirements are met.
- Release the module with the next workspace release.
