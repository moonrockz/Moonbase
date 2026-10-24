# Tasks

Each group is one story-sized slice. Each group names its beads issue ID once one exists.

## 1. Core identifiers

Beads: none yet.

- [ ] 1.1 Add `BundleLabel`, `StoreDir`, `ConceptType` and `FieldKey` with constructors and tests on each side of each rule, and use them in bundles, discovery, metadata, filters, `DocKey` and registers (design D1, D4); verify `mise run test`
- [ ] 1.2 Add the `OkfVersion` enum, remove the empty Concept ID, unknown status and actor sentinels, and make public arrays and maps read-only; verify unit tests for each case

## 2. Relationships, indexes and queries

Beads: none yet.

- [ ] 2.1 Make `Link` private with a derived kind and a `LinkOrigin`, and type `DocRef` and `GitHubSource` with `CommitSha`; verify unit tests from the `okf/relationships` scenarios
- [ ] 2.2 Add `HeadingLevel`, the preamble section, `LogDate` with `LogHeading`, and `IndexGroup`; verify unit tests, including a concept type named `Subdirectories`
- [ ] 2.3 Add `SearchLimit`, the `Facet` and `ScanField` enums and `StatusIs(Status)`; verify unit tests from the `okf/queries` scenarios

## 3. Validation and profiles

Beads: none yet.

- [ ] 3.1 Add `RuleName` and `FindingSubject`, the documented finding order, and the `validation-config-unknown-rule` report (design D5); verify unit tests and the morphir golden checks
- [ ] 3.2 Add the checked `Register` constructor with `RegisterName`, `StateName`, `RecordId` and `IdWidth`, and the unknown register report for reference fields; verify unit tests from the `okf/profiles` scenarios and the morphir reference profile

## 4. Editing, providers and OpenSpec

Beads: none yet.

- [ ] 4.1 Add `FrontmatterKey`, `RawYaml`, `SectionName` and the planner `PlanError`, and use `LogDate` in edits; verify unit tests from the `okf/editing` scenarios
- [ ] 4.2 Add `StoreRoot`, `EntryName`, `StoreLocation` error payloads and typed `IndexMetadata`, and update every store; verify the store conformance checks on every store and target, and `mise run test:browser`
- [ ] 4.3 Add `CapabilityPath`, `ChangeName`, `RequirementName`, `TaskNumber`, the `OpenSpecType` and `ChangeState` enums and complete renames; verify unit tests from the `okf/openspec` scenarios and the OpenSpec acceptance suite

## 5. Integration

Beads: none yet.

- [ ] 5.1 Update `pkgs/okf/README.md` examples for the typed API; verify `mise run lint`
- [ ] 5.2 Run `mise run check`, `mise run test:scripts`, `mise run test:browser` and `openspec validate --all --strict`; verify all pass
- [ ] 5.3 Review the change with the `code-reviewer` checklist; verify that it reports no Domain types finding for `moonrockz/okf`

## Workflow follow-up

- Archive the change after the pull request merges.
