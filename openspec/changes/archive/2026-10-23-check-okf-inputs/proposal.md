# Proposal

## Why

A review against the new Domain types guidance in `AGENTS.md` found inputs that `moonrockz/okf` accepted without checks. An OpenSpec export could write outside its target directory through a `capability` value such as `../../x`. Frontmatter edits accepted keys and raw values that add keys or close the block. `plan_transition` let an extra key replace the checked state. Log and index entries accepted line breaks that add lines, and log dates did not have to be real dates. These requirements record the checks that fix those problems.

## What Changes

- Frontmatter edits accept only plain keys, and refuse raw values whose later lines are not indented.
- Log messages and labels, and index entry titles, destinations and descriptions, must be one line.
- Log dates for edits and for OpenSpec import must be real calendar dates in the form `YYYY-MM-DD`; a log heading counts as dated only for such a date.
- `plan_transition` refuses an extra key that is the state key, and an edit whose frontmatter would not parse.
- OpenSpec export refuses `capability` and `change` values that are not safe path segments, including names that a Windows file system cannot hold.

### Out of scope

- The larger domain type refactors (typed keys, labels, names and dates as values). Later changes do them.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `okf/editing`: input checks for keys, raw values, one-line texts, dates and transition extras.
- `okf/openspec`: safe export names and import dates.
- `okf/indexes`: a log heading is dated only for a real calendar date.

## Impact

- **Affected published module:** `moonrockz/okf` (not released yet). New error variants: `EditError::{InvalidKey, InvalidValue, InvalidDate, LineBreak}`, `TransitionRefused::{NoStateKey, StateKeyInExtra, PreviewInvalid}`, `ConvertError::{InvalidName, InvalidDate}`. `new_concept_text` and `index_entry_line` now raise `EditError`.
