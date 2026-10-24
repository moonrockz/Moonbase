# Spec Delta

## ADDED Requirements

### Requirement: Typed store inputs
The stores SHALL take their root as a checked store root that is not empty, directories as store directories, and SHALL give entry names that are one non-empty segment. Index metadata SHALL hold a schema version of at least 1 and a document count of at least 0.

#### Scenario: Empty root
- **WHEN** a caller builds a store root from an empty text
- **THEN** the constructor raises a root error

### Requirement: Store error locations
A store error SHALL name its location relative to the store root, as a file or a directory, so that the same failure gives the same error from every store and no store reveals a host path.

#### Scenario: Missing file in two stores
- **WHEN** a caller reads `missing.md` from the in-memory store and from the file system store
- **THEN** both raise a not-found error for the file `missing.md`
