# Spec Delta

## Purpose

Find the links between OKF documents, resolve them to their targets, and give a navigable link graph with outbound links, backlinks, orphans and broken links.

## ADDED Requirements

### Requirement: Link extraction
The library SHALL extract each CommonMark link in a document body, including inline, reference and autolinks, with its text, its destination and its line number in the file. It SHALL ignore images and text inside code.

#### Scenario: Links and code
- **WHEN** a body has the link `[Customers](/tables/customers.md)` on file line 9 and the same text inside a code fence
- **THEN** extraction returns one link with the text `Customers`, the destination `/tables/customers.md` and the line 9

#### Scenario: Image
- **WHEN** a body has `![Diagram](/assets/flow.png)`
- **THEN** extraction returns no link for it

### Requirement: Link classification
The library SHALL classify each link destination as external (a URI with a scheme such as `http`, `https` or `mailto`), anchor (starts with `#`), bundle-rooted (starts with `/`) or relative.

#### Scenario: Four kinds
- **WHEN** a body links to `https://example.com`, `#schema`, `/tables/customers.md` and `../metrics/revenue.md`
- **THEN** the kinds are external, anchor, bundle-rooted and relative

### Requirement: Link resolution
WHEN the library resolves a link, it SHALL remove the fragment, resolve a bundle-rooted link from the bundle root, and resolve a relative link from the base that the options select. The default base SHALL be the directory of the file.

#### Scenario: Relative link from the file
- **WHEN** `/tables/orders.md` links to `customers.md` with the default options
- **THEN** the target is `/tables/customers.md`

#### Scenario: Relative link from the bundle root
- **WHEN** `/computations/revenue.md` links to `skills/run-on-bq.md` and the options select the bundle root as the base
- **THEN** the target is `/skills/run-on-bq.md`

#### Scenario: Fragment
- **WHEN** a link is `/tables/customers.md#schema`
- **THEN** the target is `/tables/customers.md` and the fragment is `schema`

### Requirement: Link escape detection
WHEN a bundle-rooted or relative link resolves to a path above the bundle root, the library SHALL keep the escape visible in the result and SHALL not move the path back into the bundle.

#### Scenario: Escape
- **WHEN** `/design/x.md` links to `/../../spec/a.md`
- **THEN** the resolution reports that the link escapes the bundle

### Requirement: Link resolver provider
The library SHALL resolve links through a link resolver provider. The default resolver SHALL test targets against the loaded documents. A caller SHALL be able to supply a resolver that also tests other targets, such as files outside the bundle.

#### Scenario: Target outside the bundle
- **WHEN** a link targets a repository file outside the bundle and the caller supplies a resolver that knows that file
- **THEN** the link resolves and is not broken

### Requirement: Broken links
The library SHALL report a link as broken when its target does not resolve. It SHALL keep broken links in the graph, because OKF allows links to knowledge that does not exist yet.

#### Scenario: Missing target
- **WHEN** a concept links to `/tables/returns.md` and the bundle has no such document
- **THEN** the graph contains the link, marked as broken

### Requirement: Link graph
The library SHALL build a directed link graph for a set of bundles. For each document, the graph SHALL give its outbound links and its backlinks. A backlink SHALL exist for each resolved link, including relative and cross-bundle links.

#### Scenario: Backlinks
- **WHEN** `/tables/orders.md` and `/metrics/revenue.md` both link to `/tables/customers.md`
- **THEN** the backlinks of `/tables/customers.md` are `/tables/orders.md` and `/metrics/revenue.md`

#### Scenario: Cross-bundle link
- **WHEN** a concept in bundle `morphir/cli` links to a concept in bundle `morphir/ir` and the resolver resolves it
- **THEN** the target in `morphir/ir` has a backlink from the concept in `morphir/cli`

### Requirement: Orphans
The library SHALL report each concept that has no backlink as an orphan. The caller SHALL choose whether links from index documents count as backlinks.

#### Scenario: Linked only from the index
- **WHEN** only `/index.md` links to `/tables/customers.md` and the caller does not count index links
- **THEN** `/tables/customers.md` is an orphan

### Requirement: Typed references
The library SHALL resolve typed references in frontmatter, such as `sources[].resource` and profile-defined fields, to documents or to external resources. It SHALL report each typed reference that does not resolve.

#### Scenario: Source points to a concept
- **WHEN** a source has `resource: /references/ga4-docs.md` and that concept exists
- **THEN** the typed reference resolves to that concept

### Requirement: Source URL parts
The library SHALL split a commit-pinned GitHub URL in a source into its organization, repository, commit and path.

#### Scenario: Pinned URL
- **WHEN** a source has `resource: https://github.com/finos/morphir/blob/ab8d5c91/spec/ir.md`
- **THEN** the parts are `finos`, `morphir`, `ab8d5c91` and `spec/ir.md`
