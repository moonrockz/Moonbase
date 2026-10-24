# Design

## Context

See `proposal.md` for the motivation. The specs under `specs/` give the required behavior.

Current state of `moonrockz/ears` (`pkgs/ears`):

- `Requirement::Requirement(source)` normalizes white space, reads `Where`, `While`, `When` and `If ... then` clauses with comma separators, requires `the` before the system, and splits the system and the response at the first `shall`. `Requirement` is opaque and immutable, with `feature`, `preconditions`, `trigger`, `system` and `response`. `to_string()` renders canonical keyword case.
- `parse_text` treats each nonblank line as one requirement. `parse_markdown` and `from_mdc` pick candidate paragraphs and list items from an MDC document and keep `SourceSpan` origins and `Diagnostic` values.
- `moonrockz/okf/openspec` parses requirement names, texts and scenarios from Markdown headings itself; it does not use `moonrockz/ears`.

A probe over this repository's 88 OpenSpec requirements found these failure classes: subjects without `the` (pronouns, other determiners, bare nouns), `MUST`, several sentences per requirement, lead-in words such as "Otherwise", and openers such as "For each document,".

## Goals / Non-Goals

**Goals:**

- No behavior change without a dialect.
- Project vocabulary as data, so a project extends the parser without code.
- One parser: dialects add vocabulary to the same grammar; they do not replace it.

**Non-Goals:**

- Guessing subjects that no dialect names. A sentence such as "Text comparison SHALL ignore letter case" parses only when a lexicon names `Text comparison` as a system noun, or when the author writes it in EARS form.
- A general sentence splitter for natural language. Sentence ends are `.`, `?` and `!` followed by white space or the end, outside backticks.

## Decisions

### D1. `Dialect` is a trait; `Lexicon` is its data form

```text
pub(open) trait Dialect {
  name(Self) -> String
  modals(Self) -> Array[Word] = _          // default: none (the grammar always has "shall")
  determiners(Self) -> Array[Word] = _     // default: none ("the" is always allowed)
  pronouns(Self) -> Array[Word] = _
  system_nouns(Self) -> Array[Phrase] = _
  lead_ins(Self) -> Array[Phrase] = _
  headings(Self) -> Array[HeadingRule] = _
}
```

`Lexicon` is a struct with the same lists and implements `Dialect`. `Lexicon::from_yaml(text)` parses a lexicon file; it is pure, so the caller reads the file (for example through an OKF store). `openspec_dialect()` returns a `Lexicon`.

The parser merges the dialects into one internal `Vocabulary` (sets of lower-case words, and system nouns and lead-ins sorted longest first so that the longest match wins). This follows the `moonrockz/okf` profile pattern, so the two modules extend the same way.

Alternative: a grammar plug-in per dialect. Rejected: separate grammars would drift, and the failure classes all fit as vocabulary.

### D2. The requirement records the new parts

`Requirement` gains `lead_in : String?`, `opener : Word` (the determiner or pronoun as written; `the` for strict input), `modal : Modal` (`{ verb : Word, negated : Bool }`) and `resolved_system : String?` (set only by block parsing). For a pronoun subject, `system()` is `""` and `resolved_system()` gives the antecedent. `pattern()` does not change, because lead-ins, openers and modals are not EARS clauses.

`to_string()` renders `[lead_in, ]clauses, <opener> <system> <verb>[ not] <response>`, with the opener as written and keywords in canonical lower case. Parsing that text with the same dialects gives an equal requirement. For strict input the output is the same as today.

### D3. Parsing order with a vocabulary

1. Normalize white space.
2. If the text starts with a lead-in (longest match, any case), take it up to the first comma that is followed by a clause keyword or a subject start, or up to the subject start when no comma follows.
3. Read `Where`, `While`, `When` and `If ... then` clauses as today. A comma is structural when a clause keyword, `then`, or a subject start follows it. A subject start is `the`, a determiner, a pronoun or a system noun.
4. Read the subject: an opener word, or a system noun. After a determiner (or `the`), the system runs to the modal verb. After a pronoun, the modal verb must follow directly. A system noun is the whole system.
5. Find the first modal verb of the vocabulary (`shall` always, plus dialect modals) as a word. An optional `not` after it sets `negated`. The rest is the response.

Strict input passes through the same steps with an empty dialect vocabulary, so `the` and `shall` give the same results as today. The acceptance tests of `tests/ears-acceptance` and the laws of `tests/ears-laws` run unchanged as the strictness proof.

### D4. Blocks and Markdown

`parse_block(text, dialects?) -> Specification` splits sentences (D-goal rule), parses each with the vocabulary, and resolves pronouns to the nearest previous `system` or `resolved_system`. Each sentence keeps a `SourceSpan` relative to the block; an unresolved pronoun adds a diagnostic and keeps the requirement.

`parse_markdown(source, dialects?)` keeps today's extraction when no heading rule is active. With heading rules, it walks the MDC block tree: a heading that matches a rule (level and case-sensitive prefix) opens a `RequirementBlock { name, heading_line, specification }`; the paragraphs and list items after it, up to the next heading of any level, form the block text with their positions. The `Specification` gains `blocks()`; `requirements()` and `diagnostics()` stay flat lists over all blocks.

### D5. The OpenSpec dialect

`openspec_dialect()` adds the modal `must`, the determiners `a`, `an`, `each`, `every`, `any`, `these`, `those`, `this`, `that`, `its` and `their`, the pronouns `it` and `they`, the lead-in `otherwise`, and the heading rule `(3, "Requirement:")`. Project-specific words, such as `Mission Control`, `Text comparison` or the lead-in `for each`, belong in the project lexicon, not in the shipped dialect.

### D6. `moonrockz/okf/openspec` uses `moonrockz/ears`

`OpenSpecProfile` gets a constructor `OpenSpecProfile::OpenSpecProfile(lexicon? : @ears.Lexicon)`. `view(bundle, lexicon?)` reads `ears.yaml` at the bundle root when it exists (an asset of the `openspec/` bundle), adds it to the OpenSpec dialect, and gives each `Requirement` of the view an `ears : @ears.Specification` from `parse_block(text)`. The profile adds the rule `openspec-requirement-not-ears` (warning) for each diagnostic, and the rule `openspec-lexicon-invalid` (error) for a lexicon file that does not parse.

The existing `OpenSpecProfile::{}` literal stays valid, because the struct keeps no required field; the lexicon is an optional field with a default.

### D7. This repository gets a lexicon file

`openspec/ears.yaml` names this project's systems and lead-ins (such as `for each`), so the acceptance test that parses every requirement of `openspec/specs/` can pass. Sentences that still fail are listed by the test and fixed in the spec text, as part of this change only when the fix is a word choice; larger rewrites are out of scope.

### D8. Domain types for vocabulary and headings

Following the Domain types section of `AGENTS.md`:

- `Word` is one vocabulary word: not empty, no white space, no comma, no full stop. It is used for modal verbs, determiners and pronouns. Its constructor `Word::Word(text) -> Word raise LexiconError` keeps the text as written and compares without letter case.
- `Phrase` is one or more words separated by single spaces, with no comma and no full stop. It is used for system nouns and lead-in phrases.
- `HeadingLevel` is an integer from 1 to 6. `HeadingPrefix` is a non-empty text without a line break. `HeadingRule` has private fields and the constructor `HeadingRule::HeadingRule(level, prefix)`.
- `Dialect` methods return `Array[Word]`, `Array[Phrase]` and `Array[HeadingRule]`, so a dialect cannot give an invalid word. `Lexicon::from_yaml` parses each list item with these constructors and reports the key, the line and the broken rule in `LexiconError`.
- `Modal` holds a `Word` and the negation flag. `Requirement::opener()` gives the opener `Word` as written.
- Each constructor has tests on each side of each rule.

## Risks / Trade-offs

- [Determiners make subject boundaries ambiguous: "Each entry of the index SHALL ..."] → The system runs to the first modal verb, so it is `entry of the index`. That is correct for EARS, which keeps the system as free text.
- [A modal verb inside a system name, such as "the shall-list"] → Modal verbs match only as whole words with spaces around them, as `shall` does today.
- [Pronoun resolution picks the wrong antecedent] → Only the nearest previous system is used, and the resolved system is recorded beside the pronoun, so a reader can see it.
- [Requirement equality changes because of the new fields] → Strict input gives `opener = "the"`, `modal = shall`, no lead-in, so two strict requirements compare as before; the laws prove the round trip.

## Migration Plan

All additions are optional arguments or new functions; the strict default keeps today's results. Callers that match on `ParseError` keep working; no error constructor changes. Rollback is a revert of the pull request.
