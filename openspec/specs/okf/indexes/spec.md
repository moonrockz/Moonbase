# okf/indexes Specification

## Purpose
Read and write the OKF navigation files, `index.md` and `log.md`, and check that the indexes cover the concepts and describe them correctly.

## Requirements

### Requirement: Index model
The library SHALL parse an `index.md` body into sections, each with its heading and its entries. Each entry SHALL have its link text, its link destination, its description and its line number.

#### Scenario: Index entries
- **WHEN** an index has `# Tables` followed by `* [Customers](/tables/customers.md) - One row per customer`
- **THEN** the section `Tables` has one entry with the text `Customers`, the destination `/tables/customers.md` and the description `One row per customer`

#### Scenario: Line that is not an entry
- **WHEN** an index section contains a paragraph of prose
- **THEN** the paragraph is kept as section text and is not an entry

### Requirement: Index frontmatter rule
The library SHALL accept frontmatter only on the root index, and only to hold `okf_version` and profile-defined bundle keys. It SHALL report frontmatter on a sub-index.

#### Scenario: Sub-index with frontmatter
- **WHEN** `/tables/index.md` has a frontmatter block
- **THEN** the library reports that a sub-index has frontmatter

### Requirement: Index coverage
The library SHALL report each concept that no index in its bundle links to.

#### Scenario: Concept not indexed
- **WHEN** `/metrics/revenue.md` exists and no `index.md` in the bundle links to it
- **THEN** the library reports `/metrics/revenue.md` as not indexed

### Requirement: Description drift
The library SHALL report each index entry whose description differs from the `description` of its target concept. The comparison SHALL ignore letter case, runs of white space and one trailing full stop.

#### Scenario: Drift
- **WHEN** the entry says `One row per customer` and the concept says `One row for each customer.`
- **THEN** the library reports description drift for that entry

#### Scenario: Case and full stop only
- **WHEN** the entry says `one row per customer` and the concept says `One row per customer.`
- **THEN** the library reports no drift

### Requirement: Index generation
WHEN a bundle has no `index.md`, or a caller asks for one, the library SHALL generate index content that groups the concepts of a directory by `type`, with one entry for each concept and a section for the subdirectories.

#### Scenario: Generated index
- **WHEN** a directory has two concepts of type `Metric` and one of type `BigQuery Table`
- **THEN** the generated index has a `Metric` section with two entries and a `BigQuery Table` section with one entry

#### Scenario: Root index keeps its version
- **WHEN** the library generates the root index of a bundle that declares `okf_version: "0.2"`
- **THEN** the generated root index keeps `okf_version: "0.2"`

### Requirement: Log model
The library SHALL parse a `log.md` body into dated sections, newest first, each with its date and its entries. It SHALL read the bold first word of an entry, such as `**Update**`, as the entry label when it is present.

#### Scenario: Log entries
- **WHEN** a log has `## 2026-10-20` with `* **Update**: Added revenue metric.`
- **THEN** the section dated `2026-10-20` has one entry with the label `Update` and the text `Added revenue metric.`

#### Scenario: Dates out of order
- **WHEN** a log has `## 2026-09-01` before `## 2026-10-20`
- **THEN** the library reports that the log is not newest first

### Requirement: Nested logs
The library SHALL load a `log.md` at any depth by default. WHEN the options select root logs only, the library SHALL ignore nested logs and SHALL report each one that it ignores.

#### Scenario: Nested log with root-only option
- **WHEN** `/tables/log.md` exists and the options select root logs only
- **THEN** the bundle has no log for `/tables` and the library reports the ignored file

### Requirement: Generated regions
The library SHALL find the regions of a document that a marker comment starts, such as `<!-- kb:sources -->`, and SHALL give the text of each region apart from the hand-written text around it.

#### Scenario: Marker region
- **WHEN** an index has a preamble, then `<!-- intent:index -->`, then generated entries
- **THEN** the region for `intent:index` contains only the generated entries

### Requirement: Dated log headings
The library SHALL treat a log section heading as dated only when it is a real calendar date in the form `YYYY-MM-DD`. A heading such as `2026-13-45` SHALL be undated.

#### Scenario: Impossible date
- **WHEN** a log has the headings `2026-13-45`, `2026-02-30` and `2026-10-23`
- **THEN** the undated sections are `2026-13-45` and `2026-02-30`
