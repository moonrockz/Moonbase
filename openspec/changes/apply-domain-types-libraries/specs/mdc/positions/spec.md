# Spec Delta

## Purpose

Give MDC consumers typed source positions, ranges and heading levels, and frontmatter errors that they can match by case, so that no consumer repeats position arithmetic or reads error messages.

## ADDED Requirements

### Requirement: Heading levels
The library SHALL give the level of a Markdown heading as a heading level value from 1 to 6.

#### Scenario: Level of a heading
- **WHEN** a caller reads the kind of the block `### Steps`
- **THEN** the kind is a heading with the level value 3

### Requirement: Source positions
The library SHALL give positions as values with a line and a column that are at least 1, and ranges whose start is not after their end. It SHALL translate a location in the Markdown body to a range in the original source.

#### Scenario: Body location in the source
- **WHEN** a document has 3 lines of frontmatter and a caller asks for the source range of a heading on the first body line
- **THEN** the range starts on line 4

### Requirement: Frontmatter errors
The library SHALL raise a frontmatter error with one case for invalid YAML (with its position and message), one for a payload that is not a mapping, and one for more than one YAML document.

#### Scenario: Two documents
- **WHEN** a caller builds frontmatter from `a: 1\n---\nb: 2`
- **THEN** the error is the multiple documents case with the count 2
