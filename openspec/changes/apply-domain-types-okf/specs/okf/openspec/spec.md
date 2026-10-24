# Spec Delta

## ADDED Requirements

### Requirement: Typed OpenSpec names
The OpenSpec profile SHALL parse capability paths, change names and requirement names once into values with the rules of `check-okf-inputs`, and SHALL give OpenSpec types and change states as enums, not as text.

#### Scenario: Change state
- **WHEN** the profile loads an archived change
- **THEN** the change has the archived state value

### Requirement: Task numbers
The OpenSpec profile SHALL parse a task number as dot-separated positive integers and SHALL order task numbers by their numbers, so that `1.2` comes before `1.10`. A task without a number SHALL have no number.

#### Scenario: Numeric order
- **WHEN** a task list has the tasks `1.10` and `1.2`
- **THEN** `1.2` orders before `1.10`

### Requirement: Complete renames
The OpenSpec profile SHALL give a rename only when it has both a from name and a to name, and SHALL report a rename with one part as a finding.

#### Scenario: Rename without TO
- **WHEN** a `RENAMED Requirements` section has `- FROM: X` and no `TO:` line
- **THEN** the view has no rename for `X` and validation reports the incomplete rename
