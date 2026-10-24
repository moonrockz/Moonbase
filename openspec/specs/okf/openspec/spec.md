# okf/openspec Specification

## Purpose
Connect OpenSpec and OKF: read an OpenSpec tree as an OKF bundle, hold OpenSpec artifacts as native OKF concepts, and convert between the two forms.

## Requirements

### Requirement: OpenSpec tree as a bundle
The library SHALL ship an OpenSpec profile that loads an `openspec/` tree as an OKF bundle. It SHALL classify `specs/<capability>/spec.md` as a Specification, the `proposal.md` of each change as its Change, and the change's `design.md`, `tasks.md` and spec deltas as Design, Tasks and Spec Delta.

#### Scenario: Specification
- **WHEN** the tree has `openspec/specs/okf/documents/spec.md`
- **THEN** the bundle has a Specification concept for the capability `okf/documents`

#### Scenario: Change
- **WHEN** the tree has `openspec/changes/add-okf-module/` with `proposal.md`, `design.md`, `tasks.md` and spec deltas
- **THEN** the bundle has a Change concept `add-okf-module` (its `proposal.md`) that links to its Design, Tasks and deltas

#### Scenario: Archived change
- **WHEN** the tree has a change under `openspec/changes/archive/`
- **THEN** the Change concept has the `state` value `archived`

### Requirement: Structured OpenSpec content
The OpenSpec profile SHALL give each requirement with its name, its text and its scenarios, each scenario with its WHEN and THEN clauses, each delta with its operation (added, modified, removed or renamed), and each task with its number, text and done flag.

#### Scenario: Requirement and scenario
- **WHEN** a spec has `### Requirement: Concept IDs` with `#### Scenario: Concept ID from path`
- **THEN** the profile gives the requirement `Concept IDs` with one scenario and its WHEN and THEN clauses

#### Scenario: Task state
- **WHEN** `tasks.md` has `- [x] 1.1 Add the module`
- **THEN** the profile gives task `1.1` as done

### Requirement: OpenSpec relationships
The OpenSpec profile SHALL link each spec delta to the Specification of its capability, and each Change to the capabilities it adds or modifies, so that the link graph and backlinks work across OpenSpec content.

#### Scenario: Backlinks of a capability
- **WHEN** two changes have deltas for `okf/documents`
- **THEN** the Specification `okf/documents` has backlinks from both changes

### Requirement: Native OpenSpec types
The OpenSpec profile SHALL define native OKF types and frontmatter keys for Specification, Requirement, Scenario, Change and Task, so that an OKF bundle with frontmatter can hold OpenSpec content. Native and OpenSpec-tree forms SHALL give the same structured view.

#### Scenario: Same view
- **WHEN** a caller loads one capability from an `openspec/` tree and the same capability from a native OKF bundle
- **THEN** both give equal requirements, scenarios and links

### Requirement: OpenSpec checks
The OpenSpec profile SHALL report a requirement without a scenario, a scenario that does not use four `#` characters, a requirement without `SHALL` or `MUST`, a modified requirement whose name matches no existing requirement, and a delta for a capability that does not exist and is not added.

#### Scenario: Requirement without scenario
- **WHEN** a spec has a requirement with no scenario
- **THEN** the profile reports a finding for that requirement

### Requirement: Import from OpenSpec
The library SHALL import an `openspec/` tree into an edit plan that creates a native OKF bundle with one concept for each specification, change, proposal, design and task list, with an `index.md` and a `log.md`.

#### Scenario: Import plan
- **WHEN** a caller imports a tree with two specifications and one change
- **THEN** the plan creates concepts for both specifications and the change, a root `index.md` with `okf_version: "0.2"`, and a `log.md`

### Requirement: Export to OpenSpec
The library SHALL export a native OKF bundle with OpenSpec types into an edit plan that creates an `openspec/` tree that the OpenSpec CLI accepts.

#### Scenario: Export plan
- **WHEN** a caller exports a bundle with one Specification concept for `okf/documents`
- **THEN** the plan creates `openspec/specs/okf/documents/spec.md` with the same requirements and scenarios

### Requirement: Round trip
WHEN a caller imports an `openspec/` tree and exports the result, the library SHALL give a tree with the same specifications, changes, requirements, scenarios and tasks as the input.

#### Scenario: Round trip of this repository
- **WHEN** a caller imports the `openspec/` tree of this repository and exports it again
- **THEN** the exported tree has the same structured content as the original tree
