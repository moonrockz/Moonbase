# OKF

`moonrockz/okf` reads, queries, validates and edits knowledge bases in the
[Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format)
(OKF v0.2): directories of Markdown concepts with YAML frontmatter. It is built
on [`moonrockz/mdc`](../mdc/README.md).

OKF does not define how to store, index, search or extend a knowledge base, so
this module keeps those concerns behind provider traits and a profile API.

## Packages

| Package | Contents | Targets |
| --- | --- | --- |
| `moonrockz/okf` | Document model, frontmatter, links, link graph, indexes, logs, queries, search, validation, profiles | all |
| `moonrockz/okf/edit` | Text edits that keep every other byte, and edit plans | all |
| `moonrockz/okf/provider` | Async `DocumentStore`, `IndexProvider` and `SearchProvider` traits, loading and plan application | all (async: native, wasm, js) |
| `moonrockz/okf/memory` | In-memory store, index and search providers | all (async: native, wasm, js) |
| `moonrockz/okf/conformance` | Conformance checks for new providers | native, wasm, js |
| `moonrockz/okf/fs` | File system store | native, wasm |
| `moonrockz/okf/fs/node` | File system store over `node:fs/promises` (Node.js 20.16+, Bun, Deno) | js |
| `moonrockz/okf/fs/browser` | Store over the File System Access API | js |
| `moonrockz/okf/openspec` | OpenSpec profile, structured view, import and export | all |

## Load and query

The core is pure and synchronous. It works on a `DocumentSet` in memory, so it
runs on every target, including wasm-gc.

```moonbit
let set = @okf.DocumentSet::of_texts([
  ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
  ("kb/tables/orders.md", "---\ntype: BigQuery Table\ntitle: Orders\n---\nSee [customers](customers.md).\n"),
])
let knowledge = @okf.discover(set)            // every directory whose index.md has okf_version
let bundle = knowledge.bundles()[0]
let orders = bundle.concept(@okf.ConceptId("tables/orders")).unwrap()
orders.metadata().concept_type()               // Some("BigQuery Table")
orders.links()                                 // body links with file lines and kinds
let graph = @okf.Graph::build(knowledge)       // outbound links, backlinks, orphans, broken links
knowledge.filter([TypeIs("metric"), HasTag("finance")])
knowledge.facet("type")
@okf.search_knowledge(knowledge, @okf.SearchRequest("revenue", limit=10))
```

Typed accessors cover every OKF v0.2 field: `sources`, `usage_window`,
`generated`, `verified` (a single mapping reads as a list), `status`,
`stale_after`, and the Attested Computation fields. `trust_tier()` derives the
tier from `verified`, and `is_stale(now)` compares `stale_after` with an instant
that the caller supplies. Unknown keys keep their source order, and every scalar
keeps its source text, so dates and timestamps stay as written.

`Options::default()` follows OKF v0.2. `Options::update` changes each known
difference between the specification and existing tools: the relative link base,
the status default, nested logs, date-only instants, the v0.1 field forms, and
whether index links count as backlinks.

## Validate

```moonbit
let report = @okf.validate(
  knowledge,
  [@okf.okf_v02_conformance(), @okf.advisory()],
  @okf.FixedClock::at("2026-10-23T00:00:00Z"),
  config=@okf.ValidationConfig(overrides=[("link-broken", Error)], disabled=["duplicate-title"]),
)
report.findings()      // sorted by severity, bundle, path and line
report.fails(strict=true)
```

`okf_v02_conformance()` holds the OKF v0.2 section 11 rules. `advisory()` holds
rules that OKF tolerates, such as missing titles, broken links, stale concepts,
index coverage and description drift. The caller chooses their severities.

## Edit

Edits in `moonrockz/okf/edit` are pure: they take a text and return the new
text and whether it changed. They keep line endings, comments, key order and
quoting. Plans group edits until a caller applies them to a document set or a
store.

```moonbit
@edit.set_key(text, "status", "deprecated")
@edit.add_index_entry(index_text, "Metric", @edit.index_entry_line("Revenue", "/metrics/revenue.md"))
@edit.add_log_entry(log_text, "2026-10-23", "Added revenue.", label="Creation")
let plan = @edit.plan_add_concept(bundle, "/metrics/revenue.md", "Metric", "Revenue", "Net revenue per day", "2026-10-23")
plan.render()          // a dry run
```

## Stores, indexes and search

Storage, indexing and search are async traits in `moonrockz/okf/provider`.
`load(store)` reads documents into memory and then runs the core; `apply(plan,
store)` writes the changed documents.

| Runtime | Store |
| --- | --- |
| Tests, wasm-gc, any target | `@memory.MemoryStore` (its `snapshot()` is synchronous) |
| Native and wasm | `@fs.FsStore(root)` |
| Node.js, Bun, Deno | `@node.NodeStore(root)` |
| Browser | `@browser.BrowserStore(handle)`, with `@browser.origin_private_root()` or `@browser.pick_directory()` |

MoonBit has one js target, so choose the Node.js or the browser store by the
package you import. `@memory.MemoryIndex` implements `IndexProvider` and
`SearchProvider` (BM25 over title, description, tags and body). A new provider,
for example over SQLite or RocksDB, proves its contract with
`@conformance.check_store`, `check_index` and `check_search`.

## Profiles

A profile adds conventions to OKF without changes to this module. Implement
`@okf.Profile`; every method has a default.

| Method | Adds |
| --- | --- |
| `vocabulary`, `bundle_keys` | Known frontmatter keys |
| `derive_metadata` | Metadata for a document without frontmatter |
| `registers` | Typed views of one concept type: record IDs, states, transitions with obligations, supersession |
| `reference_fields` | Fields whose values name documents or records |
| `templates` | Bodies for new concepts |
| `rule_sets`, `severities` | Validation rules and their preferred severities |
| `relations` | Links that a document implies |
| `options` | Preferred options |

`profile_conflicts` reports two profiles that define one key or register
differently. The tests hold a morphir reference profile, written with this API
only, that reproduces `morphir kb check` and `morphir kb decision list` on a copy
of the finos/morphir knowledge base.

## OpenSpec

`@openspec.OpenSpecProfile` reads an `openspec/` tree as a bundle. It derives
the types `Specification`, `Change` (the change's `proposal.md`), `Design`,
`Tasks` and `Spec Delta`, links changes to their capabilities, and adds checks:
the three that `openspec validate --strict` runs (a requirement without a
scenario, without `SHALL` or `MUST`, or with a wrong scenario heading) and two
that OpenSpec runs only at archive time (a `MODIFIED` or `REMOVED` requirement
that matches nothing, and a delta for a capability that does not exist). `@openspec.view(bundle)` gives
requirements, scenarios, deltas and tasks. Native bundles can also use
`Requirement` and `Scenario` concepts.

`import_openspec` plans a native OKF bundle from a tree, and `export_openspec`
plans the tree again; the round trip keeps every file.
