# Spec Delta

## ADDED Requirements

### Requirement: Typed headings
The library SHALL give heading levels as values from 1 to 6, and SHALL give the text before the first index heading as a preamble section, not as a heading with level 0.

#### Scenario: Preamble
- **WHEN** an index has prose before its first heading
- **THEN** the first section is a preamble section with that prose

### Requirement: Typed log headings
The library SHALL give each log section heading as a dated heading with a calendar date, or as an undated heading with its text, and SHALL order dated headings by date.

#### Scenario: Order by date
- **WHEN** a log has `## 2026-09-01` before `## 2026-10-20`
- **THEN** the library reports that the log is not newest first, from the dates and not from the text

### Requirement: Index groups apart from types
The generated index SHALL keep the subdirectory section and the section for concepts without a type apart from the sections of concept types, even when a concept type has the same text.

#### Scenario: Concept type named Subdirectories
- **WHEN** a directory has a concept of type `Subdirectories` and a subdirectory
- **THEN** the generated index has a `Subdirectories` section for the concept type and a separate section for the subdirectory
