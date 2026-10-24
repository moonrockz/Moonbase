# Spec Delta

## ADDED Requirements

### Requirement: Consistent links
The library SHALL derive the kind of a link from its destination, so that no link has a kind that disagrees with its destination. A link SHALL record its origin: a body line, or a profile.

#### Scenario: Profile link
- **WHEN** a profile adds a link to `/specs/okf/documents/spec.md`
- **THEN** the link has the origin profile and the kind bundle-rooted, and it has no line number

### Requirement: Typed document references
The library SHALL parse a document reference such as `morphir/ir:/caps/okf.md` once into a bundle label and a bundle path, and SHALL raise a typed error for a reference that has an invalid label or an escaping path.

#### Scenario: Escaping path in a reference
- **WHEN** a caller parses the reference `x:/../a.md`
- **THEN** the parse raises an error that names the escaping path

### Requirement: Typed GitHub sources
The library SHALL parse a commit-pinned GitHub URL into an organization, a repository, a commit and a path that are not empty, with a commit of 7 to 40 hexadecimal characters, and SHALL raise a typed error that names the broken rule.

#### Scenario: Empty organization
- **WHEN** a caller parses `https://github.com//r/blob/abcdef1/x.md`
- **THEN** the parse raises an error for the empty organization
