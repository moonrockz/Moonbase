# Spec Delta

## Purpose

Keep the commands and the version that the CLI, the web UI and the desktop shell share as typed values in one place.

## ADDED Requirements

### Requirement: Version value
The contracts SHALL give the workspace version as a version value with three non-negative integer parts and no leading zeros.

#### Scenario: Version text
- **WHEN** a caller renders the contract version
- **THEN** the text equals the version of the root `moon.mod`

### Requirement: Commands
The contracts SHALL parse a command name into a command value, and SHALL raise an unknown command error that names the input for any other name. Each command SHALL give its CLI name and its Proton ID.

#### Scenario: Unknown command
- **WHEN** a caller parses the command name `nope`
- **THEN** the parse raises the unknown command error with the name `nope`

#### Scenario: Proton ID
- **WHEN** the desktop shell asks the version command for its Proton ID
- **THEN** the ID is `mission-control.version`
