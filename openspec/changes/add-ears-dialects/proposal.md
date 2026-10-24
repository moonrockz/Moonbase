# Proposal

## Why

`moonrockz/ears` accepts only the strict EARS form `the <system> shall <response>`, one sentence at a time. OpenSpec requirements are EARS-like but wider: they use `SHALL` or `MUST`, start sentences with subjects such as "It", "A store" or "Each entry", put several sentences in one requirement, and mark each requirement in Markdown with a `### Requirement: <name>` heading. A probe over the 88 requirements of this repository's `openspec/specs/` showed that only 42 parse sentence by sentence, and that whole-text parsing gives wrong results, because the response takes in the following sentences.

Projects also use their own words for systems and clause lead-ins. The parser must accept them without a change to the library.

## What Changes

- Add a provider model to `moonrockz/ears`: a `Dialect` trait whose methods add modal verbs (such as `must`), subject openers (determiners such as "a" and "each", and pronouns such as "it"), system nouns that need no determiner, lead-in phrases (such as "Otherwise"), and Markdown requirement headings. Every method has a default, and several dialects compose.
- Add a `Lexicon`: a dialect that a project defines as data, built in code or parsed from a YAML lexicon file, such as `openspec/ears.yaml`.
- The default dialect keeps today's strict grammar, so existing callers see no change.
- Requirements record their modal verb (with negation), their subject opener and their lead-in phrase. Rendering and parsing stay round-trip safe.
- Parse a requirement block: split it into sentences, parse each one, and resolve a pronoun subject to the system of the previous sentence.
- Extract requirement blocks from Markdown with the heading rules of the active dialects, so that each block has its heading name, its sentences and its source positions.
- Ship an OpenSpec dialect in `moonrockz/ears`: `SHALL` and `MUST` with negation, the usual OpenSpec subject openers, and the `### Requirement:` heading.
- The OKF OpenSpec profile (`moonrockz/okf/openspec`) uses the EARS parser with the OpenSpec dialect and the project lexicon: its view gives the parsed EARS sentences of each requirement, and a new check reports a requirement sentence that is not in EARS form.

### Out of scope

- Natural-language analysis beyond the lexicon, such as finding a subject without a known opener, or splitting conjunctions inside a response.
- Scenario (`WHEN`/`THEN` bullet) parsing, which `moonrockz/okf/openspec` already does.
- Rewriting this repository's specs into strict EARS. A later change can do that once the check reports what fails.
- Other requirement formats than EARS.

## Capabilities

### New Capabilities

- `ears/dialects`: The dialect provider model, lexicons and lexicon files, sentence and block parsing with pronoun resolution, Markdown requirement headings, and the shipped OpenSpec dialect.

### Modified Capabilities

- `okf/openspec`: The structured view adds the parsed EARS sentences of each requirement, and a new check reports requirement sentences that are not in EARS form.

## Impact

- **Affected published modules:** `moonrockz/ears` (new API; strict default unchanged) and `moonrockz/okf` (`moonrockz/okf/openspec` gains a dependency on `moonrockz/ears`).
- **API:** `Requirement` gains accessors for the modal verb, the subject opener and the lead-in. `parse`, `parse_text` and `parse_markdown` take optional dialects.
- **Tests:** new acceptance features and laws in `tests/ears-acceptance` and `tests/ears-laws`, and a probe of this repository's own OpenSpec requirements as an acceptance test.
- **Dependencies:** `moonrockz/ears` already depends on `moonrockz/mdc` and `moonbit-community/yaml` through it; no new external dependency.
