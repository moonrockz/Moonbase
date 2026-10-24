# Spec Delta

## Purpose

Give EARS parse errors as typed values that name the clause keyword and the place where the parse failed, so that callers match cases and point to the problem.

## ADDED Requirements

### Requirement: Keyword values in errors
The library SHALL name a clause keyword in a parse error as a keyword value (`Where`, `While`, `When` or `If`), not as text.

#### Scenario: Empty clause
- **WHEN** a caller parses `When , the sensor shall reply.`
- **THEN** the error is the empty clause case with the keyword value `When`

### Requirement: Error positions
A parse error SHALL carry the position in the normalized sentence where the parse failed.

#### Scenario: Missing separator
- **WHEN** a caller parses `When polled the sensor shall reply.`
- **THEN** the error is the missing separator case, with a position in the `When` clause
