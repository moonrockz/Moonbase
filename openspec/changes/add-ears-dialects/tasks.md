# Tasks

Each group is one story-sized slice. Each group names its beads issue ID once one exists.

## 1. Dialects and the requirement model

Beads: none yet.

- [ ] 1.0 Add `Word`, `Phrase`, `HeadingLevel`, `HeadingPrefix` and `HeadingRule` with smart constructors, `LexiconError`, and tests on each side of each rule (design D8); verify the unit tests
- [ ] 1.1 Add the `Dialect` trait with default methods, `HeadingRule`, `Lexicon` (implementing `Dialect`) and the internal merged vocabulary (design D1); verify unit tests for an empty dialect and for the union of two dialects
- [ ] 1.2 Add `lead_in`, `opener`, `modal` and `resolved_system` to `Requirement` with accessors, and extend `to_string()` (design D2); verify that the existing unit tests, `tests/ears-acceptance` and `tests/ears-laws` pass unchanged
- [ ] 1.3 Implement the vocabulary parsing order: lead-ins, clauses with subject-aware commas, openers, system nouns, modal verbs with `not` (design D3); verify unit tests from the `ears/dialects` scenarios
- [ ] 1.4 Add laws in `tests/ears-laws`: strict input gives the same requirement with and without an empty dialect, and render then parse gives an equal requirement for generated dialect sentences; verify they pass on all four targets

## 2. Blocks, Markdown headings and lexicon files

Beads: none yet.

- [ ] 2.1 Implement `parse_block` with the sentence rule, positions, pronoun resolution and diagnostics (design D4); verify unit tests for two sentences, a full stop in code and an unresolved pronoun
- [ ] 2.2 Implement heading rules in `parse_markdown`, `RequirementBlock` and `Specification::blocks()`, keeping today's extraction without rules; verify unit tests for an OpenSpec heading with a scenario and for Markdown without rules
- [ ] 2.3 Implement `Lexicon::from_yaml` with errors for unknown keys and wrong types with lines; verify unit tests for a valid file and for `modals: must`
- [ ] 2.4 Ship `openspec_dialect()` (design D5); verify a unit test that parses one sentence of each failure class from the probe
- [ ] 2.5 Add `tests/ears-acceptance/features/dialects.feature` with the `ears/dialects` scenarios, and document dialects, lexicons and lexicon files in `pkgs/ears/README.md`; verify `mise run test` passes

## 3. OKF OpenSpec profile

Beads: none yet.

- [ ] 3.1 Add the `moonrockz/ears` dependency to `moonrockz/okf/openspec`, the optional lexicon on `OpenSpecProfile`, and the reading of `ears.yaml` at the bundle root (design D6); verify unit tests for a lexicon in code, a lexicon file and an invalid lexicon file
- [ ] 3.2 Add the parsed EARS specification to each requirement of the view, and the rules `openspec-requirement-not-ears` and `openspec-lexicon-invalid`; verify unit tests from the `okf/openspec` scenarios
- [ ] 3.3 Add `openspec/ears.yaml` for this repository and an acceptance test in `tests/okf-openspec-acceptance` that parses every requirement of `openspec/specs/` and lists any sentence that fails (design D7); verify it passes, with word-choice fixes in the specs where needed
- [ ] 3.4 Document the EARS check and the lexicon file in `pkgs/okf/README.md` and `AGENTS.md`; verify `mise run lint` passes

## 4. Integration

Beads: none yet.

- [ ] 4.1 Run `mise run check`, `mise run test:scripts` and `openspec validate --all --strict`; verify all pass
- [ ] 4.2 Check every scenario of the delta specs against a test that covers it; verify that no scenario lacks a test

## Workflow follow-up

- Archive the change after the pull request merges.
