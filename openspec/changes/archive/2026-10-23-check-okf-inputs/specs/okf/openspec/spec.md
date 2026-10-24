# Spec Delta

## ADDED Requirements

### Requirement: Safe export names
OpenSpec export SHALL accept a `capability` or `change` value only when each path segment is not empty, is not `.` or `..`, does not start or end with `.`, does not end with a space, is not a Windows device name such as `CON`, and has no control character and none of `\ : * ? " < > |`. WHEN a value breaks a rule, export SHALL raise `InvalidName` with the key and the value.

#### Scenario: Path traversal
- **WHEN** a native concept has `capability: ../../evil` and a caller exports to `out`
- **THEN** export raises `InvalidName` for `capability`, and the plan writes nothing outside `out`

#### Scenario: Windows device name
- **WHEN** a native concept has `change: CON`
- **THEN** export raises `InvalidName` for `change`

### Requirement: Import date
OpenSpec import SHALL accept only a real calendar date in the form `YYYY-MM-DD` for its log entry, and SHALL raise `InvalidDate` for any other date text.

#### Scenario: Month out of range
- **WHEN** a caller imports with the date `2026-13-01`
- **THEN** import raises `InvalidDate`
