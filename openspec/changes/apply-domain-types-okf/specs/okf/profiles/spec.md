# Spec Delta

## ADDED Requirements

### Requirement: Checked registers
The library SHALL build a register only through a constructor that checks it: the name and the concept type are not empty, an ID width is from 1 to 9, and every transition target and superseded state is one of its states. The constructor SHALL raise a typed error that names the broken rule.

#### Scenario: Unknown transition target
- **WHEN** a caller builds a register with the states `Backlog` and `Done` and a transition to `Review`
- **THEN** the constructor raises an error that names `Review`

#### Scenario: Width zero
- **WHEN** a caller builds a register with an ID width of 0
- **THEN** the constructor raises an error for the width

### Requirement: Typed register parts
The library SHALL give record IDs, state names and register names as values, and a record without an ID SHALL have no ID, not an empty one. A reference field that names a register SHALL name one that a profile defines, and profile checks SHALL report one that does not.

#### Scenario: Unknown register in a reference field
- **WHEN** a profile defines a reference field for the register `decisoins` and no profile defines that register
- **THEN** the profile checks report the unknown register name
