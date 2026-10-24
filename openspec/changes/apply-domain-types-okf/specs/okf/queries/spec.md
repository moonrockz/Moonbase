# Spec Delta

## ADDED Requirements

### Requirement: Typed search limits
A search request SHALL take a limit from 1 to a maximum that the library documents, through a constructor that raises a typed error for any other value, and SHALL have a default limit.

#### Scenario: Negative limit
- **WHEN** a caller builds a search limit from `-1`
- **THEN** the constructor raises a limit error that names `-1`

### Requirement: Typed facets and filters
The library SHALL take a facet as one of type, status, tags, bundle, or a frontmatter key, and SHALL take a status filter as a status value, so that a frontmatter key named `bundle` can be a facet and an unknown status that reads like a known one cannot occur.

#### Scenario: Frontmatter key named bundle
- **WHEN** concepts have the frontmatter key `bundle` and a caller asks for the facet of that key
- **THEN** the result counts the values of the key, not the bundle labels
