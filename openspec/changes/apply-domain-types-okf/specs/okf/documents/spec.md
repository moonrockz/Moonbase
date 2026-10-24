# Spec Delta

## ADDED Requirements

### Requirement: Typed identifiers
The library SHALL represent bundle labels, store directories, concept types and frontmatter keys as types whose constructors check their rules once: a label has one or more non-empty segments without `/`, `:` or white space; a directory has no empty, `.` or `..` segment; a concept type is not blank; a key is a plain key. A constructor SHALL raise a typed error that names the input and the broken rule.

#### Scenario: Invalid label
- **WHEN** a caller builds a bundle label from `morphir//ir`
- **THEN** the constructor raises an error that names `morphir//ir` and the empty segment

#### Scenario: Concept types compare without case
- **WHEN** a caller compares the concept types `Decision Record` and `decision record`
- **THEN** they are equal

### Requirement: OKF version values
The library SHALL give the OKF version of a bundle as a known version (`0.1` or `0.2`) or as an unknown version with its text, not as raw text.

#### Scenario: Unknown version
- **WHEN** the root index has `okf_version: "0.3"`
- **THEN** the bundle reports an unknown OKF version with the text `0.3`

### Requirement: No sentinel values
The library SHALL represent an absent value as an absent option or as an enum case, never as an empty string or a zero: a Concept ID is never empty, an unknown status is never empty and never a known status word, and an attribution without an actor has no actor.

#### Scenario: Empty Concept ID
- **WHEN** a caller builds a Concept ID from `/.md`
- **THEN** the constructor raises an empty path error

### Requirement: Immutable public values
Every public value of the library SHALL be immutable after construction: arrays and maps that it gives SHALL be read-only, and no public field SHALL let a caller change a value that other code holds.

#### Scenario: Validation config
- **WHEN** a caller builds a validation config and keeps the list of turned-off rules that it gave
- **THEN** a later change to that list does not change the config
