# Spec Delta

## Purpose

Give the exit codes of the `mission-control` command as typed values, so that each outcome has one documented code.

## ADDED Requirements

### Requirement: Exit codes
The `mission-control` command SHALL exit with 0 for success, 1 for a failure and 2 for a usage error, and its command result SHALL carry the exit code as an exit code value from 0 to 255.

#### Scenario: Unknown command
- **WHEN** a user runs `mission-control nope`
- **THEN** the command prints the unknown command message and exits with 2
