# Spec Delta

## Purpose

Make the build and release scripts parse their inputs and classify failures once, as typed values, so that a typo or an unexpected text cannot change what a release does.

## ADDED Requirements

### Requirement: Release inputs
The release script SHALL parse the GitHub event, the dry-run flag and the ref once into a run trigger (pull request, dry run or push) and a git ref (a branch or a version tag), and SHALL stop with a typed error that names an event or a ref type that it does not know.

#### Scenario: Unknown event
- **WHEN** the release plan runs with the event `pull-request`
- **THEN** the script stops with an error that names `pull-request`, and plans no release

### Requirement: Build targets
The build, test and distribution scripts SHALL parse each target argument into a backend (`wasm`, `wasm-gc`, `js` or `native`) or a distribution target, and SHALL stop with a usage error for any other text before they run a build.

#### Scenario: Misspelled target
- **WHEN** a user runs `mise run test -- jss`
- **THEN** the script stops with a usage error that names `jss`, and runs no test

### Requirement: Failure classes
The publish and release scripts SHALL classify a failed command once into refused, conflict, transient, already published or other, from one table, and SHALL retry only transient failures.

#### Scenario: Same table in both scripts
- **WHEN** the publish and the release script classify the same output
- **THEN** both give the same class

### Requirement: Script exit codes
Every task script SHALL exit with 0 for success, 1 for a failure and 2 for a usage error.

#### Scenario: Usage error
- **WHEN** a user runs `moonx scripts/versions.mbtx` with no arguments
- **THEN** the script prints its usage and exits with 2
