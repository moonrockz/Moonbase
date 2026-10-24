# Spec Delta

## Purpose

Find documents and pull data out of OKF bundles: lookup by path or ID, filters and facets over frontmatter, document outlines, and ranked search through a search provider.

## ADDED Requirements

### Requirement: Lookup by path and Concept ID
The library SHALL find a document by its bundle label and bundle-relative path, and a concept by its Concept ID. A bundle label SHALL match the full label or, when only one bundle has it, the bare bundle name.

#### Scenario: Lookup by Concept ID
- **WHEN** a caller asks bundle `acme_retail` for the Concept ID `metrics/revenue`
- **THEN** the result is the concept at `/metrics/revenue.md`

#### Scenario: Ambiguous bare name
- **WHEN** the bundles `morphir/ir` and `finos/ir` both exist and a caller asks for `ir`
- **THEN** the lookup reports that the name is ambiguous and names both bundles

### Requirement: Lookup by path suffix
WHEN no document matches a path exactly, the library SHALL find the documents whose path ends with the given suffix, and SHALL report the result as one match, no match or several matches.

#### Scenario: Suffix match
- **WHEN** a caller asks for `customers.md` and only `/tables/customers.md` ends with it
- **THEN** the lookup returns `/tables/customers.md`

### Requirement: Filters and facets
The library SHALL filter concepts by `type`, `status`, tag, bundle and any frontmatter key. Text comparison SHALL ignore letter case. WHEN a caller gives several filters, a concept SHALL match only when it matches all of them.

#### Scenario: Two filters
- **WHEN** a caller filters for type `Metric` and tag `finance`
- **THEN** the result contains only concepts that have both

#### Scenario: Facet counts
- **WHEN** a caller asks for the `type` facet of a bundle
- **THEN** the result gives each type value with its number of concepts

### Requirement: Text scan
The library SHALL find concepts whose title, description, type, tags or path contains a given text, ignoring letter case. WHEN the caller includes bodies, the result SHALL give each matching body line with its line number.

#### Scenario: Body hit
- **WHEN** a caller scans for `churn` with bodies included and line 14 of `/metrics/churn.md` contains `Churn`
- **THEN** the result contains that concept with a hit on line 14

### Requirement: Search provider
The library SHALL run ranked search through a search provider. A search request SHALL carry the query text, the filters and a result limit. Each result SHALL carry the document, a score and a snippet.

#### Scenario: Ranked results
- **WHEN** a caller searches for `revenue` with a limit of 5 through the in-memory search provider
- **THEN** the result has at most 5 documents, ordered by score from high to low, each with a snippet

#### Scenario: Other provider
- **WHEN** a caller supplies a search provider of its own
- **THEN** the library sends the same search request to that provider and returns its results

### Requirement: Document outline
The library SHALL give the outline of a document: each heading with its level, its text, its slug and its line number in the file. It SHALL ignore lines in code that start with `#`.

#### Scenario: Outline with code
- **WHEN** a body has `# Schema` on file line 7 and `# comment` inside a code fence
- **THEN** the outline has one heading, `Schema`, at level 1 on line 7

### Requirement: One line base
The library SHALL give every line number as a line in the file, counted from 1, for links, headings, index entries, log entries and findings.

#### Scenario: Line after frontmatter
- **WHEN** a document has 5 lines of frontmatter and a heading on the first body line
- **THEN** the heading line is 6

### Requirement: Body section access
The library SHALL give the content under a named heading, such as `# Schema`, `# Examples` or `# Computation`, and the code blocks in that content with their language tags.

#### Scenario: Computation code
- **WHEN** a concept has `# Computation` followed by a `sql` code block
- **THEN** the library returns that code block with the language `sql`

### Requirement: Footnote citations
The library SHALL link each body footnote whose label equals a `sources[].id` to that source.

#### Scenario: Cited claim
- **WHEN** a body has `[^ga4-schema]` and `sources` has an entry with `id: ga4-schema`
- **THEN** the citation resolves to that source entry
