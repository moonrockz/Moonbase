# Proposal

## Why

The review against the Domain types section of `AGENTS.md` also covered `moonrockz/mdc`, `moonrockz/ears`, the shared contracts, the apps and the task scripts. It found raw integers for positions and heading levels, string codes in public errors, an error case that callers can tell apart only by its message, versions and exit codes as raw text and integers, and scripts that pass GitHub event codes and five Boolean flags around. These are published modules and the release tooling, so the change needs a plan and a compatibility note.

## What Changes

- **BREAKING (`moonrockz/mdc`):** `BlockKind::Heading` holds a `HeadingLevel` value (1 to 6) in place of `Int`. Frontmatter construction raises `FrontmatterError` with the cases invalid YAML, not a mapping and multiple documents, so a caller can match each case. Positions become `TextPosition` and `SourceRange` values, and `Document::source_range` translates body locations to source locations, so callers do no line arithmetic.
- **BREAKING (`moonrockz/ears`):** `ParseError::EmptyClause` holds a `Keyword` enum in place of a string; the parser keeps one keyword table. `Trigger` becomes read-only. Parse errors can carry the position where the parse failed. This lands with or after `add-ears-dialects`, which also changes the requirement model.
- **`moonrockz/mission-control-contracts`:** `version()` gives a `Version` value; `Command::Command(name)` raises `CommandError::UnknownCommand` with the name; commands give their CLI names and Proton IDs, so the apps copy no names.
- **`apps/cli`:** the command result carries an `ExitCode` (0 to 255) with named constructors for success, failure and usage errors.
- **Task scripts:** the release script parses the GitHub event, the ref and the release facts once into `RunTrigger`, `GitRef` and `ReleaseFacts`; build targets become `Backend` and `DistTarget` enums; command failures become a `Failure` enum from one keyword table; exit codes and script errors are typed.

### Out of scope

- `moonrockz/okf` (`apply-domain-types-okf`).
- A shared package for the scripts. Each script is one file, so each keeps its own small copy of `Version` and `ExitCode`, with a test that the copies agree.
- Changes to what the CLI prints or to the release behavior.

## Capabilities

### New Capabilities

- `mdc/positions`: typed source positions, ranges and heading levels, and typed frontmatter errors.
- `ears/parsing`: typed parse errors with keywords and positions.
- `contracts/commands`: typed versions and commands shared by the CLI, the web UI and the desktop shell.
- `cli/exit-codes`: typed exit codes of the `mission-control` command.
- `tooling/release`: typed inputs and failures of the build and release scripts.

### Modified Capabilities

None.

## Impact

- **Affected published modules:** `moonrockz/mdc` and `moonrockz/ears` (breaking: callers that match `Heading(level~)`, `InvalidFrontmatter` or `EmptyClause(keyword~)` change), `moonrockz/mission-control-contracts`, `moonrockz/mission-control-cli`, `moonrockz/mission-control-desktop` and `moonrockz/okf` (it consumes the mdc values).
- **Release notes:** the breaking changes go in the highlights of the next release.
- **Scripts:** `scripts/*.mbtx` and their features change; `mise run test:scripts` covers them.
