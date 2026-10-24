# Design

## Context

See `proposal.md` for the motivation. The audit that drives this change used the checklist in `.agents/skills/code-review/SKILL.md` over every package of `moonrockz/okf`. `check-okf-inputs` already fixed the bugs that it found; this change fixes the types, so that the same class of bug cannot come back.

## Goals / Non-Goals

**Goals:**

- Every public value with rules is a type with private fields and one fallible constructor, or a constructor that cannot fail for values that are valid by construction.
- No public mutable state, and no sentinel values.
- The acceptance features, laws, golden checks and browser checks pass unchanged in meaning.

**Non-Goals:**

- Typing free text: titles, descriptions, messages, clause text and body text stay `String`.
- Changes to behavior, except the two fixes in the proposal.

## Decisions

### D1. One `types.mbt` per package for its value types

Each package keeps its value types and their errors together, for example `pkgs/okf/types.mbt` for `BundleLabel`, `StoreDir`, `ConceptType`, `FieldKey`, `RuleName`, `HeadingLevel`, `LogDate` and `SearchLimit`. Each type has:

- private fields, `derive(Eq, Hash, Debug)` where it applies, and `Compare` through `lexical_compare` where order matters;
- one constructor `fn T::T(text : String) -> T raise TError`, whose error has one case per rule and names the input;
- infallible constructors where a value is valid by construction (`StoreDir::root()`, `SearchLimit::default()`, `LogDate::of_instant(...)`);
- `to_string()` for display and for writing back to text.

### D2. Order of the work

The types are added bottom up, so that each step compiles and passes the tests: core identifiers (labels, directories, keys, concept types) → links, references and GitHub sources → indexes, logs and queries → validation → registers and profiles → edit inputs and planner errors → providers and stores → OpenSpec names. Each step changes its callers in the same commit.

### D3. Shared with other changes

`StoreDir` is also part of `add-browser-storage-options`; whichever change lands first adds it, and the other uses it. `HeadingLevel` is also proposed for `moonrockz/mdc` in `apply-domain-types-libraries`; the OKF type converts from the mdc value at the boundary until that change lands.

### D4. Boundary parsing

Raw text enters at the document set and at frontmatter. The parse happens there: `load_bundle` and `discover` build labels and directories; metadata accessors give typed values (`concept_type() -> ConceptType?`, `okf_version() -> OkfVersion?`); the OpenSpec profile parses names in `derived_fields` and in the view. Functions after the boundary take the types and check nothing again.

### D5. Unknown rule names

`validate` collects the names of all active rules and reports each override or turned-off name that no rule has, with the new rule `validation-config-unknown-rule` (warning).

## Risks / Trade-offs

- [A large API change touches every test] → The bottom-up order (D2) keeps each step small and green; the golden checks guard the behavior.
- [More types make simple calls longer] → Infallible constructors and `to_string()` cover the common cases; README examples show them.
- [Case-insensitive `ConceptType` equality surprises a caller] → The doc comment states it; it matches the current comparisons, which already ignore case.

## Migration Plan

`moonrockz/okf` has no release yet, so no caller migrates. Rollback is a revert of the pull request.
