# Spec Delta

## Purpose

Let EARS parsing accept the requirement styles of real projects, such as OpenSpec, through dialects that add vocabulary and Markdown requirement headings, while the default grammar stays strict EARS.

## ADDED Requirements

### Requirement: Strict default
WHEN a caller parses without a dialect, the library SHALL accept only the current strict EARS grammar and SHALL give the same requirements and errors as before this change.

#### Scenario: Strict subject
- **WHEN** a caller parses `It shall report the version.` without a dialect
- **THEN** the parse fails with `ExpectedSystem`

#### Scenario: Strict requirement unchanged
- **WHEN** a caller parses `While enabled, when polled, the sensor shall report temperature.` without a dialect
- **THEN** the requirement has the precondition `enabled`, the event `polled`, the system `sensor` and the response `report temperature.`

### Requirement: Dialect contract
The library SHALL define a dialect contract whose methods each add one kind of vocabulary: modal verbs, subject openers, system nouns, lead-in phrases and Markdown requirement headings. Each method SHALL be optional, and a dialect that adds nothing SHALL behave as the default.

#### Scenario: Empty dialect
- **WHEN** a caller parses with a dialect that gives only a name
- **THEN** the results equal the results without a dialect

### Requirement: Dialect composition
WHEN a caller gives several dialects, the library SHALL use the union of their vocabularies and heading rules. Keyword matching SHALL ignore letter case.

#### Scenario: Two dialects
- **WHEN** one dialect adds the modal verb `must` and another adds the subject opener `each`
- **THEN** `Each entry MUST have a link.` parses with the subject opener `Each`, the system `entry` and the modal verb `must`

### Requirement: Modal verbs
A dialect SHALL be able to add modal verbs. A modal verb followed by `not` SHALL be a negated modal. The requirement SHALL record its modal verb and whether it is negated, and its response SHALL not include them.

#### Scenario: MUST NOT
- **WHEN** a dialect adds `must` and a caller parses `The store MUST NOT write outside its root.`
- **THEN** the modal verb is `must`, it is negated, and the response is `write outside its root.`

### Requirement: Subject openers
A dialect SHALL be able to add determiners and pronouns that can start the subject in place of `the`. The requirement SHALL record the opener as written. A determiner SHALL need a system after it; a pronoun SHALL stand for a system by itself.

#### Scenario: Determiner
- **WHEN** a dialect adds `an` and a caller parses `An edit SHALL keep every other byte.`
- **THEN** the subject opener is `An` and the system is `edit`

#### Scenario: Pronoun alone
- **WHEN** a dialect adds the pronoun `it` and a caller parses `It SHALL report the error.` as a single sentence
- **THEN** the subject opener is `It` and the system is not resolved

### Requirement: System nouns
A dialect SHALL be able to add system nouns that start a subject without a determiner, such as a product name.

#### Scenario: Product name
- **WHEN** a dialect adds the system noun `Mission Control` and a caller parses `Mission Control SHALL publish one version.`
- **THEN** the system is `Mission Control`

### Requirement: Lead-in phrases
A dialect SHALL be able to add lead-in phrases that can come before the clauses of a sentence, such as `Otherwise` or `For each`. The requirement SHALL record the lead-in up to its comma, or up to the subject when no comma follows.

#### Scenario: Otherwise
- **WHEN** a dialect adds `otherwise` and the pronoun `it`, and a caller parses `Otherwise it SHALL select the root index.`
- **THEN** the lead-in is `Otherwise`, the subject opener is `it` and the response is `select the root index.`

#### Scenario: Lead-in with a comma
- **WHEN** a dialect adds `for each` and a caller parses `For each document, the graph SHALL give its backlinks.`
- **THEN** the lead-in is `For each document` and the system is `graph`

### Requirement: Round trip
The library SHALL render a requirement with its lead-in, clauses, subject opener, system, modal verb with negation, and response. WHEN a caller parses the rendered text with the same dialects, the library SHALL give an equal requirement.

#### Scenario: Render and parse
- **WHEN** a caller renders the requirement from `For each document, the graph SHALL NOT drop links.` and parses the result with the same dialects
- **THEN** the second requirement equals the first

### Requirement: Requirement blocks
The library SHALL parse a requirement block into sentences. A sentence SHALL end at a full stop, question mark or exclamation mark that is followed by white space or the end, outside backticks. Each sentence SHALL become a requirement or a diagnostic with its position, so that one bad sentence does not discard the others.

#### Scenario: Two sentences
- **WHEN** a caller parses the block `The store SHALL list files. It SHALL sort them by path.` with the OpenSpec dialect
- **THEN** the block has two requirements and no diagnostic

#### Scenario: Full stop in code
- **WHEN** a block contains `` The parser SHALL read `a.md` files. ``
- **THEN** the block has one requirement

### Requirement: Pronoun resolution
In a requirement block, the library SHALL resolve a pronoun subject to the system of the nearest previous sentence that has a system. WHEN no previous sentence has a system, the library SHALL keep the pronoun unresolved and SHALL report it as a diagnostic.

#### Scenario: It refers back
- **WHEN** a caller parses `The store SHALL list files. It SHALL sort them by path.` with the OpenSpec dialect
- **THEN** the second requirement has the resolved system `store`

### Requirement: Markdown requirement headings
A dialect SHALL be able to add heading rules: a heading level and a heading prefix, such as level 3 and `Requirement:`. WHEN a caller extracts requirements from Markdown, the library SHALL take each heading that matches a rule as a requirement block named by the rest of the heading. The block SHALL hold the paragraphs up to the next heading of any level, and SHALL keep source positions.

#### Scenario: OpenSpec heading
- **WHEN** a caller extracts requirements with the OpenSpec dialect from `### Requirement: Path safety` followed by two sentences and a `#### Scenario:` heading
- **THEN** the result has one block named `Path safety` with two requirements, and the scenario text is not in the block

#### Scenario: No heading rule
- **WHEN** a caller extracts requirements from the same Markdown without a dialect
- **THEN** the library extracts requirements as before this change, from paragraphs and list items

### Requirement: Lexicons
The library SHALL provide a lexicon: a dialect defined as data, with a name and lists of modal verbs, determiners, pronouns, system nouns, lead-in phrases and heading rules. A caller SHALL be able to build a lexicon in code.

#### Scenario: Lexicon in code
- **WHEN** a caller builds a lexicon with the system noun `OpenSpec` and parses with it
- **THEN** `OpenSpec SHALL validate the change.` parses with the system `OpenSpec`

### Requirement: Lexicon files
The library SHALL parse a lexicon from YAML text with the keys `name`, `modals`, `determiners`, `pronouns`, `systems`, `lead_ins` and `headings`, where each heading has a `level` and a `prefix`. It SHALL report an unknown key or a wrong value type as an error with its line.

#### Scenario: Lexicon file
- **WHEN** a caller parses a lexicon file with `systems: [Mission Control]` and `lead_ins: [otherwise]`
- **THEN** the lexicon adds that system noun and that lead-in phrase

#### Scenario: Wrong type
- **WHEN** a lexicon file has `modals: must`
- **THEN** parsing fails with an error that names `modals` and its line

### Requirement: OpenSpec dialect
The library SHALL ship an OpenSpec dialect that adds the modal verbs `shall` and `must`, the determiners `a`, `an`, `each`, `every`, `any`, `these`, `those`, `this`, `that`, `its` and `their`, the pronouns `it` and `they`, the lead-in `otherwise`, and the heading rule level 3 with the prefix `Requirement:`.

#### Scenario: This repository's specs
- **WHEN** the library parses every requirement block of this repository's `openspec/specs/` with the OpenSpec dialect and a project lexicon
- **THEN** every sentence parses, or the acceptance test lists each sentence that does not
