---
name: code-review
description: Review a Mission Control diff, branch or pull request against the repository practices in AGENTS.md. Checks domain types (no primitive obsession; parse, do not validate; smart constructors that make invalid states unrepresentable), pure domain code, I/O boundaries, OpenSpec agreement, targets and warnings. Use after a change and before a pull request. Reports findings and does not edit files.
---

# Code review

Use this skill to review a change to Mission Control, a MoonBit monorepo of
libraries (`moonrockz/mdc`, `moonrockz/ears`, `moonrockz/okf`), shared contracts,
a CLI, a web UI and a desktop shell. The review does not edit files. It reports
findings that the author can act on.

This file is the one checklist for every agent tool. The tool wrappers in
`.claude/agents/`, `.cursor/agents/`, `.codex/agents/` and `.github/agents/` only
point here. Change the checklist here, not in a wrapper.

## Start

1. Read `AGENTS.md`. Its rules are the standard for the review. When this file and
   `AGENTS.md` disagree, `AGENTS.md` wins.
2. Find the change. Use the target that the caller gives. Else review
   `git diff origin/main...HEAD` and the uncommitted changes.
3. When the change belongs to an OpenSpec change, read its `proposal.md`,
   `design.md`, `tasks.md` and the spec deltas in `openspec/changes/<name>/`, and
   the main specs in `openspec/specs/` that the deltas change.
4. Read the full changed files, not only the diff lines, before you report a
   finding.

Use the compiler for mechanical questions. You can run `mise exec -- moon check
--deny-warn --target <target>`, `mise exec -- moon test <path> --target <target>`,
`mise run validate` and `mise exec -- openspec validate --all --strict`. Do not run
commands that write to the repository, push, or change the tracker.

## Checklist

### Domain types (highest priority)

The owner practice: no primitive obsession; parse, do not validate; make invalid
states unrepresentable.

- A public function, field or step that takes or holds a raw `String`, `Int`,
  `Array` or `Map` for a value with rules. Look for names such as `name`, `label`,
  `key`, `path`, `dir`, `id`, `url`, `level`, `limit`, `width`, `code`, `version`,
  `type` and `rule`. Ask: does the value have rules (not empty, a character set, a
  range, a format, a fixed set)? If yes, it needs a type.
- A `pub(all)` struct, a public tuple struct or public fields that let a caller
  make a value that breaks its rules, for example a negative limit or an empty name.
- A smart constructor that is missing or can be bypassed: the type must have
  private fields and one constructor, `fn T::T(...) -> T raise SomeError`, that
  raises a typed `suberror`.
- Validation in place of a parse: a `Bool` check such as `is_valid_*` or
  `validate_*`, `is_empty()` or `trim()` checks far from the boundary, or the same
  rule checked at more than one place.
- A raw value that goes past the boundary after a parse already made the type.
- A string or an integer code where an enum fits.
- A parse error that is not typed or does not name the input and the broken rule.
- A missing test for each rule of a smart constructor, on each side of the limit.

Free text without rules, such as a title, a description, a message or the clause
text of an EARS requirement, can stay a `String`.

### Purity and boundaries

- I/O outside the boundary code. The boundary code is the task scripts in
  `scripts/`, the apps in `apps/`, the OKF store packages (`moonrockz/okf/fs`,
  `fs/node`, `fs/browser` and later stores), and tests. Library cores stay pure.
- Domain functions that read hidden state, such as the process environment, the
  clock or the working directory, in place of explicit inputs or providers.
- Public values that can change after construction, or a mutable map or array that
  escapes a domain value. Transitions must give a new value and leave the earlier
  value unchanged.

### Public API

- A public item without a doc comment, or a doc comment that disagrees with the
  behavior.
- An API that disagrees with the design or spec of its OpenSpec change.

### Targets and warnings

- Library code that does not build and test on `wasm`, `wasm-gc`, `js` and
  `native`, unless the package limits its targets on purpose with a comment in
  `moon.pkg` that gives the reason.
- Per-target code that does not use `options(targets: ...)` or a `#cfg` attribute.
- A `warnings` override in `moon.pkg` without a comment that gives the reason and
  the condition to remove it, or one that is wider than the problem.

### Errors

- An error matched by its message text. Errors must be typed values.
- An `abort` or `panic` for a fault that an input can cause.

### Specs, tasks and docs

- Behavior, a public API or a requirement that changes without an OpenSpec change.
- A ticked task in `tasks.md` whose behavior or test is missing.
- Files under `.dev/` that are staged or committed.
- Documentation, comments, specs and commit messages that do not use ASD-STE100
  Simplified Technical English, or README examples that disagree with the API.

### Commits

- A commit message that is not a Conventional Commit, or one with an AI
  attribution line.

## Report

Give findings in order of severity. For each finding give:

- `path:line`
- The rule from the checklist or from `AGENTS.md`
- The problem in one sentence, and a concrete case where it fails or misleads
- The fix, for example the type and smart constructor to add

Mark each finding as confirmed (you read the code or ran the check) or as a
question (you need the author's intent). Do not praise and do not list style
points that the formatter or the linter already checks. If you find nothing, say
so in one line.
