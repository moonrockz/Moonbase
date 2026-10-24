# Tasks

Each group is one story-sized slice. Each group names its beads issue ID once one exists.

## 1. moonrockz/mdc

Beads: none yet.

- [ ] 1.1 Add `HeadingLevel` and use it in `BlockKind::Heading`, with tests for each level and for `of_int` outside 1 to 6 (design D2); verify the mdc tests, `tests/mdc-acceptance` and `tests/mdc-laws`
- [ ] 1.2 Add `FrontmatterError`, `TextPosition`, `SourceRange` and `Document::source_range` (design D3), and move `moonrockz/ears` and `moonrockz/okf` to them; verify unit tests from the `mdc/positions` scenarios and all suites that use mdc

## 2. moonrockz/ears

Beads: none yet.

- [ ] 2.1 Add `Keyword`, use it in `EmptyClause`, keep one keyword table, make `Trigger` read-only and add error positions (design D4); verify unit tests from the `ears/parsing` scenarios, `tests/ears-acceptance` and `tests/ears-laws`

## 3. Contracts and apps

Beads: none yet.

- [ ] 3.1 Add `Version`, `Command::Command` with `CommandError`, `Command::name()` and `Command::proton_id()`, and update `scripts/versions.mbtx` for the new version pattern (design D5); verify unit tests and `mise run validate:versions`
- [ ] 3.2 Add `ExitCode` to `apps/cli`, carry it in the command result, and build `usage()` from the commands; verify the CLI tests and the release smoke test locally with `mise run build:release`

## 4. Scripts

Beads: none yet.

- [ ] 4.1 Parse `RunTrigger`, `GitRef` and `ReleaseFacts` in `scripts/release.mbtx` and pass them to `plan` (design D6); verify the release features, with a scenario for an unknown event
- [ ] 4.2 Add `Backend` and `DistTarget` to the build, test and distribution scripts; verify a scenario for a misspelled target
- [ ] 4.3 Add the `Failure` enum from one table in the publish and release scripts, typed script errors and `ExitCode`, and the script test that the failure tables agree; verify `mise run test:scripts`

## 5. Integration

Beads: none yet.

- [ ] 5.1 Run `mise run check`, `mise run test:scripts`, `mise run test:browser` and `openspec validate --all --strict`; verify all pass
- [ ] 5.2 Write the release note highlights for the breaking mdc and ears changes in the next release pull request; verify they name each changed case
- [ ] 5.3 Review the change with the `code-reviewer` checklist; verify that it reports no Domain types finding in the changed packages

## Workflow follow-up

- Archive the change after the pull request merges.
