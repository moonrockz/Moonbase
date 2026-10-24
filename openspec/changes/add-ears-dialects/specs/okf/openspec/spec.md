# Spec Delta

## ADDED Requirements

### Requirement: EARS sentences in the view
The OpenSpec profile SHALL give, for each requirement of its structured view, the EARS requirements and diagnostics of the requirement text, parsed with the OpenSpec dialect and the project lexicon.

#### Scenario: Parsed sentences
- **WHEN** a requirement has the text `The store SHALL list files. It SHALL sort them by path.`
- **THEN** the view gives two EARS requirements for it, and the second has the resolved system `store`

### Requirement: Project lexicon
The OpenSpec profile SHALL read a project lexicon from the file `ears.yaml` at the root of the `openspec/` tree when it exists, and a caller SHALL be able to supply a lexicon in code. WHEN the lexicon file is invalid, the profile SHALL report it as a finding and SHALL parse with the OpenSpec dialect alone.

#### Scenario: Lexicon file in the tree
- **WHEN** `openspec/ears.yaml` adds the system noun `Mission Control`
- **THEN** the sentence `Mission Control SHALL publish one version.` parses in the view

#### Scenario: Invalid lexicon file
- **WHEN** `openspec/ears.yaml` is not valid YAML
- **THEN** validation reports a finding for `ears.yaml`, and requirements still parse with the OpenSpec dialect

### Requirement: EARS form check
The OpenSpec profile SHALL report each requirement sentence that does not parse as EARS with the active dialects, with the rule `openspec-requirement-not-ears`, the sentence, its line and the parse error.

#### Scenario: Sentence not in EARS form
- **WHEN** a requirement text has the sentence `Fast responses are important.`
- **THEN** validation reports `openspec-requirement-not-ears` for that sentence and its line
