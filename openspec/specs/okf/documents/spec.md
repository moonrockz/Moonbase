# okf/documents Specification

## Purpose
Read OKF v0.2 bundles into immutable values: bundles, concepts, reserved files, typed frontmatter and derived trust and lifecycle facts, with every unknown key kept.

## Requirements

### Requirement: Bundle loading
WHEN a caller loads a bundle from a set of documents in memory or from a document store, the library SHALL return an immutable bundle that contains every Markdown file under the bundle root, each with its bundle-relative path and its document kind.

#### Scenario: Load a bundle
- **WHEN** a document set holds `index.md`, `log.md`, `tables/customers.md` and `metrics/revenue.md` under one root
- **THEN** the bundle contains four documents with the paths `/index.md`, `/log.md`, `/tables/customers.md` and `/metrics/revenue.md`

#### Scenario: Later changes do not reach the bundle
- **WHEN** a caller loads a bundle and then changes the document set
- **THEN** the loaded bundle and its documents stay unchanged

### Requirement: Document kinds
The library SHALL classify each file named `index.md` as an index, each file named `log.md` as a log, and each other Markdown file as a concept. It SHALL separate the root index from the sub-indexes.

#### Scenario: Reserved files at any depth
- **WHEN** a bundle holds `/index.md`, `/tables/index.md` and `/tables/log.md`
- **THEN** `/index.md` is the root index, `/tables/index.md` is a sub-index, `/tables/log.md` is a log, and none of them is a concept

#### Scenario: Non-Markdown files
- **WHEN** a bundle holds `/computations/revenue.py`
- **THEN** the bundle lists it as an asset, and it is not a concept

### Requirement: Concept IDs
The library SHALL give each concept a Concept ID equal to its bundle-relative path without the `.md` extension. A Concept ID SHALL compare equal only to the same path.

#### Scenario: Concept ID from path
- **WHEN** a bundle holds `/tables/customers.md`
- **THEN** the concept has the Concept ID `tables/customers`

### Requirement: Bundle discovery under a root
WHEN a caller discovers bundles under a directory, the library SHALL return each directory whose `index.md` frontmatter contains `okf_version` as one bundle. It SHALL not search inside a bundle that it found, and it SHALL report Markdown files that belong to no bundle as strays.

#### Scenario: Grouped bundles
- **WHEN** `bundles/morphir/ir/index.md` and `bundles/morphir/cli/index.md` each declare `okf_version: "0.2"`
- **THEN** discovery returns two bundles with the group `morphir` and the labels `morphir/ir` and `morphir/cli`

#### Scenario: Stray file
- **WHEN** `bundles/notes.md` is in no bundle
- **THEN** discovery reports `bundles/notes.md` as a stray

### Requirement: Frontmatter parse results
The library SHALL parse the frontmatter of each document and keep the result as data. WHEN the frontmatter is invalid, the library SHALL keep the document, record the error with its line and column, and continue with the other documents.

#### Scenario: Invalid YAML
- **WHEN** `/tables/orders.md` has frontmatter with invalid YAML at line 3
- **THEN** the bundle contains the document with a frontmatter error at line 3, and the other documents load normally

#### Scenario: Duplicate keys
- **WHEN** a frontmatter block contains the key `title` two times
- **THEN** the document has a frontmatter error that names the duplicate key

#### Scenario: No frontmatter block
- **WHEN** a concept file does not start with a frontmatter block
- **THEN** the document has no frontmatter and no frontmatter error

### Requirement: Typed OKF fields
The library SHALL give typed access to the OKF v0.2 fields `type`, `title`, `description`, `resource`, `tags`, `sources`, `usage_window`, `generated`, `verified`, `status`, `stale_after`, `runtime`, `parameters`, `computation`, `executor` and `attester`.

#### Scenario: Read sources
- **WHEN** a concept has `sources` with one entry that has `id: ga4-schema` and `resource: https://example.com/schema`
- **THEN** the typed sources contain one source with that id and resource

#### Scenario: Bare verified mapping
- **WHEN** a concept has `verified: {by: "human:jsmith", at: "2026-06-30T14:00:00Z"}`
- **THEN** the typed verified value is a list with one entry

#### Scenario: Title fallback
- **WHEN** `/metrics/revenue.md` has no `title`
- **THEN** its display title is `revenue`

### Requirement: Unknown keys and scalar text
The library SHALL keep every frontmatter key in source order, including keys that OKF does not define. It SHALL keep the source text of each scalar value, so that timestamps and dates stay as written.

#### Scenario: Extension key
- **WHEN** a concept has the key `owner_team: data-platform`
- **THEN** the frontmatter exposes `owner_team` with the value `data-platform` in its source position

#### Scenario: Timestamp text
- **WHEN** a concept has `stale_after: 2026-09-01T00:00:00Z`
- **THEN** the raw value is the string `2026-09-01T00:00:00Z`

### Requirement: Lenient accessors
The library SHALL give lenient accessors that read a frontmatter value as text, as a list of text, as a Boolean, as an integer or as a list of mappings. WHEN a list accessor reads a scalar, it SHALL return a list with that one value.

#### Scenario: Scalar read as a list
- **WHEN** a caller reads `tags: finance` as a list
- **THEN** the result is the list `["finance"]`

### Requirement: Trust tier
The library SHALL derive the trust tier of a concept from `verified` only: unverified when `verified` is absent, machine-confirmed when no verifier starts with `human:`, and human-reviewed when one verifier starts with `human:`.

#### Scenario: Human verifier
- **WHEN** `verified` has the verifiers `okf-agent/0.2` and `human:jsmith`
- **THEN** the trust tier is human-reviewed

#### Scenario: No verifier
- **WHEN** a concept has no `verified` key
- **THEN** the trust tier is unverified

### Requirement: Lifecycle status and staleness
The library SHALL read `status` as `draft`, `stable`, `deprecated` or an unknown value. WHEN a caller supplies the current instant, the library SHALL report a concept as stale when that instant is at or after `stale_after`.

#### Scenario: Stale concept
- **WHEN** a concept has `stale_after: 2026-09-01T00:00:00Z` and the caller supplies `2026-09-02T00:00:00Z`
- **THEN** the concept is stale

#### Scenario: Unknown status
- **WHEN** a concept has `status: archived`
- **THEN** the status is unknown with the text `archived`

### Requirement: Specification options
The library SHALL follow OKF v0.2 by default and SHALL expose an option for each known difference between the specification and existing tools: the relative link base, the status default, nested `log.md` files, date-only `stale_after` values and the v0.1 field forms.

#### Scenario: Default status
- **WHEN** a concept has no `status` and the caller uses the default options
- **THEN** the effective status is `stable`

#### Scenario: Status default turned off
- **WHEN** a concept has no `status` and the options set no status default
- **THEN** the effective status is absent

#### Scenario: Date-only stale_after
- **WHEN** a concept has `stale_after: 2026-09-01` and the options accept date-only values
- **THEN** the concept is stale from the start of `2026-09-01` in UTC

### Requirement: OKF version
The library SHALL read `okf_version` from the root index frontmatter. WHEN a bundle declares a version that the library does not know, the library SHALL load the bundle with best effort and SHALL report the version.

#### Scenario: Unknown version
- **WHEN** the root index has `okf_version: "0.3"`
- **THEN** the bundle loads and reports the OKF version `0.3`
