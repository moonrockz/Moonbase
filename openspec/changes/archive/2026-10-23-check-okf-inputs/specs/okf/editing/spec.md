# Spec Delta

## ADDED Requirements

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
