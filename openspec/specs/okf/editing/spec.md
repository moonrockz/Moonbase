# okf/editing Specification

## Purpose
Change OKF documents with pure text edits that touch only the intended text and keep every other byte, so that tools can write back to a knowledge base without unwanted changes.

## Requirements

### Requirement: Edit results
Each edit SHALL take the current document text and return the new text and a flag that says whether the text changed. An edit SHALL not write to a document store.

#### Scenario: No change
- **WHEN** a caller sets `status: stable` on a concept that already has `status: stable`
- **THEN** the edit returns the same text and says that nothing changed

### Requirement: Byte preservation
An edit SHALL keep every byte outside the text that it changes, including line endings (LF or CRLF), comments, key order, quoting and trailing white space.

#### Scenario: CRLF file
- **WHEN** a caller sets one frontmatter key in a file with CRLF line endings
- **THEN** the new text has CRLF line endings, and only the line of that key differs

### Requirement: Frontmatter key edits
The library SHALL set or remove a top-level frontmatter key. A new key SHALL go after the last top-level key. A scalar value SHALL be quoted when YAML needs quotes for it.

#### Scenario: Add a key
- **WHEN** a caller sets `status: deprecated` on a concept that has no `status`
- **THEN** the new text has `status: deprecated` after the last top-level key

#### Scenario: Value that needs quotes
- **WHEN** a caller sets `title` to `Revenue: net`
- **THEN** the new line is `title: "Revenue: net"`

#### Scenario: Remove a key
- **WHEN** a caller removes `stale_after`
- **THEN** the new text has no `stale_after` line and no other line changes

### Requirement: Index entry edits
The library SHALL add an entry to a named index section after its last entry, and SHALL add the section at the end when it does not exist. It SHALL refresh the description of an entry and keep its link text.

#### Scenario: New section
- **WHEN** a caller adds an entry to the section `Metrics` in an index without that section
- **THEN** the new text ends with a `Metrics` section that contains the entry

#### Scenario: Refresh description
- **WHEN** the concept description changed to `Net revenue per day`
- **THEN** the refresh changes only the description part of the entry line

### Requirement: Target index selection
WHEN a caller adds a concept in a subdirectory that has its own `index.md`, the library SHALL select that sub-index for the entry. Otherwise it SHALL select the root index.

#### Scenario: Sub-index exists
- **WHEN** a caller adds `/decisions/0042-use-yaml.md` and `/decisions/index.md` exists
- **THEN** the entry goes into `/decisions/index.md`

### Requirement: Log entry edits
The library SHALL add a log entry under the section for a given date. WHEN that section does not exist, the library SHALL add it in newest-first order.

#### Scenario: New date
- **WHEN** a caller adds a `Creation` entry for `2026-10-23` to a log whose newest section is `2026-10-20`
- **THEN** the new `2026-10-23` section is first, with the entry

### Requirement: Generated region edits
The library SHALL replace the content of a marked region with new content and keep the text before the marker. It SHALL say whether the region changed.

#### Scenario: Same region content
- **WHEN** a caller regenerates a region with content equal to the current content
- **THEN** the edit says that nothing changed

### Requirement: Concept creation
The library SHALL create the text of a new concept from a type, a title, a description and optional fields, using a template that a profile or caller supplies. It SHALL refuse a path that is reserved, that escapes the bundle, or that already exists.

#### Scenario: Reserved path
- **WHEN** a caller creates a concept at `/tables/index.md`
- **THEN** the library refuses it and names the reserved file name

#### Scenario: Created text
- **WHEN** a caller creates a `Metric` concept with the title `Revenue`
- **THEN** the new text has frontmatter with `type: Metric` and `title: Revenue`, and a body from the template

### Requirement: Edit plans
The library SHALL combine several edits to several documents into one plan that a caller can show as a dry run or apply through a document store.

#### Scenario: Add a concept
- **WHEN** a caller plans to add a concept
- **THEN** the plan contains the new concept file, the index entry and the log entry, and nothing is written before the caller applies it

### Requirement: Plain frontmatter keys
A frontmatter edit SHALL accept only a plain key: a letter, a digit or `_` first, then letters, digits, `_`, `.` or `-`. WHEN a caller gives another key, the edit SHALL raise `InvalidKey` and change nothing.

#### Scenario: Quoted key
- **WHEN** a caller sets the key `"state"` on a concept that has `state: Backlog`
- **THEN** the edit raises `InvalidKey` and the text does not change

#### Scenario: Plain keys
- **WHEN** a caller sets the keys `owner.team`, `stale-after` and `x_1`
- **THEN** each edit succeeds

### Requirement: Raw values stay in their key
A frontmatter edit SHALL refuse a raw YAML value whose second or later line does not start with white space, with `InvalidValue`, because such a line would add a key or close the block.

#### Scenario: Value that adds a key
- **WHEN** a caller sets the raw value `x\nstatus: done` for the key `owner`
- **THEN** the edit raises `InvalidValue`

#### Scenario: Indented block value
- **WHEN** a caller sets the raw value `\n  - a\n  - b` for the key `tags`
- **THEN** the document has the tags `a` and `b` and no other new key

### Requirement: One-line entries
An edit SHALL refuse a line break in a log message, a log label, and an index entry title, destination or description, with `LineBreak` that names the field.

#### Scenario: Forged log section
- **WHEN** a caller adds the log message `x\n## 2099-01-01`
- **THEN** the edit raises `LineBreak` for the field `message`

### Requirement: Real log dates
A log entry edit SHALL accept only a real calendar date in the form `YYYY-MM-DD`, and SHALL raise `InvalidDate` for any other date text.

#### Scenario: Date that does not exist
- **WHEN** a caller adds a log entry for `2026-02-30`
- **THEN** the edit raises `InvalidDate`

### Requirement: Transition extras
WHEN a caller plans a transition, the library SHALL refuse an extra key that is the state key of the register with `StateKeyInExtra`, a register without a state key with `NoStateKey`, and an edit whose frontmatter would not parse with `PreviewInvalid`.

#### Scenario: Extra state key
- **WHEN** a caller plans the transition to `Review` with the extra key `state` set to `Done`
- **THEN** the plan raises `StateKeyInExtra` and contains no edit
